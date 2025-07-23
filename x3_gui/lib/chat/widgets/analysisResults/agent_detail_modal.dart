import 'package:flutter/material.dart';
import 'package:x3_gui/models/agentanalysis_model.dart';

class AgentDetailModal extends StatelessWidget {
  final AnalysisResults analysisResult;

  const AgentDetailModal({super.key, required this.analysisResult});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final Color bgDark = const Color(0xFF223A5E);
        final Color bgDarker = const Color(0xFF18223A);
        final Color accentBlue = const Color(0xFF88BDF2);
        final Color accentLight = const Color(0xFFBDDDFC);
        final Color accentRed = Colors.red[600]!;
        final Color textLight = Colors.white;
        final Color textMuted = Colors.white70;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgDarker, bgDark],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: bgDark.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: accentLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        analysisResult.agentName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textLight,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: accentLight),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agent description
                      _buildSection(
                        context,
                        'Agent Role',
                        analysisResult.agentDescription,
                        titleColor: accentLight,
                        contentColor: textMuted,
                      ),
                      const SizedBox(height: 24),
                      // Summary
                      _buildSection(
                        context,
                        'Analysis Summary',
                        analysisResult.summary,
                        titleColor: accentLight,
                        contentColor: textLight,
                      ),
                      const SizedBox(height: 24),
                      // Confidence score
                      if (analysisResult.confidenceScore != null)
                        _buildConfidenceScore(
                          context,
                          accentBlue,
                          accentRed,
                          textLight,
                        ),
                      const SizedBox(height: 24),
                      // Extracted data
                      _buildExtractedData(
                        context,
                        accentLight,
                        textLight,
                        textMuted,
                      ),
                      const SizedBox(height: 24),
                      // Completion info
                      if (analysisResult.completedAt != null)
                        _buildCompletionInfo(context, accentLight, textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content, {
    Color? titleColor,
    Color? contentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: titleColor ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: contentColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceScore(
    BuildContext context,
    Color accentBlue,
    Color accentRed,
    Color textLight,
  ) {
    final score = analysisResult.confidenceScore!;
    final percentage = (score * 100).toInt();
    final Color barColor = _getConfidenceColor(score, accentBlue, accentRed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confidence Score',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtractedData(
    BuildContext context,
    Color titleColor,
    Color valueColor,
    Color keyColor,
  ) {
    if (analysisResult.extractedData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Data Points',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        ...analysisResult.extractedData.entries.map(
          (entry) => _buildDataPoint(
            context,
            entry.key,
            entry.value,
            valueColor,
            keyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDataPoint(
    BuildContext context,
    String key,
    dynamic value,
    Color valueColor,
    Color keyColor,
  ) {
    String displayValue;
    if (value is List) {
      displayValue = value.join(', ');
    } else if (value is Map) {
      displayValue = value.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
    } else {
      displayValue = value.toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              _formatKey(key),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: keyColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              displayValue,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionInfo(
    BuildContext context,
    Color titleColor,
    Color valueColor,
  ) {
    final completedAt = analysisResult.completedAt!;
    final formattedTime =
        '${completedAt.hour.toString().padLeft(2, '0')}:${completedAt.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Completed at $formattedTime',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: valueColor),
        ),
      ],
    );
  }

  //MARK: helpers
  Color _getConfidenceColor(double score, Color accentBlue, Color accentRed) {
    if (score >= 0.8) return accentBlue;
    if (score >= 0.6) return Colors.orangeAccent;
    return accentRed;
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
