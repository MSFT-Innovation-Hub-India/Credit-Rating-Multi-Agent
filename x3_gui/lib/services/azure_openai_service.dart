import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x3_gui/services/llm_service_interface.dart';
import 'package:x3_gui/models/document_model.dart';
import "azure_config.dart";

class AzureOpenAIService implements LLMServiceInterface {
  static const String _endpoint = AzureConfig.OpenAIendpoint;
  static const String _deploymentName = AzureConfig.OpenAIdeploymentName;
  static const String _apiVersion = AzureConfig.OpenAIapiVersion;
  static const String _apiKey = AzureConfig.OpenAIapiKey;

  final http.Client _httpClient;
  final List<Map<String, String>> _conversationHistory = [];

  AzureOpenAIService() : _httpClient = http.Client() {
    // Initialize with system message
    _conversationHistory.add({'role': 'system', 'content': _getSystemPrompt()});
  }

  String get _baseUrl =>
      '$_endpoint/openai/deployments/$_deploymentName/chat/completions?api-version=$_apiVersion';

  //MARK: System Prompt
  String _getSystemPrompt() {
    return '''
You are an AI assistant specialized in corporate credit scoring and financial document analysis. Your role is to:

1. Guide users through the document upload process for comprehensive credit assessment
2. Explain what documents are needed and why each is important
3. Provide real-time status updates during document processing and analysis
4. Present analysis results from AI agents in a clear, conversational manner
5. Answer follow-up questions about the analysis and credit recommendations

REQUIRED DOCUMENTS for comprehensive credit scoring (5 types only):
- **Qualitative Business Documents**: Business Plan, Executive Summary, Market Analysis
- **Balance Sheet**: Current financial position snapshot
- **Cash Flow Statement**: Liquidity and operational efficiency analysis
- **Profit & Loss Statement**: Revenue, costs, and profitability analysis
- **Earnings Call**: Short audio recording of company earnings discussion (1-2 minutes)

CONVERSATION GUIDELINES:
- Be brief, and concise in response
- Do not return markdown or special formatting
- Always be helpful, professional, and encouraging
- Be aware of what documents have been uploaded and reference them in conversations
- Ask for the 4 required documents in logical order
- Explain the purpose and importance of each document type
- Provide clear progress updates during document processing
- Present analysis results with both technical details and business implications
- Highlight key insights and recommendations prominently

DOCUMENT PROCESSING STAGES:
- Upload: Document saved to secure storage
- Extraction: AI reading and analyzing document content
- Indexing: Creating searchable database of document information
- Analysis: AI agents processing and scoring the documents

Remember: You are helping with corporate credit assessment for these 4 specific document types only. Focus on business financial health, cash flow, and creditworthiness indicators based on the uploaded documents.
''';
  }

  Future<String> _makeOpenAIRequest(List<Map<String, String>> messages) async {
    try {
      final requestBody = {
        'messages': messages,
        'max_tokens': 1000,
        'temperature': 0.7,
        'top_p': 0.95,
        'frequency_penalty': 0,
        'presence_penalty': 0,
      };

      final response = await _httpClient.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json', 'api-key': _apiKey},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content =
            responseData['choices']?[0]?['message']?['content'] as String?;
        return content ?? 'Sorry, I could not generate a response.';
      } else {
        print(
          'Azure OpenAI API Error: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to get response from Azure OpenAI: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error making Azure OpenAI request: $e');
      throw Exception('Failed to communicate with Azure OpenAI: $e');
    }
  }

  //MARK: Doc Helpers (same as Gemini service)
  List<DocumentType> _getRequiredDocumentTypes() {
    return [
      DocumentType.qualitativeBusiness,
      DocumentType.balanceSheet,
      DocumentType.cashFlow,
      DocumentType.profitLoss,
      DocumentType.earningsCall,
    ];
  }

  List<DocumentType> _prioritizeDocumentTypes(List<DocumentType> types) {
    final priority = [
      DocumentType.balanceSheet,
      DocumentType.cashFlow,
      DocumentType.profitLoss,
      DocumentType.qualitativeBusiness,
      DocumentType.earningsCall,
    ];
    final prioritized = <DocumentType>[];
    for (final priorityType in priority) {
      if (types.contains(priorityType)) {
        prioritized.add(priorityType);
      }
    }
    for (final type in types) {
      if (!prioritized.contains(type)) {
        prioritized.add(type);
      }
    }
    return prioritized;
  }

  String _getDocumentExplanation(DocumentType type) {
    switch (type) {
      case DocumentType.qualitativeBusiness:
        return 'Qualitative business documents like Business Plans and Market Analysis help assess the business model, market position, and strategic vision.';
      case DocumentType.balanceSheet:
        return 'Balance Sheets provide a snapshot of the company\'s assets, liabilities, and equity at a specific point in time, crucial for understanding financial health.';
      case DocumentType.cashFlow:
        return 'Cash Flow Statements show the inflow and outflow of cash, indicating liquidity and operational efficiency.';
      case DocumentType.profitLoss:
        return 'Profit & Loss Statements summarize revenues, costs, and expenses over a period, revealing profitability trends.';
      case DocumentType.earningsCall:
        return 'Earnings call recordings provide management insights and forward-looking statements crucial for assessing business strategy and market position.';
      default:
        return 'This is another document type which is important for credit scoring.';
    }
  }

  String _getDocumentTypeDisplayName(DocumentType type) {
    switch (type) {
      case DocumentType.qualitativeBusiness:
        return 'Qualitative Business Documents';
      case DocumentType.balanceSheet:
        return 'Balance Sheet';
      case DocumentType.cashFlow:
        return 'Cash Flow Statement';
      case DocumentType.profitLoss:
        return 'Profit & Loss Statement';
      case DocumentType.earningsCall:
        return 'Earnings Call';
      default:
        return 'Other Financial Document';
    }
  }

  String _getNextStepsRecommendation(List<Document> uploadedDocuments) {
    if (uploadedDocuments.isEmpty) {
      return "Upload the company's qualitative information, balance sheet, profit and loss, and cash flow statements.";
    }

    final uploadedTypes = uploadedDocuments.map((doc) => doc.type).toSet();
    final remainingTypes = _getRequiredDocumentTypes()
        .where((type) => !uploadedTypes.contains(type))
        .toList();

    if (remainingTypes.isEmpty) {
      return "Great! You have uploaded all required documents. I can now analyze them to provide you with a comprehensive credit assessment.";
    }

    return "Please upload the remaining ${remainingTypes.length} required document(s) to complete your credit assessment.";
  }

  String _getStatusDisplayText(DocumentStatus? status) {
    switch (status) {
      case DocumentStatus.uploaded:
        return '📄 Document uploaded to cloud successfully.';
      case DocumentStatus.extracting:
        return '🔍 Our AI is reading your document...';
      case DocumentStatus.embedding:
        return '🔗 Generating vector embeddings for analysis...';
      case DocumentStatus.indexed:
        return '📊 Document indexed successfully for agent search.';
      case DocumentStatus.error:
        return '❌ An error occurred...';
      default:
        return '🔃 We are analysing your data';
    }
  }

  List<Map<String, String>> _filterDocumentStatusMessages(
    List<Map<String, String>> conversationHistory,
  ) {
    return conversationHistory.where((message) {
      final content = message['content']?.toLowerCase() ?? '';
      final isAssistantMessage = message['role'] == 'assistant';

      if (isAssistantMessage) {
        final documentStatusKeywords = [
          'uploaded successfully',
          'document upload progress',
          'uploaded documents:',
          'remaining documents needed:',
          'all required documents',
          '✅',
          '❗',
          '📋',
          '🎉',
        ];

        final containsDocumentStatus = documentStatusKeywords.any(
          (keyword) => content.contains(keyword.toLowerCase()),
        );

        return !containsDocumentStatus;
      }
      return true;
    }).toList();
  }

  String _buildContextPrompt(
    String userPrompt,
    List<Map<String, String>> conversationHistory,
    List<Document> uploadedDocuments,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('CURRENT DOCUMENT STATUS:');
    if (uploadedDocuments.isNotEmpty) {
      buffer.writeln('Currently uploaded documents:');
      for (final doc in uploadedDocuments) {
        buffer.writeln(
          '- ${_getDocumentTypeDisplayName(doc.type)}: ${doc.fileName} (${doc.status?.name ?? 'unknown status'})',
        );
      }
    } else {
      buffer.writeln('No documents currently uploaded.');
    }
    buffer.writeln();

    if (conversationHistory.isNotEmpty) {
      buffer.writeln('RECENT CONVERSATION CONTEXT:');
      final filteredHistory = _filterDocumentStatusMessages(
        conversationHistory,
      );
      for (final message in filteredHistory.take(8)) {
        buffer.writeln('${message['role']}: ${message['content']}');
      }
      buffer.writeln();
    }

    buffer.writeln('USER CURRENT MESSAGE: $userPrompt');
    buffer.writeln();
    buffer.writeln(
      'IMPORTANT: Base your response on the CURRENT DOCUMENT STATUS above, not on any previous conversation history about documents.',
    );

    return buffer.toString();
  }

  //MARK: Interface Implementation
  @override
  Future<String> generateResponse(String prompt) async {
    try {
      final messages = [
        ..._conversationHistory,
        {'role': 'user', 'content': prompt},
      ];

      final response = await _makeOpenAIRequest(messages);

      // Update conversation history
      _conversationHistory.add({'role': 'user', 'content': prompt});
      _conversationHistory.add({'role': 'assistant', 'content': response});

      // Keep only last 20 messages to prevent context overflow
      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(
          1,
          _conversationHistory.length - 19,
        ); // Keep system message
      }

      return response;
    } catch (e) {
      throw Exception('Failed to get response from Azure OpenAI: $e');
    }
  }

  @override
  Future<String> generateResponseWithContext(
    String prompt,
    List<Map<String, String>> conversationHistory,
    List<Document> uploadedDocuments,
  ) async {
    try {
      final contextPrompt = _buildContextPrompt(
        prompt,
        conversationHistory,
        uploadedDocuments,
      );

      final messages = [
        {'role': 'system', 'content': _getSystemPrompt()},
        ...conversationHistory.take(10), // Limit context to prevent overflow
        {'role': 'user', 'content': contextPrompt},
      ];

      return await _makeOpenAIRequest(messages);
    } catch (e) {
      throw Exception('Failed to generate response with context: $e');
    }
  }

  @override
  String getDocumentUploadGuidance(List<Document> uploadedDocuments) {
    final uploadedTypes = uploadedDocuments.map((doc) => doc.type).toSet();
    final remainingTypes = _getRequiredDocumentTypes()
        .where((type) => !uploadedTypes.contains(type))
        .toList();

    if (remainingTypes.isEmpty && uploadedDocuments.isNotEmpty) {
      return "🎉 **Excellent!** You've uploaded all the essential documents. "
          "Your credit analysis is now in progress. ";
    }

    final buffer = StringBuffer();
    buffer.writeln("📋 **Document Upload Progress**\n");

    if (uploadedDocuments.isNotEmpty) {
      buffer.writeln("✅ **Uploaded Documents:**");
      for (final doc in uploadedDocuments) {
        buffer.writeln(
          '- ${_getDocumentTypeDisplayName(doc.type)}: ${doc.fileName} (${_getStatusDisplayText(doc.status)})',
        );
      }
      buffer.writeln();
    }

    if (remainingTypes.isNotEmpty) {
      buffer.writeln("❗ **Remaining Documents Needed:**");
      for (final type in _prioritizeDocumentTypes(remainingTypes)) {
        buffer.writeln(
          '- ${_getDocumentTypeDisplayName(type)}: ${_getDocumentExplanation(type)}',
        );
      }
      buffer.writeln(_getNextStepsRecommendation(uploadedDocuments));
    } else {
      buffer.writeln("🎉 **All required documents uploaded!**");
    }

    return buffer.toString();
  }

  Future<String> generateResponseWithDocumentGuidance(
    String userMessage,
    List<Map<String, String>> conversationHistory,
    List<Document> uploadedDocuments,
  ) async {
    try {
      final documentGuidanceContent = getDocumentUploadGuidance(
        uploadedDocuments,
      );
      final contextPrompt = _buildContextPrompt(
        userMessage,
        conversationHistory,
        uploadedDocuments,
      );

      final fullPrompt =
          '''
$documentGuidanceContent

$contextPrompt

Please provide a helpful response that addresses the user's question while being aware of their document upload progress. If they need guidance on uploading documents, provide it. If all documents are uploaded, focus on their question about the documents.
''';

      final messages = [
        {'role': 'system', 'content': _getSystemPrompt()},
        ...conversationHistory.take(8), // Reduced to prevent context overflow
        {'role': 'user', 'content': fullPrompt},
      ];

      return await _makeOpenAIRequest(messages);
    } catch (e) {
      throw Exception('Failed to generate response with document guidance: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
