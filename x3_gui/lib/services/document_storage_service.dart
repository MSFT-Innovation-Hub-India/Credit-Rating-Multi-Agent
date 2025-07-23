import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart'; //For hashing
import 'package:path/path.dart' as path; //For file path manipulation
import 'package:http/http.dart' as http; //For HTTP requests
import 'package:x3_gui/models/document_model.dart';
import 'package:x3_gui/services/azure_config.dart'; //Azure configuration props (bad security for production, but ok for demo)

class DocumentStorageService {
  // Constants for retry logic
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 1000;

  // MARK: Helpers

  /// Calculates SHA-256 hash of file content for unique blob naming
  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gets content type from file extension
  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.csv':
        return 'text/csv';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  /// Maybe reading file contents via OCR/Text-Extraction in future phases or LLM?? --> run on cloud later
  DocumentType _detectDocumentType(String fileName) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.contains('balance') && lowerName.contains('sheet')) {
      return DocumentType.balanceSheet;
    } else if (lowerName.contains('cash') && lowerName.contains('flow')) {
      return DocumentType.cashFlow;
    } else if (lowerName.contains('profit') ||
        lowerName.contains('p&l') ||
        lowerName.contains('income') ||
        lowerName.contains('pnl')) {
      return DocumentType.profitLoss;
    } else if (lowerName.contains('business') ||
        lowerName.contains('plan') ||
        lowerName.contains('executive') ||
        lowerName.contains('market')) {
      return DocumentType.qualitativeBusiness;
    } else if (lowerName.contains('earnings') ||
        lowerName.contains('call') ||
        lowerName.contains('conference') ||
        path.extension(lowerName) == '.mp3' ||
        path.extension(lowerName) == '.wav') {
      return DocumentType.earningsCall;
    }

    // Default to other for unrecognized files
    return DocumentType.other;
  }

  /// Executes HTTP request with retry logic
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request,
  ) async {
    Exception? lastException;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        print('DEBUG: Attempt ${attempt + 1} of $_maxRetries');
        final response = await request();

        // Log response
        print('DEBUG: HTTP ${response.statusCode} - ${response.reasonPhrase}');
        if (response.statusCode >= 400) {
          print('DEBUG: Error response body: ${response.body}');
        }

        return response;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('ERROR: Attempt ${attempt + 1} failed: $e');

        if (attempt < _maxRetries - 1) {
          final delayMs = _baseDelayMs * pow(2, attempt);
          print('DEBUG: Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs.toInt()));
        }
      }
    }

    throw lastException ?? Exception('All retry attempts failed');
  }

  /// Gets all uploaded documents by listing blobs and their metadata
  Future<List<Document>> getAllDocuments() async {
    try {
      print('DEBUG: Fetching all documents from Azure Blob Storage');

      // List blobs in container
      final listUrl =
          '${AzureConfig.baseUrl}${AzureConfig.sasQuery}&restype=container&comp=list';
      print(
        'DEBUG: List URL: ${listUrl.replaceAll(AzureConfig.sasToken, '[SAS_TOKEN]')}',
      );

      final response = await _executeWithRetry(() async {
        return http.get(Uri.parse(listUrl));
      });

      if (response.statusCode == 404) {
        print('DEBUG: Container not found or empty');
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to list blobs: HTTP ${response.statusCode} - ${response.body}',
        );
      }

      print('DEBUG: Successfully listed blobs');

      // Parse XML response to extract blob names
      final xmlBody = response.body;
      final blobNames = <String>[];

      // Simple XML parsing for blob names (avoiding XML dependency)
      final namePattern = RegExp(r'<Name>([^<]+)</Name>');
      final matches = namePattern.allMatches(xmlBody);

      for (final match in matches) {
        final blobName = match.group(1)!;
        if (!blobName.endsWith('.json') &&
            blobName != 'documents_metadata.json') {
          blobNames.add(blobName);
        }
      }

      print('DEBUG: Found ${blobNames.length} document blobs');

      // Get metadata for each blob
      final documents = <Document>[];

      for (final blobName in blobNames) {
        try {
          final document = await _getBlobMetadata(blobName);
          if (document != null) {
            documents.add(document);
          }
        } catch (e) {
          print('WARNING: Failed to get metadata for blob $blobName: $e');
          // Continue with other blobs
        }
      }

      print('DEBUG: Retrieved ${documents.length} documents with metadata');
      return documents;
    } catch (e) {
      print('ERROR: Failed to get all documents: $e');
      return [];
    }
  }

  /// Gets blob metadata and creates Document object
  Future<Document?> _getBlobMetadata(String blobName) async {
    try {
      final metadataUrl =
          '${AzureConfig.baseUrl}/$blobName${AzureConfig.sasQuery}';

      final response = await _executeWithRetry(() async {
        return http.head(Uri.parse(metadataUrl));
      });

      if (response.statusCode != 200) {
        print(
          'WARNING: Failed to get metadata for $blobName: HTTP ${response.statusCode}',
        );
        return null;
      }

      // Extract metadata from headers - MATCH YOUR UPLOAD KEYS
      final headers = response.headers;
      final originalFileName =
          headers['x-ms-meta-filename'] ??
          blobName; // CHANGED: was 'x-ms-meta-original-filename'
      final documentTypeStr =
          headers['x-ms-meta-doctype'] ??
          'other'; // CHANGED: was 'x-ms-meta-document-type'
      final fileHash =
          headers['x-ms-meta-hash'] ?? ''; // CHANGED: was 'x-ms-meta-file-hash'
      final documentId = fileHash.isNotEmpty
          ? fileHash
          : blobName; // CHANGED: use hash as ID
      final contentLength = int.tryParse(headers['content-length'] ?? '0') ?? 0;

      // Parse document type
      DocumentType documentType = DocumentType.other;
      try {
        documentType = DocumentType.values.firstWhere(
          (type) => type.name == documentTypeStr,
          orElse: () => DocumentType.other,
        );
      } catch (e) {
        print('WARNING: Failed to parse document type: $documentTypeStr');
      }

      return Document(
        id: documentId,
        fileName: originalFileName.replaceAll(
          '_',
          '.',
        ), // CHANGED: Convert back from sanitized filename
        filePath: '${AzureConfig.baseUrl}/$blobName',
        fileSizeBytes: contentLength,
        uploadedAt: DateTime.now(), // Since we removed upload date metadata
        contentHash: fileHash,
        type: documentType,
        status: DocumentStatus.uploaded,
      );
    } catch (e) {
      print('ERROR: Failed to get blob metadata for $blobName: $e');
      return null;
    }
  }

  //MARK: UPLOAD
  Future<Document> uploadDocument(
    File sourceFile, [
    DocumentType? expectedType,
  ]) async {
    try {
      print('DEBUG: Starting Azure Blob upload for file: ${sourceFile.path}');

      //Validate file existence:
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final fileName = path.basename(sourceFile.path);
      final fileHash = await _calculateFileHash(sourceFile);
      final blobName =
          '$fileHash${path.extension(fileName)}'; // Unique blob name based on hash

      //DEBUG logs:
      print('DEBUG: File: $fileName');
      print('DEBUG: Blob name: $blobName');
      print('DEBUG: Hash: $fileHash');

      //Read file as bytes:
      final fileBytes = await sourceFile.readAsBytes();
      print('DEBUG: File size: ${fileBytes.length} bytes');

      // Create blob URL
      final blobUrl = '${AzureConfig.baseUrl}/$blobName${AzureConfig.sasQuery}';
      print(
        'DEBUG: Upload URL: ${blobUrl.replaceAll(AzureConfig.sasToken, '[SAS_TOKEN]')}',
      );

      //ALWAYS USE EXPECTED TYPE IF PROVIDED ELSE USE FILE NAME DETECTION"
      final DocumentType finalType;
      final bool isTypeOverridden;

      if (expectedType != null) {
        finalType = expectedType;
        final detectedType = _detectDocumentType(fileName);
        isTypeOverridden = detectedType != expectedType;
        print(
          'DEBUG: User selected type: $expectedType, detected type: $detectedType, override: $isTypeOverridden',
        );
      } else {
        finalType = _detectDocumentType(fileName);
        isTypeOverridden = false;
        print('DEBUG: Using detected type: $finalType');
      }

      //create doc model
      final document = Document(
        id: fileHash,
        fileName: fileName,
        filePath: '${AzureConfig.baseUrl}/$blobName',
        fileSizeBytes: fileBytes.length,
        uploadedAt: DateTime.now(),
        contentHash: fileHash,
        type:
            finalType, // CHANGED: Use finalType instead of expectedType ?? _detectDocumentType(fileName)
        metadata: isTypeOverridden
            ? {
                'typeOverridden': true,
                'detectedType': _detectDocumentType(fileName).name,
              }
            : null,
      );

      //Upload doc Blob w metadata
      //PUT request with retry logic
      final response = await _executeWithRetry(() async {
        return http.put(
          Uri.parse(blobUrl),
          headers: {
            'x-ms-blob-type': 'BlockBlob',
            'Content-Type': _getContentType(fileName),
            'Content-Length': fileBytes.length.toString(),
            // MINIMAL METADATA - just the essentials
            'x-ms-meta-filename': fileName.replaceAll(
              '.',
              '_',
            ), // Replace period with underscore
            'x-ms-meta-doctype': document.type.name,
            'x-ms-meta-hash': fileHash,
            // ADDED: Store override information
            if (isTypeOverridden) 'x-ms-meta-overridden': 'true',
            if (isTypeOverridden)
              'x-ms-meta-detected': _detectDocumentType(fileName).name,
          },
          body: fileBytes,
        );
      });

      if (response.statusCode != 201) {
        throw Exception(
          'Failed to upload blob: HTTP ${response.statusCode} - ${response.body}',
        );
      }

      print('DEBUG: Successfully uploaded to Azure Blob Storage');
      print('DEBUG: Document created: ${document.id}');

      return document;
    } catch (e) {
      print('ERROR: Failed to upload document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Gets a document by ID
  Future<Document?> getDocumentById(String documentId) async {
    try {
      final documents = await getAllDocuments();
      return documents.firstWhere(
        (doc) => doc.id == documentId,
        orElse: () => throw StateError('Document not found'),
      );
    } catch (e) {
      print('DEBUG: Document not found: $documentId');
      return null;
    }
  }

  ///MARK: DELETE
  Future<bool> deleteDocument(String documentId) async {
    try {
      print('DEBUG: Deleting document: $documentId');

      final document = await getDocumentById(documentId);

      if (document == null) {
        print('WARNING: Document not found for deletion: $documentId');
        return false;
      }

      // Extract blob name from URL
      final uri = Uri.parse(document.filePath);
      final blobName = uri.pathSegments.last;

      print('DEBUG: Deleting blob: $blobName');

      // Delete blob
      final deleteUrl =
          '${AzureConfig.baseUrl}/$blobName${AzureConfig.sasQuery}';

      final response = await _executeWithRetry(() async {
        return http.delete(Uri.parse(deleteUrl));
      });

      if (response.statusCode != 202 && response.statusCode != 204) {
        print(
          'ERROR: Failed to delete blob: HTTP ${response.statusCode} - ${response.body}',
        );
        return false;
      }

      print('DEBUG: Successfully deleted document: $documentId');
      return true;
    } catch (e) {
      print('ERROR: Failed to delete document: $e');
      return false;
    }
  }

  /// Gets documents by type
  Future<List<Document>> getDocumentsByType(DocumentType type) async {
    final documents = await getAllDocuments();
    return documents.where((doc) => doc.type == type).toList();
  }
}
