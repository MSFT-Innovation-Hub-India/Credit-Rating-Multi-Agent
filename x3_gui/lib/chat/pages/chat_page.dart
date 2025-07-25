import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';
import 'package:x3_gui/services/azure_openai_service.dart'; // UPDATED: Now using Azure OpenAI
import 'package:x3_gui/services/document_storage_service.dart';
import 'package:x3_gui/chat/widgets/chat_widgets_barrel.dart';
import 'package:x3_gui/chat/widgets/document_status_widget.dart';
import 'package:x3_gui/services/agent_orchestration_service.dart';
import 'package:x3_gui/services/tts_service.dart';
import 'package:x3_gui/services/speech_recording_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        AzureOpenAIService(), // UPDATED: Now using Azure OpenAI instead of Gemini
        DocumentStorageService(),
        AgentOrchestrationService(),
        TTSService(),
        SpeechRecordingService(), // NEW: Add speech service
      ),
      child: const ChatView(),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  bool _showAnalysisPanel = true; // Local state

  @override
  Widget build(BuildContext context) {
    return ChatAnalysisVisibility(
      showAnalysisPanel: _showAnalysisPanel,
      onVisibilityChanged: (bool visible) {
        setState(() {
          _showAnalysisPanel = visible;
        });
      },
      child: Scaffold(
        appBar: const ChatAppBar(),
        body: Stack(
          children: [
            // Main chat layout
            const Column(
              children: [
                DocumentStatusWidget(),
                AnalysisButtonWidget(),
                SizedBox(height: 8),
                Expanded(child: ChatMessagesList()),
                ChatInput(),
              ],
            ),

            // Large modal overlay covering DocumentStatusWidget and ChatMessagesList
            if (_shouldShowAnalysisPanel()) _buildLargeAnalysisModal(),
          ],
        ),
      ),
    );
  }

  bool _shouldShowAnalysisPanel() {
    return _showAnalysisPanel &&
        context.select<ChatBloc, bool>((bloc) {
          final state = bloc.state;
          return (state is ChatBureauAwaitingApproval) ||
              (state is ChatAnalysisRunning) ||
              (state is ChatAnalysisComplete) ||
              (state.completedAnalysis != null);
        });
  }

  Widget _buildLargeAnalysisModal() {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(40),
                height: MediaQuery.of(context).size.height * 0.95,
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Credit Analysis Results',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showAnalysisPanel = false;
                              });
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Close Analysis',
                          ),
                        ],
                      ),
                    ),

                    // Analysis panel content with proper scrolling
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildAnalysisPanel(state),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisPanel(ChatState state) {
    if (state is ChatBureauAwaitingApproval) {
      return AnalysisTreeWidget(
        analysisResults: [state.bureauResult],
        consolidatedCreditScore: 'Awaiting Approval...',
        isRunning: false,
        showApprovalButton: true,
        onApprovalTap: () {
          context.read<ChatBloc>().add(const ApproveAndContinueEvent());
        },
        onBureauApprove: () {
          context.read<ChatBloc>().add(const ApproveAndContinueEvent());
        },
        onRequestAgentExplanation: (agentName) {
          context.read<ChatBloc>().add(RequestAgentExplanationEvent(agentName));
        },
      );
    } else if (state is ChatAnalysisRunning) {
      return AnalysisTreeWidget(
        analysisResults: state.currentAnalysisResults,
        consolidatedCreditScore: 'Analyzing...',
        isRunning: true,
        showApprovalButton: false,
        onRequestAgentExplanation: (agentName) {
          context.read<ChatBloc>().add(RequestAgentExplanationEvent(agentName));
        },
      );
    } else if (state is ChatAnalysisComplete) {
      return AnalysisTreeWidget(
        analysisResults: state.analysisResults,
        consolidatedCreditScore: state.consolidatedCreditScore,
        isRunning: false,
        showApprovalButton: false,
        onMiddleLayerApprove: () {
          // This will just update the UI to show the bottom layer
        },
        onRequestAgentExplanation: (agentName) {
          context.read<ChatBloc>().add(RequestAgentExplanationEvent(agentName));
        },
      );
    }

    return const SizedBox.shrink();
  }
}
