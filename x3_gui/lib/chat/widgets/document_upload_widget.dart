import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:x3_gui/chat/bloc/chat_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';
import 'package:x3_gui/models/document_model.dart';

class DocumentUploadWidget extends StatelessWidget {
  const DocumentUploadWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final Color darkBg = const Color(0xFF223A5E);
    final Color accent = const Color(0xFF88BDF2);
    final Color textLight = Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkBg.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showUploadOptions(context),
            icon: Icon(Icons.attach_file, color: accent),
            tooltip: 'Attach Document',
          ),
          Text(
            'Attach financial documents',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    // Get the ChatBloc before opening the bottom sheet
    final chatBloc = context.read<ChatBloc>();

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => DocumentUploadBottomSheet(
        onDocumentTypeSelected: (type) async {
          print('DEBUG: Document type selected: $type');
          await _pickAndUploadFile(chatBloc, type, context);
        },
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  Future<void> _pickAndUploadFile(
    ChatBloc chatBloc,
    DocumentType expectedType,
    BuildContext parentContext,
  ) async {
    try {
      print('DEBUG: Starting file picker for type: $expectedType');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'txt', 'docx'],
        allowMultiple: false,
      );

      print('DEBUG: File picker result: ${result?.files.length ?? 0} files');

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        print('DEBUG: Selected file: ${file.path}');
        print('DEBUG: File exists: ${await file.exists()}');
        print('DEBUG: Using ChatBloc reference: ${chatBloc.runtimeType}');
        print('DEBUG: ChatBloc current state: ${chatBloc.state.runtimeType}');

        // Show loading indicator on parent context
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(parentContext).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Uploading ${result.files.single.name}...'),
                ],
              ),
              duration: const Duration(seconds: 30),
              backgroundColor: Theme.of(parentContext).colorScheme.primary,
            ),
          );
        }

        print('DEBUG: Creating UploadDocumentEvent');
        final event = UploadDocumentEvent(file, expectedType);
        print('DEBUG: Event created: ${event.runtimeType}');
        print('DEBUG: Event file path: ${event.file.path}');
        print('DEBUG: Event expected type: ${event.expectedType}');

        print('DEBUG: Dispatching UploadDocumentEvent to ChatBloc');
        chatBloc.add(event);
        print('DEBUG: Event dispatched successfully');

        // Add listener to dismiss SnackBar when upload completes
        late StreamSubscription subscription;
        subscription = chatBloc.stream.listen((state) {
          if (state is ChatLoaded ||
              state is ChatReadyForAnalysis ||
              state is ChatError) {
            // Dismiss the SnackBar
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).hideCurrentSnackBar();
            }
            subscription.cancel();
          }
        });
      } else {
        print('DEBUG: No file selected or path is null');
      }
    } catch (e, stackTrace) {
      print('ERROR: File picker error: $e');
      print('ERROR: Stack trace: $stackTrace');
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Theme.of(parentContext).colorScheme.error,
          ),
        );
      }
    }
  }
}

class DocumentUploadBottomSheet extends StatelessWidget {
  final Function(DocumentType) onDocumentTypeSelected;

  const DocumentUploadBottomSheet({
    super.key,
    required this.onDocumentTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color darkBg = const Color(0xFF223A5E);
    final Color accent = const Color(0xFF88BDF2);
    final Color textLight = Colors.white;
    final Color textMuted = Colors.white70;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: darkBg.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Financial Document',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select the type of document you\'d like to upload:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textLight),
            ),
            const SizedBox(height: 20),
            _buildDocumentTypeOption(
              context,
              DocumentType.qualitativeBusiness,
              Icons.receipt,
              'Qualitative Business',
              'Business Plan, Executive Summary, Market Analysis',
              accent,
              textLight,
              textMuted,
            ),
            _buildDocumentTypeOption(
              context,
              DocumentType.balanceSheet,
              Icons.account_balance,
              'Balance Sheet',
              'Company\'s financial position',
              accent,
              textLight,
              textMuted,
            ),
            _buildDocumentTypeOption(
              context,
              DocumentType.profitLoss,
              Icons.analytics,
              'Profit & Loss Statement',
              'Company\'s profitability over a period',
              accent,
              textLight,
              textMuted,
            ),
            _buildDocumentTypeOption(
              context,
              DocumentType.cashFlow,
              Icons.money,
              'Cash Flow Statement',
              'Company\'s cash inflows and outflows',
              accent,
              textLight,
              textMuted,
            ),
            _buildDocumentTypeOption(
              context,
              DocumentType.earningsCall,
              Icons.mic,
              'Earnings Call',
              'Company earnings call recording (1-2 minutes)',
              accent,
              textLight,
              textMuted,
            ),
            _buildDocumentTypeOption(
              context,
              DocumentType.other,
              Icons.insert_drive_file,
              'Other Document',
              'Any other financial document',
              accent,
              textLight,
              textMuted,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeOption(
    BuildContext context,
    DocumentType type,
    IconData icon,
    String title,
    String subtitle,
    Color accent,
    Color textLight,
    Color textMuted,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.18),
        child: Icon(icon, color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(color: textLight, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted)),
      onTap: () {
        print('DEBUG: Document type option tapped: $type');
        Navigator.pop(context);
        onDocumentTypeSelected(type);
      },
    );
  }
}
