import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_state.dart';
import 'chat_bubble_widget.dart';

class ChatMessagesList extends StatefulWidget {
  const ChatMessagesList({super.key});

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${state.error}')));
        }
        // Auto-scroll to bottom when new message is added
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
      builder: (context, state) {
        if (state is ChatInitial) {
          return const Center(
            child: Text(
              'Welcome to X³, your AI credit scoring assistant! To start upload the required financial documents or ask a question.',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final messages = _getMessages(state);
        final isLoading = state is ChatLoading;

        // Elegant ListView with padding
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          itemCount: messages.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator
            if (isLoading && index == messages.length) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Show regular chat message
            if (index < messages.length) {
              final message = messages[index];
              return ChatBubble(message: message);
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  List<ChatMessage> _getMessages(ChatState state) {
    if (state is ChatLoaded) return state.messages;
    if (state is ChatLoading) return state.messages;
    if (state is ChatError) return state.messages;
    if (state is ChatReadyForAnalysis) return state.messages;
    if (state is ChatAnalysisRunning) return state.messages;
    if (state is ChatAnalysisComplete) return state.messages;
    return [];
  }
}
