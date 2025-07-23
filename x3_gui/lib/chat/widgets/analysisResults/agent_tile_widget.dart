import 'package:flutter/material.dart';
import 'package:x3_gui/models/agentanalysis_model.dart';

class AgentTileWidget extends StatelessWidget {
  final AnalysisResults analysisResult;
  final VoidCallback? onTap;
  final int tileIndex;
  final bool showApprovalButton;
  final VoidCallback? onApprovalTap;
  final String approvalButtonText;
  final bool isInactive;

  const AgentTileWidget({
    super.key,
    required this.analysisResult,
    required this.tileIndex,
    this.onTap,
    this.showApprovalButton = false,
    this.onApprovalTap,
    this.approvalButtonText = 'Approve & Continue',
    this.isInactive = false,
  });

  static const Color _primaryBlue = Color(0xFF6A89A7);
  static const Color _lightBlue = Color(0xFFBDDDFC);
  static const Color _midBlue = Color(0xFF88BDF2);
  static const Color _darkBlue = Color(0xFF384959);

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      Color(0xFF223A5E),
      Color(0xFF335C81),
    ]; // navy to muted blue
    final isComplete = analysisResult.status == AgentStatus.complete;
    final isRunning = analysisResult.status == AgentStatus.running;
    final isError = analysisResult.status == AgentStatus.error;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isInactive
                ? [
                    Color(0xFF335C81).withValues(alpha: 0.35),
                    Color(0xFF223A5E).withValues(alpha: 0.35),
                  ]
                : gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRunning
                ? Color(0xFF335C81).withValues(alpha: 0.5)
                : isComplete
                ? Color(0xFF88BDF2).withValues(alpha: 0.4)
                : isError
                ? Colors.red.withValues(alpha: 0.3)
                : Color(0xFF223A5E).withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF223A5E).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            if (isRunning)
              BoxShadow(
                color: Color(0xFF335C81).withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 0),
              ),
            if (isComplete)
              BoxShadow(
                color: Color(0xFF88BDF2).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isComplete && onTap != null) ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: _lightBlue.withValues(alpha: 0.15),
            highlightColor: _midBlue.withValues(alpha: 0.08),
            child: Column(
              children: [
                // Agent tile content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius:
                          (showApprovalButton &&
                              isComplete &&
                              onApprovalTap != null)
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            )
                          : BorderRadius.circular(16),
                      color: Color(0xFF335C81), // muted blue for contrast
                    ),
                    child: Row(
                      children: [
                        _buildEnhancedAgentIcon(context),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                analysisResult.agentName,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getStatusText(analysisResult.status),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Color(
                                        0xFFBDDDFC,
                                      ), // light blue for status
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildEnhancedStatusBadge(context),
                      ],
                    ),
                  ),
                ),
                // Approval button if needed
                if (showApprovalButton &&
                    isComplete &&
                    onApprovalTap != null) ...[
                  InkWell(
                    onTap: onApprovalTap,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ), // reduced padding
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF00FF57), // neon green
                            Color(0xFF88BDF2), // light blue
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF00FF57).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xFF00FF57).withValues(alpha: 0.7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            approvalButtonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Color(0xFF00FF57), blurRadius: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAgentIcon(BuildContext context) {
    final iconData = _getAgentIcon();
    final isRunning = analysisResult.status == AgentStatus.running;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _lightBlue.withValues(alpha: 0.7),
            _midBlue.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _midBlue.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        iconData,
        size: 20,
        color: isRunning ? _primaryBlue : _darkBlue,
      ),
    );
  }

  Widget _buildEnhancedStatusBadge(BuildContext context) {
    final iconData = _getStatusIcon();
    final isRunning = analysisResult.status == AgentStatus.running;

    // Logical neon color mapping for each status
    Color neonColor;
    switch (analysisResult.status) {
      case AgentStatus.pending:
        neonColor = const Color(0xFFFFA500); // orange
        break;
      case AgentStatus.running:
        neonColor = const Color(0xFFFFFF00); // yellow
        break;
      case AgentStatus.complete:
        neonColor = const Color(0xFF00FF57); // green
        break;
      case AgentStatus.error:
        neonColor = const Color(0xFFFF0057); // red
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: neonColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: neonColor, width: 1.5),
      ),
      child: isRunning
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(neonColor),
              ),
            )
          : Icon(iconData, size: 12, color: neonColor),
    );
  }

  IconData _getAgentIcon() {
    final agentName = analysisResult.agentName.toLowerCase();
    if (agentName.contains('bureau') || agentName.contains('summariser')) {
      return Icons.summarize_rounded;
    } else if (agentName.contains('credit') &&
        (agentName.contains('score') ||
            agentName.contains('rating') ||
            agentName.contains('risk'))) {
      return Icons.star_rate_rounded;
    } else if (agentName.contains('fraud')) {
      return Icons.security_rounded;
    } else if (agentName.contains('compliance')) {
      return Icons.gavel_rounded;
    } else if (agentName.contains('explainability')) {
      return Icons.lightbulb_rounded;
    } else {
      return Icons.analytics_rounded;
    }
  }

  IconData _getStatusIcon() {
    switch (analysisResult.status) {
      case AgentStatus.pending:
        return Icons.schedule_rounded;
      case AgentStatus.running:
        return Icons.sync_rounded;
      case AgentStatus.complete:
        return Icons.check_circle_rounded;
      case AgentStatus.error:
        return Icons.error_rounded;
    }
  }

  String _getStatusText(AgentStatus status) {
    switch (status) {
      case AgentStatus.pending:
        return 'Waiting...';
      case AgentStatus.running:
        return 'Analyzing...';
      case AgentStatus.complete:
        return 'Complete';
      case AgentStatus.error:
        return 'Error';
    }
  }
}
