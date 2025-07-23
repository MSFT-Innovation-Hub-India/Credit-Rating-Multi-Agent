import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';

class AnalysisButtonWidget extends StatelessWidget {
  const AnalysisButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state is ChatReadyForAnalysis) {
          return Container(
            margin: const EdgeInsets.all(16.0),
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF88BDF2,
                  ).withValues(alpha: 0.45), // neon blue shadow
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ChatBloc>().add(StartAnalysisEvent());
              },
              icon: const Icon(Icons.analytics, color: Colors.white),
              label: const Text('Start Credit Analysis'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                backgroundColor: const Color(0xFF223A5E), // navy blue
                foregroundColor: Colors.white,
                elevation: 0, // shadow handled by container
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
