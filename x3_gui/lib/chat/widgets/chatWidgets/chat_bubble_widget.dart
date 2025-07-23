import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_state.dart';
import '../animations/animated_blob_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Replace LLM messages with animated blob
    if (!message.isUserMessage) {
      return AnimatedBlobWidget(message: message);
    }

    // Keep existing user message bubble
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF223A5E), // Dark navy blue
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF223A5E).withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: Colors.white, // White text for contrast
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }
}
