import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:x3_gui/models/document_model.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class SendMessageEvent extends ChatEvent {
  /*
This event is the main thing for Chat Logic
This event will trigger:
1. Sending the user message
2. Calling the LLM API Service
3. Receiving the response from the LLM API Service
4. Update state with both messages (Sent and Response)
*/

  final String message;
  final List<Document>? attachedDocuments;
  const SendMessageEvent(this.message, {this.attachedDocuments});

  @override
  List<Object> get props => [message];
}

class ClearChatEvent extends ChatEvent {}

//MARK: Doc Events
class UploadDocumentEvent extends ChatEvent {
  final File file;
  final DocumentType expectedType;
  UploadDocumentEvent(this.file, this.expectedType);

  @override
  List<Object> get props => [file, expectedType];
}

class RemoveDocumentEvent extends ChatEvent {
  final String documentId;
  RemoveDocumentEvent(this.documentId);
}

//MARK: Analysis Events
// This event is used to start the analysis process --> API Call to Azure Agents
class StartAnalysisEvent extends ChatEvent {}

//TTS
class StartTtsEvent extends ChatEvent {
  final String text;
  StartTtsEvent(this.text);
}

class StopTtsEvent extends ChatEvent {}

// NEW: Add this event for TTS completion
class TtsCompletedEvent extends ChatEvent {}

// Add this new event after existing events

class ApproveAndContinueEvent extends ChatEvent {
  const ApproveAndContinueEvent();
}

//MARK: STT
class StartRecordingEvent extends ChatEvent {}

class StopRecordingEvent extends ChatEvent {}

class RequestAgentExplanationEvent extends ChatEvent {
  final String agentName;

  const RequestAgentExplanationEvent(this.agentName);
}

class CancelRecordingEvent extends ChatEvent {}

class SpeechTranscriptionEvent extends ChatEvent {
  final String transcription;
  SpeechTranscriptionEvent(this.transcription);

  @override
  List<Object> get props => [transcription];
}

// NEW: Real-time recording feedback events
class RecordingStartedEvent extends ChatEvent {}

class RecordingStoppedEvent extends ChatEvent {}

class RecordingErrorEvent extends ChatEvent {
  final String error;
  RecordingErrorEvent(this.error);

  @override
  List<Object> get props => [error];
}

//MARK: TTS
//For animation synchronisations
class TtsStartedEvent extends ChatEvent {
  const TtsStartedEvent();

  @override
  List<Object> get props => [];
}

class TtsAudioPlayingEvent extends ChatEvent {
  const TtsAudioPlayingEvent();

  @override
  List<Object> get props => [];
}

class TtsAudioPausedEvent extends ChatEvent {
  const TtsAudioPausedEvent();

  @override
  List<Object> get props => [];
}
