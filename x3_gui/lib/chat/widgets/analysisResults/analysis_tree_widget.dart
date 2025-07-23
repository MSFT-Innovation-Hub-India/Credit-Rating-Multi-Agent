import 'package:flutter/material.dart';
import 'package:x3_gui/models/agentanalysis_model.dart';
import 'package:x3_gui/chat/widgets/analysisResults/agent_tile_widget.dart';
import 'package:x3_gui/chat/widgets/analysisResults/agent_detail_modal.dart';

class AnalysisTreeWidget extends StatefulWidget {
  final List<AnalysisResults> analysisResults;
  final String consolidatedCreditScore;
  final bool isRunning;
  final bool showApprovalButton; // Add this parameter
  final VoidCallback? onApprovalTap; // Add this parameter
  final VoidCallback? onBureauApprove;
  final VoidCallback? onMiddleLayerApprove;
  final Function(String)? onRequestAgentExplanation;

  const AnalysisTreeWidget({
    super.key,
    required this.analysisResults,
    required this.consolidatedCreditScore,
    this.isRunning = false,
    this.showApprovalButton = false, // Default to false
    this.onApprovalTap, // Optional callback
    this.onBureauApprove,
    this.onMiddleLayerApprove,
    this.onRequestAgentExplanation,
  });

  @override
  State<AnalysisTreeWidget> createState() => _AnalysisTreeWidgetState();
}

class _AnalysisTreeWidgetState extends State<AnalysisTreeWidget>
    with TickerProviderStateMixin {
  late AnimationController _connectionAnimationController;
  late Animation<double> _connectionAnimation;

  // Track which layers are visible
  bool _showMiddleLayer = false;
  bool _showBottomLayer = false;

  @override
  void initState() {
    super.initState();
    _connectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _connectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _connectionAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(AnalysisTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start animation when layers become visible
    if (!oldWidget.isRunning && widget.isRunning) {
      _connectionAnimationController.repeat();
    } else if (!widget.isRunning) {
      _connectionAnimationController.stop();
    }
  }

  @override
  void dispose() {
    _connectionAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF223A5E), Color(0xFF335C81)], // navy to muted blue
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF223A5E).withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF223A5E).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Credit score badge
              _buildCreditScoreBadge(context),
              const SizedBox(height: 32),

              // Tree structure
              _buildAgentTree(context),

              if (widget.isRunning) ...[
                const SizedBox(height: 24),
                _buildProgressIndicator(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentTree(BuildContext context) {
    // Get bureau agent (top layer)
    final bureauAgent = widget.analysisResults.firstWhere(
      (agent) => agent.agentName == 'Bureau Summariser',
      orElse: () => AnalysisResults(
        agentName: 'Bureau Summariser',
        agentDescription: '',
        extractedData: {},
        summary: '',
        status: AgentStatus.pending,
      ),
    );

    // Get middle layer agents (credit, fraud, compliance)
    final middleLayerAgents = widget.analysisResults
        .where(
          (agent) =>
              agent.agentName == 'Credit Score Rating' ||
              agent.agentName == 'Fraud Detection' ||
              agent.agentName == 'Compliance',
        )
        .toList();

    // Get explainability agent (bottom layer)
    final explainabilityAgent = widget.analysisResults.firstWhere(
      (agent) => agent.agentName == 'Explainability',
      orElse: () => AnalysisResults(
        agentName: 'Explainability',
        agentDescription: '',
        extractedData: {},
        summary: '',
        status: AgentStatus.pending,
      ),
    );

    return Column(
      children: [
        // Top layer: Bureau Summariser
        _buildBureauTile(context, bureauAgent),

        // Connection line to middle layer
        if (bureauAgent.status == AgentStatus.complete) ...[
          const SizedBox(height: 24),
          _buildConnectionLines(context),
          const SizedBox(height: 24),

          // Middle layer: Credit Score + Fraud + Compliance
          _buildMiddleLayerGrid(context, middleLayerAgents),

          // Connection line to bottom layer
          if (_showBottomLayer) ...[
            const SizedBox(height: 24),
            _buildConnectionLines(context),
            const SizedBox(height: 24),

            // Bottom layer: Explainability
            _buildExplainabilityTile(context, explainabilityAgent),
          ],
        ],
      ],
    );
  }

  Widget _buildBureauTile(BuildContext context, AnalysisResults bureauAgent) {
    final isComplete = bureauAgent.status == AgentStatus.complete;

    return Column(
      children: [
        // Bureau agent tile
        SizedBox(
          width: 300,
          height: 120,
          child: AgentTileWidget(
            analysisResult: bureauAgent,
            tileIndex: 0,
            onTap: isComplete
                ? () => _showAgentDetails(context, bureauAgent)
                : null,
            showApprovalButton: isComplete && !_showMiddleLayer,
            onApprovalTap: () {
              setState(() {
                _showMiddleLayer = true;
              });
              if (widget.onBureauApprove != null) {
                widget.onBureauApprove!();
              }
            },
            approvalButtonText: 'Approve & Continue',
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleLayerGrid(
    BuildContext context,
    List<AnalysisResults> middleLayerAgents,
  ) {
    if (!_showMiddleLayer) return const SizedBox.shrink();

    // Improved sorting to ensure Credit Score is in the middle
    if (middleLayerAgents.length == 3) {
      // For 3 agents, place Credit Score in the middle (index 1)
      middleLayerAgents.sort((a, b) {
        // Credit Score should be in the middle
        if (a.agentName == 'Credit Score Rating') {
          if (b.agentName == 'Fraud Detection') return 1; // After Fraud
          return -1; // Before Compliance
        }
        if (b.agentName == 'Credit Score Rating') {
          if (a.agentName == 'Fraud Detection')
            return -1; // Fraud before Credit
          return 1; // Compliance after Credit
        }
        // Fraud before Compliance
        if (a.agentName == 'Fraud Detection') return -1;
        if (b.agentName == 'Fraud Detection') return 1;
        return 0;
      });
    } else if (middleLayerAgents.length > 3) {
      // For more than 3 agents, still keep Credit in the middle
      final creditIndex = middleLayerAgents.indexWhere(
        (agent) => agent.agentName == 'Credit Score Rating',
      );

      if (creditIndex >= 0) {
        final creditAgent = middleLayerAgents.removeAt(creditIndex);
        final middleIndex = middleLayerAgents.length ~/ 2;
        middleLayerAgents.insert(middleIndex, creditAgent);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final int maxColumns = 3;
        final int columns = middleLayerAgents.length > maxColumns
            ? maxColumns
            : middleLayerAgents.length;
        final double tileWidth =
            (availableWidth - (columns - 1) * 16) / columns;

        final List<Widget> tiles = [];

        for (int i = 0; i < middleLayerAgents.length; i++) {
          final agent = middleLayerAgents[i];
          final bool isCredit = agent.agentName == 'Credit Score Rating';
          final bool isInactive = agent.summary.isEmpty; // Null agent

          tiles.add(
            SizedBox(
              width: tileWidth.clamp(200, 300),
              height: 120,
              child: isInactive
                  ? _buildInactiveAgentTile(context, agent)
                  : AgentTileWidget(
                      analysisResult: agent,
                      tileIndex: i + 1,
                      onTap: () => _showAgentDetails(context, agent),
                      showApprovalButton: isCredit && !_showBottomLayer,
                      onApprovalTap: isCredit
                          ? () {
                              setState(() {
                                _showBottomLayer = true;
                              });
                              if (widget.onMiddleLayerApprove != null) {
                                widget.onMiddleLayerApprove!();
                              }
                            }
                          : null,
                      approvalButtonText: 'Proceed to Explanation',
                    ),
            ),
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: tiles,
        );
      },
    );
  }

  Widget _buildInactiveAgentTile(BuildContext context, AnalysisResults agent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBDDDFC).withValues(alpha: 0.3),
            Color(0xFF88BDF2).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF6A89A7).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: null, // Not clickable by default
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.agentName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Color(0xFF384959),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onRequestAgentExplanation != null) {
                      widget.onRequestAgentExplanation!(agent.agentName);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6A89A7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Why wasn't this relevant?"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplainabilityTile(
    BuildContext context,
    AnalysisResults explainabilityAgent,
  ) {
    if (!_showBottomLayer) return const SizedBox.shrink();

    return SizedBox(
      width: 300,
      height: 120,
      child: AgentTileWidget(
        analysisResult: explainabilityAgent,
        tileIndex: 4,
        onTap: explainabilityAgent.status == AgentStatus.complete
            ? () => _showAgentDetails(context, explainabilityAgent)
            : null,
      ),
    );
  }

  Widget _buildConnectionLines(BuildContext context) {
    return AnimatedBuilder(
      animation: _connectionAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 40),
          painter: TreeConnectionPainter(
            animationValue: _connectionAnimation.value,
            isAnimating: widget.isRunning,
          ),
        );
      },
    );
  }

  Widget _buildCreditScoreBadge(BuildContext context) {
    final color = _getCreditScoreColor(widget.consolidatedCreditScore);
    final isComplete = widget.consolidatedCreditScore != 'Analyzing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isComplete) ...[
            Icon(Icons.verified, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            widget.consolidatedCreditScore,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final completedCount = widget.analysisResults
        .where((result) => result.status == AgentStatus.complete)
        .length;
    final totalCount = widget.analysisResults.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF223A5E).withValues(alpha: 0.18),
                ),
              ),
              CircularProgressIndicator(
                value: progress.toDouble(),
                strokeWidth: 6,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF88BDF2)),
              ),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Analyzing... ($completedCount/$totalCount agents completed)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getCreditScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'AAA':
      case 'AA':
      case 'A':
        return const Color(0xFF4CAF50);
      case 'BBB':
      case 'BB':
      case 'B':
        return const Color(0xFFFF9800);
      case 'CCC':
      case 'CC':
      case 'C':
      case 'DDD':
      case 'DD':
      case 'D':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF20B2AA);
    }
  }

  void _showAgentDetails(BuildContext context, AnalysisResults result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SizedBox(
          height: screenHeight * 0.8, // Take up 80% of screen height
          child: AgentDetailModal(analysisResult: result),
        );
      },
    );
  }
}

// Custom painter for animated connection lines
class TreeConnectionPainter extends CustomPainter {
  final double animationValue;
  final bool isAnimating;

  TreeConnectionPainter({
    required this.animationValue,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isAnimating) return;

    final paint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Main vertical line
    final startY = 0.0;
    final endY = size.height;
    final centerX = size.width / 2;

    // Draw glow effect
    canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), glowPaint);

    // Draw main line
    canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), paint);

    // Traveling pulse effect
    final pulsePosition = (animationValue * size.height) % size.height;
    final pulsePaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..strokeWidth = 6
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, pulsePosition), 4, pulsePaint);

    // Branching lines to parallel agents (simplified)
    final branchY = endY * 0.8;
    final branchWidth = size.width * 0.6;

    canvas.drawLine(
      Offset(centerX - branchWidth / 2, branchY),
      Offset(centerX + branchWidth / 2, branchY),
      paint,
    );
  }

  @override
  bool shouldRepaint(TreeConnectionPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isAnimating != isAnimating;
  }
}
