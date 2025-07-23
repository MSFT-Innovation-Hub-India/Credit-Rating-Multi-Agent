import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_bloc.dart';
import 'package:x3_gui/chat/bloc/chat_event.dart';
import 'package:x3_gui/chat/bloc/chat_state.dart';
import 'package:x3_gui/models/document_model.dart';

class DocumentStatusWidget extends StatelessWidget {
  const DocumentStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        // Show uploading indicator
        if (state is DocumentUploading) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Uploading ${state.fileName}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        // Show document progress and list
        if (state.uploadedDocuments.isNotEmpty) {
          final requiredTypes = {
            DocumentType.qualitativeBusiness,
            DocumentType.balanceSheet,
            DocumentType.cashFlow,
            DocumentType.profitLoss,
            DocumentType.earningsCall,
          };

          final uploadedTypes = state.uploadedDocuments
              .map((doc) => doc.type)
              .toSet();
          final progress = uploadedTypes.intersection(requiredTypes).length;
          final isComplete = progress == 5;
          final missingTypes = requiredTypes.difference(uploadedTypes);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: isComplete
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.8)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12.0),
              border: isComplete
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Progress indicator with compact status
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 16,
                          )
                        : Text(
                            '$progress',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Compact document info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isComplete
                                ? 'All Documents Ready'
                                : 'Documents ($progress/5)',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isComplete
                                      ? Colors.black
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          if (isComplete) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.analytics,
                              size: 14,
                              color: Colors.black,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Single row for documents and missing items
                      SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            // Uploaded documents
                            Expanded(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.uploadedDocuments.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 4),
                                itemBuilder: (context, index) {
                                  final doc = state.uploadedDocuments[index];
                                  return _buildMiniDocumentChip(
                                    context,
                                    doc,
                                    isComplete,
                                  );
                                },
                              ),
                            ),
                            // Missing documents indicator with label
                            if (!isComplete && missingTypes.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text(
                                'Missing:',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 9,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              ...missingTypes.map((type) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.error
                                              .withValues(alpha: 0.2),
                                          Theme.of(context).colorScheme.error
                                              .withValues(alpha: 0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error
                                            .withValues(alpha: 0.6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _getShortDocumentName(type),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 9,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Thin progress bar on the right
                if (!isComplete) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(flex: 4 - progress, child: Container()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMiniDocumentChip(
    BuildContext context,
    Document document,
    bool isComplete,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isComplete
            ? const Color(0xFF49B265).withValues(
                alpha: 0.15,
              ) // green for complete
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF49B265).withValues(alpha: 0.6) // green border
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getDocumentIcon(document.type),
            size: 10,
            color: isComplete
                ? const Color(0xFF49B265) // green icon
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              document.fileName.split('.').first,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 9,
                color: isComplete
                    ? Colors
                          .black // black text for complete
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () {
              context.read<ChatBloc>().add(RemoveDocumentEvent(document.id));
            },
            child: Icon(
              Icons.close,
              size: 10,
              color: isComplete
                  ? Colors.black.withValues(
                      alpha: 0.8,
                    ) // black close icon for complete
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.qualitativeBusiness:
        return Icons.receipt;
      case DocumentType.balanceSheet:
        return Icons.account_balance;
      case DocumentType.cashFlow:
        return Icons.money;
      case DocumentType.profitLoss:
        return Icons.analytics;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getShortDocumentName(DocumentType type) {
    switch (type) {
      case DocumentType.qualitativeBusiness:
        return 'Business';
      case DocumentType.balanceSheet:
        return 'Balance';
      case DocumentType.cashFlow:
        return 'Cash Flow';
      case DocumentType.profitLoss:
        return 'P&L';
      case DocumentType.earningsCall:
        return 'Earnings Call';
      case DocumentType.other:
        return 'Other';
    }
  }
}
