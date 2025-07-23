import 'package:x3_gui/models/document_model.dart';

abstract class LLMServiceInterface {
  Future<String> generateResponse(
    String prompt,
  ); // Method to generate a response from the LLM based on the provided prompt

  // Method to generate a response from the LLM with context from conversation history and uploaded documents
  Future<String> generateResponseWithContext(
    String prompt,
    List<Map<String, String>> conversationHistory,
    List<Document> uploadedDocuments,
  );

  // Method to get guidance for uploading documents based on the uploaded documents
  String getDocumentUploadGuidance(List<Document> uploadedDocuments);
}
