import 'package:path/path.dart' as path;
/*
This file defines a document model for doc metadata
IT DOES NOT ACTUALLY HANDLE CONTENT OF THE FILES OR CONTENT PROCESSING
OR STORING THE FILES THEMSELVES
It is meant to be used for tracking metadata about documents
such as financial statements and other documents needed for credit scoring.

The actual content processing, storage, and retrieval
should be handled by another document service file
Which will handle the actual file content and storage (to local system in phase 1)
and to Fabric in phase 2.

Might need to be changed according to domain knowledge of what documents are needed
by financial institutions for credit scoring.
 */

//Types of FSI Documents needed for Credit Scoring
//Expand as needed
enum DocumentType {
  //Reduce to 4 types for demo
  qualitativeBusiness, // Business Plan, Executive Summary, Market Analysis
  balanceSheet,
  profitLoss,
  cashFlow,
  earningsCall,
  other,
}

//For state tracking of document processing: Expand as needed
enum DocumentStatus {
  uploaded, //successfully uploaded to Blob Storage
  extracting, // Document Intelligence processing in progress
  embedding, // Generating vector embeddings and indexing in Azure AI Search
  indexed, // Successfully indexed in Azure AI Search
  /// Todo: Do we need states for each agents results working??
  processing,
  processed,
  completed, // All analysis done
  error,
}

class Document {
  final String id;
  final String fileName;
  final String filePath;
  final DocumentType type;
  final DocumentStatus? status;
  final DateTime uploadedAt;
  final int fileSizeBytes;
  final String? contentHash;
  final Map<String, dynamic>? metadata;
  //Needed to be passed to Semantic Kernel so autmatically generate this property
  String get blobName =>
      '$contentHash${path.extension(fileName)}'; // Unique name for the blob in Azure Blob Storage

  Document({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.type,
    this.status,
    required this.uploadedAt,
    required this.fileSizeBytes,
    this.contentHash,
    this.metadata,
  });

  /*
Function to convert Document object to JSON representation.
This is useful for sending data to APIs or storing in databases.
 */
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'type': type.toString(),
      'status': status.toString(),
      'uploadedAt': uploadedAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'contentHash': contentHash,
      'metadata': metadata,
    };
  }

  // Function to create a Document object from JSON representation.
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      type: DocumentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DocumentType.other,
      ),
      status: DocumentStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DocumentStatus.uploaded,
      ),
      uploadedAt: DateTime.parse(json['uploadedAt']),
      fileSizeBytes: json['fileSizeBytes'],
      contentHash: json['contentHash'],
      metadata: json['metadata'],
    );
  }

  Document copyWith({
    String? id,
    String? fileName,
    String? filePath,
    DocumentType? type,
    DocumentStatus? status,
    DateTime? uploadedAt,
    int? fileSizeBytes,
    String? contentHash,
    Map<String, dynamic>? metadata,
  }) {
    return Document(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      contentHash: contentHash ?? this.contentHash,
      metadata: metadata ?? this.metadata,
    );
  }
}
