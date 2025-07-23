import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:x3_gui/models/document_model.dart';
import 'package:x3_gui/models/agentanalysis_model.dart';

/// Represents the state of individual messages: either from user or LLM
class ChatMessage {
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
  });
}

// NEW: Create a data class to hold completed analysis
class CompletedAnalysisData extends Equatable {
  final List<AnalysisResults> analysisResults;
  final String consolidatedCreditScore;

  const CompletedAnalysisData({
    required this.analysisResults,
    required this.consolidatedCreditScore,
  });

  @override
  List<Object> get props => [analysisResults, consolidatedCreditScore];
}

abstract class ChatState {
  final List<ChatMessage> messages;
  final List<Document> uploadedDocuments;
  final CompletedAnalysisData? completedAnalysis;
  final bool isTtsSpeaking;
  final bool isRecording; // NEW: Add recording state

  const ChatState(
    this.messages, {
    this.uploadedDocuments = const [],
    this.completedAnalysis,
    this.isTtsSpeaking = false,
    this.isRecording = false, // NEW: Default to false
  });
}

class ChatInitial extends ChatState {
  ChatInitial() : super([]);
}

class ChatLoaded extends ChatState {
  ChatLoaded(
    List<ChatMessage> messages, {
    List<Document> uploadedDocuments = const [],
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

class ChatLoading extends ChatState {
  ChatLoading(
    List<ChatMessage> messages, {
    List<Document> uploadedDocuments = const [],
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

class ChatError extends ChatState {
  final String error;
  ChatError(
    this.error,
    List<ChatMessage> messages, {
    List<Document> uploadedDocuments = const [],
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

//State for document operations
class DocumentUploading extends ChatState {
  final String fileName;
  DocumentUploading(
    List<ChatMessage> messages,
    this.fileName, {
    List<Document> uploadedDocuments = const [],
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

//// New state for when all 4 documents are uploaded and can be analyzed
class ChatReadyForAnalysis extends ChatState {
  ChatReadyForAnalysis(
    List<ChatMessage> messages, {
    required List<Document> uploadedDocuments,
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

// New state for when analysis is running with real-time updates
class ChatAnalysisRunning extends ChatState {
  final List<AnalysisResults> currentAnalysisResults;

  ChatAnalysisRunning(
    List<ChatMessage> messages, {
    required List<Document> uploadedDocuments,
    required this.currentAnalysisResults,
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

// New state for when analysis is complete
class ChatAnalysisComplete extends ChatState {
  final List<AnalysisResults> analysisResults;
  final String consolidatedCreditScore;

  ChatAnalysisComplete(
    List<ChatMessage> messages, {
    required List<Document> uploadedDocuments,
    required this.analysisResults,
    required this.consolidatedCreditScore,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: CompletedAnalysisData(
           analysisResults: analysisResults,
           consolidatedCreditScore: consolidatedCreditScore,
         ),
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}

class ChatBureauAwaitingApproval extends ChatState {
  final AnalysisResults bureauResult;
  final List<AnalysisResults> fullResults; // Add this field

  ChatBureauAwaitingApproval(
    List<ChatMessage> messages, {
    required List<Document> uploadedDocuments,
    required this.bureauResult,
    required this.fullResults, // Add this parameter
    CompletedAnalysisData? completedAnalysis,
    bool isTtsSpeaking = false,
    bool isRecording = false, // NEW: Add this
  }) : super(
         messages,
         uploadedDocuments: uploadedDocuments,
         completedAnalysis: completedAnalysis,
         isTtsSpeaking: isTtsSpeaking,
         isRecording: isRecording, // NEW: Add this
       );
}
