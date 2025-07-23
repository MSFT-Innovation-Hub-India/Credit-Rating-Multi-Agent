import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';
import 'package:x3_gui/models/document_model.dart';
import 'package:x3_gui/models/agentanalysis_model.dart';
import 'package:x3_gui/services/chat_llm_service.dart'; // CORRECT: Still using Gemini
import 'package:x3_gui/services/document_storage_service.dart';
import 'package:x3_gui/services/agent_orchestration_service.dart';
import 'package:x3_gui/services/tts_service.dart';
import 'package:x3_gui/services/speech_recording_service.dart';
import 'dart:async';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GeminiService _geminiService; // CORRECT: Still using Gemini
  final DocumentStorageService _documentService;
  final AgentOrchestrationService _agentOrchestrationService;
  final TTSService _ttsService;
  final SpeechRecordingService _speechService;
  StreamSubscription<List<AnalysisResults>>? _analysisSubscription;

  ChatBloc(
    this._geminiService,
    this._documentService,
    this._agentOrchestrationService,
    this._ttsService,
    this._speechService,
  ) : super(ChatInitial()) {
    print('DEBUG: ChatBloc constructor called');

    // Initialize services
    _initializeServices();

    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    on<UploadDocumentEvent>(_onUploadDocument);
    on<RemoveDocumentEvent>(_onRemoveDocument);
    on<StartAnalysisEvent>(_onStartAnalysis);
    on<ApproveAndContinueEvent>(_onApproveAndContinue);
    on<StartTtsEvent>(_onStartTts);
    on<StopTtsEvent>(_onStopTts);
    on<TtsStartedEvent>(_onTtsStarted);
    on<TtsCompletedEvent>(_onTtsCompleted);
    on<_AnalysisUpdateEvent>(_onAnalysisUpdate);
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<SpeechTranscriptionEvent>(_onSpeechTranscription);
    on<RequestAgentExplanationEvent>(_onRequestAgentExplanation);

    // In ChatBloc constructor, add:
    on<TtsAudioPlayingEvent>(_onTtsAudioPlaying);
    on<TtsAudioPausedEvent>(_onTtsAudioPaused);

    // In ChatBloc constructor, add these event handlers:
    on<CancelRecordingEvent>(_onCancelRecording);
    on<RecordingStartedEvent>(_onRecordingStarted);
    on<RecordingStoppedEvent>(_onRecordingFinished);
    on<RecordingErrorEvent>(_onRecordingError);

    _analysisSubscription = _agentOrchestrationService.analysisStream.listen((
      results,
    ) {
      add(_AnalysisUpdateEvent(results));
    });

    _setupTtsCompletionListener();

    print(
      'DEBUG: Event handlers registered - UploadDocumentEvent handler: ${_onUploadDocument}',
    );
  }

  // Initialize and pre-warm services
  Future<void> _initializeServices() async {
    try {
      await _ttsService.initialize();
      await _speechService.initialize(); // NEW: Initialize STT service

      // NEW: Set up STT callbacks
      _speechService.setCallbacks(
        onRecordingStarted: () => add(RecordingStartedEvent()),
        onRecordingStopped: () => add(RecordingStoppedEvent()),
        onTranscriptionReceived: (text) => add(SpeechTranscriptionEvent(text)),
        onRecordingError: (error) => add(RecordingErrorEvent(error)),
      );

      print('TTS and STT services initialized successfully');
    } catch (e) {
      print('Failed to initialize speech services: $e');
    }
  }

  void _setupTtsCompletionListener() {
    _ttsService.setCompletionHandler(() {
      add(TtsCompletedEvent());
    });

    _ttsService.setStartedHandler(() {
      add(TtsStartedEvent());
    });

    // NEW: Listen to actual audio playback state
    _ttsService.setAudioPlayingHandler(() {
      add(TtsAudioPlayingEvent());
    });

    _ttsService.setAudioPausedHandler(() {
      add(TtsAudioPausedEvent());
    });
  }

  @override
  Future<void> close() {
    _analysisSubscription?.cancel();
    _agentOrchestrationService.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    return super.close();
  }

  //MARK: Messages
  //THIS IS THE IMPORTANT METHOD THAT HANDELS THE ENTIRE BUSINESS LOGIC OF THE CHAT
  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    //Step 1: Get current state
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    //Step 2: Create an object for the message the user is sending to the LLM
    final userMessage = ChatMessage(
      content: event.message,
      isUserMessage: true,
      timestamp: DateTime.now(),
    );

    // STEP 3: Immediately show user message + loading
    final updatedMessages = [...currentMessages, userMessage];

    // NEW: STEP 3.5 Stop any current TTS when user sends a new message
    await _ttsService.stop();

    emit(
      ChatLoading(
        updatedMessages,
        uploadedDocuments: currentDocuments,
        completedAnalysis: currentCompletedAnalysis,
        isTtsSpeaking: false, //Sets TTS to false when loading
      ),
    ); //UI will display USER MESSAGE + LOADING SPINNER

    //Step 4: Call the LLM service to get a response WITH CONTEXT
    try {
      // Convert chat messages to conversation history format
      final conversationHistory = currentMessages
          .map(
            (msg) => {
              'role': msg.isUserMessage ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();

      // Use context-aware generation that includes uploaded documents
      final isDocumentRelatedQuery = event.message.toLowerCase().contains(
        RegExp(
          r'\b(document|upload|file|progress|status|need|require|what.*next|help.*upload)\b',
        ),
      );

      // Use context-aware generation that includes uploaded documents
      final response = isDocumentRelatedQuery || currentDocuments.isEmpty
          ? await _geminiService.generateResponseWithDocumentGuidance(
              event.message,
              conversationHistory,
              currentDocuments,
            )
          : await _geminiService.generateResponseWithContext(
              event.message,
              conversationHistory,
              currentDocuments,
            );

      //Step 5: Create an object for the LLM response
      final llmMessage = ChatMessage(
        content: response,
        isUserMessage: false,
        timestamp: DateTime.now(),
      );

      //Step 6: Update the state with the new messages
      final finalMessages = [...updatedMessages, llmMessage];

      //NEW: Step 6.5: Emit ChatLoaded first, then start TTS after a delay

      emit(
        ChatLoaded(
          finalMessages,
          uploadedDocuments: currentDocuments,
          completedAnalysis: currentCompletedAnalysis,
          isTtsSpeaking: false, //Initially false
        ),
      ); //UI will display USER MESSAGE + LLM RESPONSE

      // FIXED: Start TTS immediately (state will update via TtsStartedEvent)
      _ttsService.speak(response);
    } catch (e) {
      //Step 7: Handle errors and update state accordingly
      emit(
        ChatError(
          e.toString(),
          updatedMessages,
          uploadedDocuments: currentDocuments,
          completedAnalysis: currentCompletedAnalysis,
          isTtsSpeaking: false, //Sets TTS to false on error
        ),
      );
    }
  }

  List<ChatMessage> _getCurrentMessages() {
    // This method should retrieve the current messages from the state.
    // For simplicity, we assume the state is ChatLoaded or ChatLoading.
    if (state is ChatLoaded) {
      return (state as ChatLoaded).messages;
    } else if (state is ChatLoading) {
      return (state as ChatLoading).messages;
    } else if (state is ChatError) {
      return (state as ChatError).messages;
    }
    return []; // Return an empty list if no messages are present
  }

  void _onClearChat(ClearChatEvent event, Emitter<ChatState> emit) {
    _ttsService.stop(); // Stop TTS when clearing chat
    emit(ChatLoaded([])); //Set chat to a loaded empty list
  }

  //MARK: Documents
  Future<void> _onUploadDocument(
    UploadDocumentEvent event,
    Emitter<ChatState> emit,
  ) async {
    print('DEBUG: _onUploadDocument called with file: ${event.file.path}');
    print('DEBUG: Current state: ${state.runtimeType}');

    try {
      print('DEBUG: About to emit DocumentUploading state');

      // Check current state and get messages safely
      final currentMessages = switch (state) {
        ChatLoaded(messages: final messages) => messages,
        DocumentUploading(messages: final messages) => messages,
        _ => <ChatMessage>[],
      };

      final currentDocuments = switch (state) {
        ChatLoaded(uploadedDocuments: final docs) => docs,
        DocumentUploading(uploadedDocuments: final docs) => docs,
        _ => <Document>[],
      };

      emit(
        DocumentUploading(
          currentMessages,
          path.basename(event.file.path),
          uploadedDocuments: currentDocuments,
        ),
      );

      print('DEBUG: DocumentUploading state emitted successfully');

      // Upload the document using the service
      print('DEBUG: Starting document service upload');
      final document = await _documentService.uploadDocument(
        event.file,
        event.expectedType,
      );

      print('DEBUG: Document upload completed: ${document.id}');

      // Update the state with the new document
      final updatedDocuments = [...currentDocuments, document];

      print(
        'DEBUG: Emitting ChatLoaded state with ${updatedDocuments.length} documents',
      );

      // Only emit ChatReadyForAnalysis state, no system message
      if (_hasAllRequiredDocuments(updatedDocuments)) {
        emit(
          ChatReadyForAnalysis([
            ...currentMessages,
          ], uploadedDocuments: updatedDocuments),
        );
      } else {
        emit(
          ChatLoaded([...currentMessages], uploadedDocuments: updatedDocuments),
        );
      }

      print('DEBUG: ChatLoaded state emitted successfully');
    } catch (e, stackTrace) {
      print('ERROR: Document upload failed: $e');
      print('ERROR: Stack trace: $stackTrace');

      // Get current messages safely for error state
      final currentMessages = switch (state) {
        ChatLoaded(messages: final messages) => messages,
        DocumentUploading(messages: final messages) => messages,
        _ => <ChatMessage>[],
      };

      final currentDocuments = switch (state) {
        ChatLoaded(uploadedDocuments: final docs) => docs,
        DocumentUploading(uploadedDocuments: final docs) => docs,
        _ => <Document>[],
      };

      // Add system message about failed upload
      final errorMessage = ChatMessage(
        content: "❌ Failed to upload document: $e",
        isUserMessage: false,
        timestamp: DateTime.now(),
      );

      emit(
        ChatLoaded([
          ...currentMessages,
          errorMessage,
        ], uploadedDocuments: currentDocuments),
      );
    }
  }

  Future<void> _onRemoveDocument(
    RemoveDocumentEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _documentService.deleteDocument(event.documentId);
      final updatedDocuments = state.uploadedDocuments
          .where((doc) => doc.id != event.documentId)
          .toList();

      emit(ChatLoaded(state.messages, uploadedDocuments: updatedDocuments));
    } catch (e) {
      emit(
        ChatError(
          "Failed to remove document: $e",
          state.messages,
          uploadedDocuments: state.uploadedDocuments,
        ),
      );
    }
  }

  //MARK: ValidationDocs
  bool _hasAllRequiredDocuments(List<Document> documents) {
    final requiredTypes = {
      DocumentType.qualitativeBusiness,
      DocumentType.balanceSheet,
      DocumentType.cashFlow,
      DocumentType.profitLoss,
      DocumentType.earningsCall,
    };

    final uploadedTypes = documents.map((doc) => doc.type).toSet();
    return requiredTypes.every((type) => uploadedTypes.contains(type));
  }

  ////MARK: Agent Analysis
  /// This event is used to start the analysis process --> API Call to Azure Agents
  Future<void> _onStartAnalysis(
    StartAnalysisEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatReadyForAnalysis) return;

    try {
      // No system message, just emit running state
      final currentMessages = [...state.messages];
      emit(
        ChatAnalysisRunning(
          currentMessages,
          uploadedDocuments: state.uploadedDocuments,
          currentAnalysisResults: [],
        ),
      );

      // Run full analysis
      final results = await _agentOrchestrationService.runFullAnalysis(
        state.uploadedDocuments,
      );

      // Find bureau summarizer result
      final bureauResult = results.firstWhere(
        (result) => result.agentName == 'Bureau Summariser',
        orElse: () => throw Exception('Bureau Summariser results missing'),
      );

      // Transition to bureau awaiting approval, no system message
      emit(
        ChatBureauAwaitingApproval(
          [...currentMessages],
          uploadedDocuments: state.uploadedDocuments,
          bureauResult: bureauResult,
          fullResults: results, // Store all results here!
        ),
      );
    } catch (e) {
      emit(
        ChatError(
          "Failed to start analysis: $e",
          state.messages,
          uploadedDocuments: state.uploadedDocuments,
        ),
      );
    }
  }

  Future<void> _onApproveAndContinue(
    ApproveAndContinueEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatBureauAwaitingApproval) return;

    final awaitingState = state as ChatBureauAwaitingApproval;

    try {
      // No approval system message
      final currentMessages = [...awaitingState.messages];

      // Use the results we already have instead of making another API call
      final fullResults = awaitingState.fullResults;

      // Extract credit score
      final creditScore =
          fullResults
              .firstWhere(
                (result) => result.agentName == 'Credit Score Rating',
                orElse: () => AnalysisResults(
                  agentName: 'Credit Score Rating',
                  agentDescription: '',
                  extractedData: {'credit_score': 'N/A'},
                  summary: '',
                ),
              )
              .extractedData['credit_score']
              ?.toString() ??
          'N/A';

      // Only emit analysis complete state, no system message
      emit(
        ChatAnalysisComplete(
          [...currentMessages],
          uploadedDocuments: awaitingState.uploadedDocuments,
          analysisResults: fullResults,
          consolidatedCreditScore: creditScore,
        ),
      );
    } catch (e) {
      emit(
        ChatError(
          "Failed to complete analysis: $e",
          awaitingState.messages,
          uploadedDocuments: awaitingState.uploadedDocuments,
        ),
      );
    }
  }

  void _onAnalysisUpdate(_AnalysisUpdateEvent event, Emitter<ChatState> emit) {
    if (state is ChatAnalysisRunning) {
      final runningState = state as ChatAnalysisRunning;
      emit(
        ChatAnalysisRunning(
          runningState.messages,
          uploadedDocuments: runningState.uploadedDocuments,
          currentAnalysisResults: event.analysisResults,
        ),
      );
    } else if (state is ChatReadyForAnalysis) {
      // First update - transition to running state
      emit(
        ChatAnalysisRunning(
          state.messages,
          uploadedDocuments: state.uploadedDocuments,
          currentAnalysisResults: event.analysisResults,
        ),
      );
    }
  }

  // NEW: Handle TTS started event
  Future<void> _onTtsStarted(
    TtsStartedEvent event,
    Emitter<ChatState> emit,
  ) async {
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        true, // TTS is now speaking
      ),
    );
  }

  //MARK: TTS
  Future<void> _onStartTts(StartTtsEvent event, Emitter<ChatState> emit) async {
    await _ttsService.speak(event.text);

    // Update state to reflect TTS is speaking
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        true,
      ),
    );
  }

  Future<void> _onStopTts(StopTtsEvent event, Emitter<ChatState> emit) async {
    await _ttsService.stop();

    // Update state to reflect TTS has stopped
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        false,
      ),
    );
  }

  // NEW: Add TTS completion handler
  Future<void> _onTtsCompleted(
    TtsCompletedEvent event,
    Emitter<ChatState> emit,
  ) async {
    // Update state to reflect TTS has completed
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        false,
      ),
    );
  }

  //These are for animation management (next 2 methods)
  // NEW: Handle actual audio playing event
  Future<void> _onTtsAudioPlaying(
    TtsAudioPlayingEvent event,
    Emitter<ChatState> emit,
  ) async {
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        true, // Audio is actually playing
      ),
    );
  }

  // NEW: Handle audio paused/stopped event
  Future<void> _onTtsAudioPaused(
    TtsAudioPausedEvent event,
    Emitter<ChatState> emit,
  ) async {
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentCompletedAnalysis = state.completedAnalysis;

    emit(
      _createStateWithTts(
        currentMessages,
        currentDocuments,
        currentCompletedAnalysis,
        false, // Audio stopped
      ),
    );
  }

  // NEW: Speech Recording
  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Stop TTS if it's speaking
      await _ttsService.stop();

      await _speechService.startRecording();
      // State will be updated by RecordingStartedEvent callback
    } catch (e) {
      print('Recording failed: $e');
      // Show error message in chat
      final errorMessage = ChatMessage(
        content: "❌ Recording failed: $e",
        isUserMessage: false,
        timestamp: DateTime.now(),
      );

      final currentMessages = _getCurrentMessages();
      emit(
        ChatLoaded(
          [...currentMessages, errorMessage],
          uploadedDocuments: state.uploadedDocuments,
          completedAnalysis: state.completedAnalysis,
        ),
      );
    }
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _speechService.stopRecording();
      // Transcription will be handled by callback
    } catch (e) {
      print('Stop recording failed: $e');
      emit(_createStateWithRecording(false));
    }
  }

  // NEW: Cancel recording handler
  Future<void> _onCancelRecording(
    CancelRecordingEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _speechService.cancelRecording();
      emit(_createStateWithRecording(false));
    } catch (e) {
      print('Cancel recording failed: $e');
      emit(_createStateWithRecording(false));
    }
  }

  // NEW: Recording feedback handlers
  Future<void> _onRecordingStarted(
    RecordingStartedEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(_createStateWithRecording(true));
  }

  Future<void> _onRecordingFinished(
    RecordingStoppedEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(_createStateWithRecording(false));
  }

  Future<void> _onRecordingError(
    RecordingErrorEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(_createStateWithRecording(false));

    // Show error in chat
    final errorMessage = ChatMessage(
      content: "🎤 Recording error: ${event.error}",
      isUserMessage: false,
      timestamp: DateTime.now(),
    );

    final currentMessages = _getCurrentMessages();
    emit(
      ChatLoaded(
        [...currentMessages, errorMessage],
        uploadedDocuments: state.uploadedDocuments,
        completedAnalysis: state.completedAnalysis,
      ),
    );
  }

  Future<void> _onSpeechTranscription(
    SpeechTranscriptionEvent event,
    Emitter<ChatState> emit,
  ) async {
    // Auto-send the transcribed message
    add(
      SendMessageEvent(
        event.transcription,
        attachedDocuments: state.uploadedDocuments,
      ),
    );
  }

  ChatState _createStateWithRecording(bool isRecording) {
    final currentMessages = _getCurrentMessages();
    final currentDocuments = state.uploadedDocuments;
    final currentAnalysis = state.completedAnalysis;
    final isTtsSpeaking = state.isTtsSpeaking;

    if (state is ChatAnalysisRunning) {
      return ChatAnalysisRunning(
        currentMessages,
        uploadedDocuments: currentDocuments,
        currentAnalysisResults:
            (state as ChatAnalysisRunning).currentAnalysisResults,
        completedAnalysis: currentAnalysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    } else if (state is ChatLoaded) {
      return ChatLoaded(
        currentMessages,
        uploadedDocuments: currentDocuments,
        completedAnalysis: currentAnalysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    } else if (state is ChatReadyForAnalysis) {
      return ChatReadyForAnalysis(
        currentMessages,
        uploadedDocuments: currentDocuments,
        completedAnalysis: currentAnalysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    }

    return ChatLoaded(
      currentMessages,
      uploadedDocuments: currentDocuments,
      completedAnalysis: currentAnalysis,
      isTtsSpeaking: isTtsSpeaking,
      isRecording: isRecording,
    );
  }

  // Update all existing state creation methods to include isRecording
  ChatState _createStateWithTts(
    List<ChatMessage> messages,
    List<Document> documents,
    CompletedAnalysisData? analysis,
    bool isTtsSpeaking,
  ) {
    final isRecording = state.isRecording; // Preserve recording state

    if (state is ChatAnalysisRunning) {
      return ChatAnalysisRunning(
        messages,
        uploadedDocuments: documents,
        currentAnalysisResults:
            (state as ChatAnalysisRunning).currentAnalysisResults,
        completedAnalysis: analysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    } else if (state is ChatAnalysisComplete) {
      return ChatAnalysisComplete(
        messages,
        uploadedDocuments: documents,
        analysisResults: (state as ChatAnalysisComplete).analysisResults,
        consolidatedCreditScore:
            (state as ChatAnalysisComplete).consolidatedCreditScore,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    } else if (state is ChatReadyForAnalysis) {
      return ChatReadyForAnalysis(
        messages,
        uploadedDocuments: documents,
        completedAnalysis: analysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    } else {
      return ChatLoaded(
        messages,
        uploadedDocuments: documents,
        completedAnalysis: analysis,
        isTtsSpeaking: isTtsSpeaking,
        isRecording: isRecording,
      );
    }
  }

  //MARK: Expln Req
  Future<void> _onRequestAgentExplanation(
    RequestAgentExplanationEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Preserve current state
      List<ChatMessage> currentMessages = state.messages;
      List<Document> documents = state.uploadedDocuments;
      List<AnalysisResults> currentResults;

      if (state is ChatAnalysisRunning) {
        currentResults = (state as ChatAnalysisRunning).currentAnalysisResults;
      } else if (state is ChatAnalysisComplete) {
        currentResults = (state as ChatAnalysisComplete).analysisResults;
      } else {
        // Invalid state for this operation
        return;
      }

      // Call the appropriate explanation method based on agent name
      AnalysisResults explanation;
      switch (event.agentName) {
        case 'Fraud Detection':
          explanation = await _agentOrchestrationService
              .getFraudDetectionExplanation();
          break;
        case 'Compliance':
          explanation = await _agentOrchestrationService
              .getComplianceExplanation();
          break;
        default:
          explanation = await _agentOrchestrationService.getAgentExplanation(
            event.agentName,
          );
          break;
      }

      // Update the results with the explanation
      final updatedResults = List<AnalysisResults>.from(currentResults);
      final index = updatedResults.indexWhere(
        (agent) => agent.agentName == event.agentName,
      );

      if (index != -1) {
        updatedResults[index] = explanation;
      } else {
        updatedResults.add(explanation);
      }

      // Emit updated state
      if (state is ChatAnalysisRunning) {
        emit(
          ChatAnalysisRunning(
            currentMessages,
            uploadedDocuments: documents,
            currentAnalysisResults: updatedResults,
          ),
        );
      } else if (state is ChatAnalysisComplete) {
        emit(
          ChatAnalysisComplete(
            currentMessages,
            uploadedDocuments: documents,
            analysisResults: updatedResults,
            consolidatedCreditScore:
                (state as ChatAnalysisComplete).consolidatedCreditScore,
          ),
        );
      }
    } catch (e) {
      print('Error requesting agent explanation: $e');
      // Don't emit error state - just log to prevent disrupting the UI
    }
  }
}

// Internal event for analysis updates
class _AnalysisUpdateEvent extends ChatEvent {
  final List<AnalysisResults> analysisResults;

  const _AnalysisUpdateEvent(this.analysisResults);

  @override
  List<Object> get props => [analysisResults];
}
