import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:x3_gui/chat/bloc/chat_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';
import 'package:x3_gui/models/document_model.dart';
import 'package:x3_gui/chat/widgets/document_upload_widget.dart';
import 'package:x3_gui/chat/widgets/animations/listening_blob_widget.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;
  bool _showAnalysisPanel = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final isLoading = state is ChatLoading || state is DocumentUploading;
        final hasDocuments = state.uploadedDocuments.isNotEmpty;
        final hasCompletedAnalysis = state.completedAnalysis != null;
        final isRecording = state.isRecording; // NEW: Get recording state

        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF223A5E), // Navy
                const Color(0xFF335C81), // Muted blue
              ], // Darker, elegant background
            ),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF223A5E).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF223A5E).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Document uploading indicator
              if (state is DocumentUploading)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF6A89A7).withValues(alpha: 0.15),
                        const Color(0xFF6A89A7).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6A89A7).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6A89A7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Uploading ${state.fileName}...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // NEW: Recording indicator with listening blob
              if (isRecording) const ListeningBlobWidget(),

              // Main input container
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFF5F8FA), // Light blue
                      Colors.white,
                    ], // Light input for contrast
                  ),
                  border: Border.all(
                    color: const Color(0xFF335C81).withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF335C81).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Document upload button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF223A5E).withValues(alpha: 0.18),
                            const Color(0xFF335C81).withValues(alpha: 0.12),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF223A5E).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _showUploadOptions(context),
                        icon: Icon(
                          Icons.attach_file_rounded,
                          size: 20,
                          color: const Color(0xFF6A89A7),
                        ),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                        tooltip: 'Attach Document',
                      ),
                    ),

                    // Text input field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled:
                            !isLoading &&
                            !isRecording, // NEW: Disable during recording
                        style: const TextStyle(
                          color: Color(0xFF384959), // Dark blue text
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: isRecording
                              ? 'Recording... Release to send' // NEW: Recording placeholder
                              : isLoading
                              ? 'Processing your request...'
                              : hasDocuments
                              ? 'Ask about your attached documents...'
                              : 'Ask about your financial documents...',
                          hintStyle: TextStyle(
                            color: const Color(
                              0xFF384959,
                            ).withValues(alpha: 0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() {
                            _isComposing = text.isNotEmpty;
                          });
                        },
                        onSubmitted: isLoading || isRecording
                            ? null
                            : _handleSubmit,
                      ),
                    ),

                    // Analysis panel toggle (if available)
                    if (hasCompletedAnalysis) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF223A5E).withValues(alpha: 0.18),
                              const Color(0xFF335C81).withValues(alpha: 0.12),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF223A5E,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showAnalysisPanel = !_showAnalysisPanel;
                            });
                            ChatAnalysisVisibility.of(
                              context,
                            )?.updateVisibility(_showAnalysisPanel);
                          },
                          icon: Icon(
                            _showAnalysisPanel
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: const Color(0xFF6A89A7),
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.all(6),
                          ),
                          tooltip: _showAnalysisPanel
                              ? 'Hide Analysis'
                              : 'Show Analysis',
                        ),
                      ),
                    ],

                    // NEW: Microphone button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: isRecording
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF335C81),
                                  const Color(0xFF223A5E),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF223A5E,
                                  ).withValues(alpha: 0.85),
                                  const Color(
                                    0xFF335C81,
                                  ).withValues(alpha: 0.85),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isRecording
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF335C81,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: IconButton(
                        onPressed: isLoading ? null : _handleMicrophonePress,
                        icon: Icon(
                          isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: isRecording ? 'Stop Recording' : 'Voice Input',
                      ),
                    ),

                    // Send button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient:
                            ((_isComposing || hasDocuments) &&
                                !isLoading &&
                                !isRecording)
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF223A5E),
                                  const Color(0xFF335C81),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  const Color(0xFFB0B0B0),
                                  const Color(0xFFE0E0E0),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow:
                            ((_isComposing || hasDocuments) &&
                                !isLoading &&
                                !isRecording)
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF223A5E,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: IconButton(
                        onPressed:
                            (isLoading ||
                                isRecording ||
                                (!_isComposing && !hasDocuments))
                            ? null
                            : () => _handleSubmit(
                                _controller.text.isEmpty
                                    ? "Tell me about these documents"
                                    : _controller.text,
                              ),
                        icon: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF6A89A7),
                                      ),
                                ),
                              )
                            : Icon(Icons.send_rounded, size: 20),
                        color:
                            ((_isComposing || hasDocuments) &&
                                !isLoading &&
                                !isRecording)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: Handle microphone button press
  Future<void> _handleMicrophonePress() async {
    final bloc = context.read<ChatBloc>();

    if (bloc.state.isRecording) {
      // Stop recording
      bloc.add(StopRecordingEvent());
    } else {
      // Start recording
      bloc.add(StartRecordingEvent());
    }
  }

  void _handleSubmit(String text) {
    final finalText = text.trim().isEmpty
        ? "Tell me about these documents"
        : text.trim();

    final bloc = context.read<ChatBloc>();
    bloc.add(
      SendMessageEvent(
        finalText,
        attachedDocuments: bloc.state.uploadedDocuments,
      ),
    );

    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  void _showUploadOptions(BuildContext context) {
    final chatBloc = context.read<ChatBloc>();

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => DocumentUploadBottomSheet(
        onDocumentTypeSelected: (type) async {
          await _pickAndUploadFile(chatBloc, type, context);
        },
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFF2A2A2A),
    );
  }

  Future<void> _pickAndUploadFile(
    ChatBloc chatBloc,
    DocumentType expectedType,
    BuildContext parentContext,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'xlsx',
          'xls',
          'csv',
          'txt',
          'docx',
          'mp3',
          'wav',
          'm4a',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        final event = UploadDocumentEvent(file, expectedType);
        chatBloc.add(event);

        // Add listener to dismiss any notifications when upload completes
        late StreamSubscription subscription;
        subscription = chatBloc.stream.listen((state) {
          if (state is ChatLoaded ||
              state is ChatReadyForAnalysis ||
              state is ChatError) {
            subscription.cancel();
          }
        });
      }
    } catch (e) {
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: const Color(0xFFE53E3E),
          ),
        );
      }
    }
  }
}

//Mark: AnalysisVisibility
class ChatAnalysisVisibility extends InheritedWidget {
  final bool showAnalysisPanel;
  final ValueChanged<bool>? onVisibilityChanged;

  const ChatAnalysisVisibility({
    super.key,
    required this.showAnalysisPanel,
    this.onVisibilityChanged,
    required super.child,
  });

  static ChatAnalysisVisibility? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatAnalysisVisibility>();
  }

  void updateVisibility(bool visible) {
    onVisibilityChanged?.call(visible);
  }

  @override
  bool updateShouldNotify(ChatAnalysisVisibility oldWidget) {
    return showAnalysisPanel != oldWidget.showAnalysisPanel;
  }
}
