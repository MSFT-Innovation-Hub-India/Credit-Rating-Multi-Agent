/* * 
When we send requests to our Azure AI Foundry agents to call on the AI Search Vectorized Context
The results will be returned to the app via JSON/HTTP response.

The results will be converted to an AnalysisResults object containing the required info
We can use this to chain the output of one agent to the input of another agent
Also helps with displaying the results in the UI

Chat will probably have a queue of AnalysisResults objects representing the results of each agent's analysis
Sequential agents

Once all agents have completed their analysis, we can traverse through the queue 
to display the results in the UI

 */

enum AgentStatus { pending, running, complete, error }

class AnalysisResults {
  final String agentName; // Name of the agent that performed the analysis
  final String agentDescription; //Brief description of what the agent does
  final Map<String, dynamic> extractedData; // Key-value pairs of extracted data
  final String summary; // Summary of the analysis results
  final DateTime? completedAt; // Timestamp when the analysis was completed
  final double?
  confidenceScore; // Confidence score of the analysis --> may be needed later for explainability/transparency
  final AgentStatus status; // Status of the agent analysis
  final String? errorMessage; // Error message if the analysis failed

  AnalysisResults({
    required this.agentName,
    required this.agentDescription,
    required this.extractedData,
    required this.summary,
    this.completedAt,
    this.confidenceScore,
    this.status = AgentStatus.pending,
    this.errorMessage,
  });

  /// Creates a copy with updated fields
  AnalysisResults copyWith({
    String? agentName,
    String? agentDescription,
    Map<String, dynamic>? extractedData,
    String? summary,
    DateTime? completedAt,
    double? confidenceScore,
    AgentStatus? status,
    String? errorMessage,
  }) {
    return AnalysisResults(
      agentName: agentName ?? this.agentName,
      agentDescription: agentDescription ?? this.agentDescription,
      extractedData: extractedData ?? this.extractedData,
      summary: summary ?? this.summary,
      completedAt: completedAt ?? this.completedAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Converts the AnalysisResults object to a JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'agentName': agentName,
      'agentDescription': agentDescription,
      'extractedData': extractedData,
      'summary': summary,
      'completedAt': completedAt?.toIso8601String(),
      'confidenceScore': confidenceScore,
      'status': status.toString(),
      'errorMessage': errorMessage,
    };
  }

  factory AnalysisResults.fromJson(Map<String, dynamic> json) {
    // Defensive: ensure extractedData is a Map<String, dynamic> with no nulls
    final extractedDataRaw = json['extractedData'] ?? {};
    final extractedData = <String, dynamic>{};
    extractedDataRaw.forEach((key, value) {
      extractedData[key] = value ?? '';
    });

    return AnalysisResults(
      agentName: json['agentName'] ?? '',
      agentDescription: json['agentDescription'] ?? '',
      extractedData: extractedData,
      summary: json['summary'] ?? '',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt']) // safer than DateTime.parse
          : null,
      confidenceScore: json['confidenceScore'] != null
          ? (json['confidenceScore'] as num?)?.toDouble()
          : null,
      status: AgentStatus.values.firstWhere(
        (e) => e.toString() == (json['status'] ?? 'AgentStatus.pending'),
        orElse: () => AgentStatus.pending,
      ),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}
