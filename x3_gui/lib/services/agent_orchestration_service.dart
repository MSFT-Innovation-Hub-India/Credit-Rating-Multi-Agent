import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x3_gui/models/agentanalysis_model.dart';
import 'package:x3_gui/models/document_model.dart';
import 'package:x3_gui/services/azure_config.dart';

class AgentOrchestrationService {
  // Base URL for API endpoints - replace with actual URLs in production
  final String _baseUrl = AzureConfig.agentBaseUrl;

  // Add a toggle for using mock data
  bool _useMockData = false; // Set to true for testing, false for production

  final StreamController<List<AnalysisResults>> _analysisStreamController =
      StreamController<List<AnalysisResults>>.broadcast();

  Stream<List<AnalysisResults>> get analysisStream =>
      _analysisStreamController.stream;

  // Single API call to get all agent results
  Future<List<AnalysisResults>> runFullAnalysis(
    List<Document> documents,
  ) async {
    try {
      // Set all agents to running status to show loading indicators
      final List<AnalysisResults> initialAgents = _initializeAgents();
      _broadcastUpdate(initialAgents);

      // Use mock data if flag is set
      if (_useMockData) {
        final results = await _runMockAnalysis(documents);
        _broadcastUpdate(results);
        return results;
      }

      // Original API code remains unchanged
      final response = await http.post(
        Uri.parse('$_baseUrl/run-sk-smart-controller'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trigger': 'full_analysis',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API returned status code ${response.statusCode}');
      }

      // Parse the response into a list of AnalysisResults
      final jsonResponse = jsonDecode(response.body);
      print('API response: $jsonResponse');
      final List<AnalysisResults> results = [];

      // Parse bureau summarizer (guaranteed)
      if (jsonResponse['bureau_summary'] != null) {
        final bureauSummaryResult = AnalysisResults.fromJson(
          jsonResponse['bureau_summary'],
        );
        results.add(bureauSummaryResult);
        print('Bureau Summary Results:\n');
        print('=========================\n');
        print('Agent Name: ${bureauSummaryResult.agentName}');
        print('Description: ${bureauSummaryResult.agentDescription}');
        print('Extracted Data: ${bureauSummaryResult.extractedData}');
        print('Summary: ${bureauSummaryResult.summary}');
        print('Status: ${bureauSummaryResult.status}');
        print('Confidence Score: ${bureauSummaryResult.confidenceScore}');
        print('Completed At: ${bureauSummaryResult.completedAt}');
      } else {
        throw Exception('Bureau Summariser results missing from API response');
      }

      // Parse credit scoring (guaranteed)
      if (jsonResponse['credit_scoring'] != null) {
        final creditScoringResult = AnalysisResults.fromJson(
          jsonResponse['credit_scoring'],
        );
        results.add(creditScoringResult);
        print('Credit Scoring results:\n');
        print('=======================\n');
        print('Agent Name: ${creditScoringResult.agentName}');
        print('Description: ${creditScoringResult.agentDescription}');
        print('Extracted Data: ${creditScoringResult.extractedData}');
        print('Summary: ${creditScoringResult.summary}');
        print('Status: ${creditScoringResult.status}');
        print('Confidence Score: ${creditScoringResult.confidenceScore}');
        print('Completed At: ${creditScoringResult.completedAt}');
      } else {
        throw Exception('Credit Scoring results missing from API response');
      }

      // Parse fraud detection (may be null)
      if (jsonResponse['fraud_detection'] != null) {
        results.add(AnalysisResults.fromJson(jsonResponse['fraud_detection']));
      } else {
        // Add a placeholder for inactive fraud detection agent
        results.add(
          AnalysisResults(
            agentName: 'Fraud Detection',
            agentDescription:
                'Identifies potential fraud indicators and risk factors',
            extractedData: {},
            summary: '', // Empty summary indicates inactive
            status: AgentStatus.complete, // Still mark as complete
            completedAt: DateTime.now(),
          ),
        );
      }

      // Parse compliance (may be null or in a different format)
      if (jsonResponse['compliance_check'] != null) {
        final complianceData = jsonResponse['compliance_check'];

        // Check if it's already in the expected format or needs conversion
        if (complianceData is Map && complianceData.containsKey('agentName')) {
          // Convert to Map<String, dynamic> before passing to fromJson
          final typedComplianceData = <String, dynamic>{};
          complianceData.forEach((key, value) {
            typedComplianceData[key.toString()] = value;
          });
          results.add(AnalysisResults.fromJson(typedComplianceData));
        } else {
          // Rest of the code remains the same...
          final extractedDataMap = <String, dynamic>{};
          if (complianceData is Map) {
            complianceData.forEach((key, value) {
              extractedDataMap[key.toString()] = value;
            });
          }

          // Create the compliance result with properly typed map
          results.add(
            AnalysisResults(
              agentName: 'Compliance',
              agentDescription:
                  'Evaluates regulatory compliance and legal risks',
              extractedData: extractedDataMap,
              summary:
                  complianceData is Map &&
                      complianceData.containsKey('recommendations')
                  ? complianceData['recommendations'].toString()
                  : '',
              status: AgentStatus.complete,
              completedAt: DateTime.now(),
            ),
          );

          print('Compliance Check Results:\n');
          print('=========================\n');
          print('Agent Name: ${results.last.agentName}');
          print('Description: ${results.last.agentDescription}');
          print('Extracted Data: ${results.last.extractedData}');
          print('Summary: ${results.last.summary}');
        }
      } else {
        // Add a placeholder for inactive compliance agent
        results.add(
          AnalysisResults(
            agentName: 'Compliance',
            agentDescription: 'Evaluates regulatory compliance and legal risks',
            extractedData: <String, dynamic>{},
            summary: '', // Empty summary indicates inactive
            status: AgentStatus.complete, // Still mark as complete
            completedAt: DateTime.now(),
          ),
        );
      }

      // Parse explainability (guaranteed)
      if (jsonResponse['explainability'] != null) {
        results.add(AnalysisResults.fromJson(jsonResponse['explainability']));
      } else {
        throw Exception('Explainability results missing from API response');
      }

      print('Parsed results: $results');
      // Extract the credit score
      final creditScore = _extractCreditScore(results);

      return results;
    } catch (e) {
      print('Error during analysis: $e');
      rethrow;
    }
  }

  // Get explanation for why an agent was not relevant
  Future<AnalysisResults> getAgentExplanation(String agentName) async {
    try {
      // Use mock data if flag is set
      if (_useMockData) {
        return await _getMockAgentExplanation(agentName);
      }

      // Original API code
      final response = await http.post(
        Uri.parse('$_baseUrl/explain-agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'agent_name': agentName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API returned status code ${response.statusCode}');
      }

      // Parse the response into an AnalysisResults object
      final jsonResponse = jsonDecode(response.body);
      return AnalysisResults.fromJson(jsonResponse);
    } catch (e) {
      print('Error getting agent explanation: $e');
      rethrow;
    }
  }

  // Add these specific methods for fraud and compliance explanations
  Future<AnalysisResults> getFraudDetectionExplanation() async {
    try {
      // Use mock data if flag is set
      if (_useMockData) {
        return await _getMockAgentExplanation('Fraud Detection');
      }

      // Use fraud-specific endpoint
      final response = await http.post(
        Uri.parse('$_baseUrl/run-fraud'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'timestamp': DateTime.now().toIso8601String()}),
      );

      if (response.statusCode != 200) {
        throw Exception('API returned status code ${response.statusCode}');
      }

      // Parse the response into an AnalysisResults object
      final jsonResponse = jsonDecode(response.body);
      return AnalysisResults.fromJson(jsonResponse);
    } catch (e) {
      print('Error getting fraud explanation: $e');
      rethrow;
    }
  }

  Future<AnalysisResults> getComplianceExplanation() async {
    try {
      // Use mock data if flag is set
      if (_useMockData) {
        return await _getMockAgentExplanation('Compliance');
      }

      // Use compliance-specific endpoint
      final response = await http.post(
        Uri.parse('$_baseUrl/run-compliance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'timestamp': DateTime.now().toIso8601String()}),
      );

      if (response.statusCode != 200) {
        throw Exception('API returned status code ${response.statusCode}');
      }

      // Parse the response into an AnalysisResults object
      final jsonResponse = jsonDecode(response.body);
      return AnalysisResults.fromJson(jsonResponse);
    } catch (e) {
      print('Error getting compliance explanation: $e');
      rethrow;
    }
  }

  // NEW: Add toggle for mock mode
  void setUseMockData(bool useMock) {
    _useMockData = useMock;
  }

  // NEW: Mock analysis method
  Future<List<AnalysisResults>> _runMockAnalysis(
    List<Document> documents,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final List<AnalysisResults> results = [];

    // Bureau Summariser (always included)
    results.add(
      AnalysisResults(
        agentName: 'Bureau Summariser',
        agentDescription:
            'Analyzes and summarizes business documents and financial statements',
        extractedData: {
          'annual_revenue': 1.81,
          'company_name': 'TerraDrive Mobility Corp.',
          'employees': null,
          'industry': 'Mobility / Transportation',
          'key_financial_metrics': {
            'debt_to_equity': 4.17,
            'profit_margin': null,
            'revenue_growth': -13,
          },
          'years_in_business': null,
        },
        summary:
            'TerraDrive Mobility Corp. is a struggling mobility services company currently operating at a loss and experiencing declining revenues. With a 13% year-over-year revenue drop and no clear profitability, the firm relies heavily on debt financing, reflected in its high estimated debt-to-equity ratio of 4.17. Despite ongoing restructuring efforts and significant capital investments, free cash flow remains negative, and adjusted EBITDA is deeply in the red. Liquidity concerns persist, and the company is dependent on refinancing and asset-backed securities to maintain operations. Its financial instability and negative margins suggest heightened credit risk in the near term.',
        status: AgentStatus.complete,
        completedAt: DateTime.parse('2025-07-11T09:18:23.155598Z'),
        confidenceScore: 0.92,
      ),
    );

    // Credit Score Rating (always included)
    results.add(
      AnalysisResults(
        agentName: 'Credit Score Rating',
        agentDescription: 'Calculates credit risk and assigns AAA–DDD rating',
        extractedData: {
          'credit_score': 'DDD',
          'financial_strength_score': 0.2,
          'market_position_score': 0.4,
          'probability_of_default': 0.35,
          'risk_factors': [
            'Operating at a loss',
            'Declining revenues',
            'High debt-to-equity ratio',
            'Negative free cash flow',
            'Negative adjusted EBITDA',
            'Liquidity concerns',
          ],
        },
        summary:
            'The credit rating for TerraDrive Mobility Corp. is DDD (High Risk) with a Probability of Default (PD) score of 35%. The company is experiencing financial instability, negative margins, and liquidity concerns, indicating heightened credit risk.',
        status: AgentStatus.complete,
        completedAt: DateTime.parse('2025-07-14T05:05:33.401407Z'),
        confidenceScore: 0.89,
      ),
    );

    // Fraud Detection (now included with actual content)
    results.add(
      AnalysisResults(
        agentName: 'Fraud Detection',
        agentDescription:
            'Identifies potential fraud indicators and risk factors',
        extractedData: {
          'document_authenticity': 0.13,
          'flagged_items': ['Unusual liabilities', 'Equity mismatch'],
          'fraud_risk_score': 0.92,
          'risk_level': 'High',
          'verification_status': 'Needs Review',
        },
        summary:
            'Fraud Risk Assessment: High Fraud Risk\nJustification: The financial summary indicates zero values for revenue, net income, total assets, total liabilities, and equity, which is highly unusual and suggests potential manipulation or concealment of financial information, leading to a high fraud risk score of 0.92.',
        status: AgentStatus.complete,
        completedAt: DateTime.parse('2025-07-14T05:05:53.336622Z'),
        confidenceScore: 0.92,
      ),
    );

    // Compliance (now included with actual content)
    results.add(
      AnalysisResults(
        agentName: 'Compliance',
        agentDescription: 'Evaluates regulatory compliance and legal risks',
        extractedData: {
          'compliance_issues': 'High Fraud Risk',
          'risk_level': 'High Fraud Risk',
        },
        summary:
            'TerraDrive Mobility Corp. exhibits clear signs of financial distress and potential fraudulent activities. The declining revenues, negative free cash flow, and deeply negative EBITDA indicate severe financial instability. The high debt-to-equity ratio of 4.17 raises concerns about the company\'s ability to meet its financial obligations. The reliance on debt financing, ongoing restructuring efforts, and liquidity concerns further amplify the risk of financial fraud. It is recommended to conduct a thorough investigation into the company\'s financial statements, operations, and management practices to uncover any potential fraudulent activities.',
        status: AgentStatus.complete,
        completedAt: DateTime.now(),
        confidenceScore: 0.88,
      ),
    );

    // Explainability (always included)
    results.add(
      AnalysisResults(
        agentName: 'Explainability',
        agentDescription:
            'Provides detailed explanation of analysis decisions and factors',
        extractedData: {
          'confidence_reasoning':
              '\nThe following summary explains why a machine learning model predicted a certain level of credit default risk for a company.\n\nIt is based on various financial indicators and characteristics such as revenue, net income, total assets and liabilities, equity, industry type, and country of operation. Each of these factors influences the risk level in different ways — either increasing or reducing it.\n\nKey drivers behind this prediction include:\nnum_Revenue: -0.0598\nnumTotal_Assets: -0.0474\nnumNet_Income: -0.0431\nnumEquity: -0.0403\nnumTotal_Liabilities: +0.0267\ncatCountry_US: -0.0232\ncat_Industry_Sector_Manufacturing: -0.0184\n\nOverall, the model has assessed a moderate level of risk based on these inputs. Please provide a clear and concise explanation of this prediction in business-friendly language, highlighting the most influential factors and their impact on the risk assessment.\n',
          'decision_factors': [
            'Num  Revenue',
            'Num  Total Assets',
            'Num  Net Income',
          ],
          'weight_distribution': {
            'business_stability': 0.0474,
            'financial_performance': 0.0598,
            'market_position': 0.0431,
          },
        },
        summary:
            '\nThe following summary explains why a machine learning model predicted a certain level of credit default risk for a company.\n\nIt is based on various financial indicators and characteristics such as revenue, net income, total assets and liabilities, equity, industry type, and country of operation. Ea...',
        status: AgentStatus.complete,
        completedAt: DateTime.parse('2025-07-14T05:05:43.707127Z'),
        confidenceScore: 0.88,
      ),
    );

    return results;
  }

  // NEW: Mock explanation method
  Future<AnalysisResults> _getMockAgentExplanation(String agentName) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (agentName == 'Fraud Detection') {
      return AnalysisResults(
        agentName: 'Fraud Detection',
        agentDescription:
            'Identifies potential fraud indicators and risk factors',
        extractedData: {
          'excluded_reason': 'low_risk_profile',
          'risk_threshold': '0.30',
          'current_risk_score': '0.12',
        },
        summary:
            'Fraud detection analysis was not performed because the company\'s risk profile score of 0.12 is below the threshold of 0.30 required for in-depth fraud analysis. The initial assessment based on document consistency, business history, and transaction patterns indicated minimal fraud risk.',
        status: AgentStatus.complete,
        completedAt: DateTime.now(),
        confidenceScore: 0.95,
      );
    } else if (agentName == 'Compliance') {
      return AnalysisResults(
        agentName: 'Compliance',
        agentDescription: 'Evaluates regulatory compliance and legal risks',
        extractedData: {
          'excluded_reason': 'company_size',
          'regulatory_category': 'small_enterprise',
          'threshold': '£5M annual revenue',
        },
        summary:
            'Compliance analysis was not performed because the company falls under the small enterprise category with annual revenue below £5M. Standard compliance checks were deemed sufficient without the need for enhanced regulatory scrutiny that applies to larger organizations.',
        status: AgentStatus.complete,
        completedAt: DateTime.now(),
        confidenceScore: 0.90,
      );
    } else {
      return AnalysisResults(
        agentName: agentName,
        agentDescription: 'Agent not found or not applicable',
        extractedData: {},
        summary: 'No explanation available for this agent.',
        status: AgentStatus.error,
        errorMessage: 'Agent explanation not available',
      );
    }
  }

  // Initialize all agents with pending status
  List<AnalysisResults> _initializeAgents() {
    return [
      AnalysisResults(
        agentName: 'Bureau Summariser',
        agentDescription:
            'Analyzes and summarizes business documents and financial statements',
        extractedData: {},
        summary: '',
        status: AgentStatus.running,
      ),
      AnalysisResults(
        agentName: 'Credit Score Rating',
        agentDescription: 'Calculates credit risk and assigns AAA-DDD rating',
        extractedData: {},
        summary: '',
        status: AgentStatus.running,
      ),
      AnalysisResults(
        agentName: 'Fraud Detection',
        agentDescription:
            'Identifies potential fraud indicators and risk factors',
        extractedData: {},
        summary: '',
        status: AgentStatus.running,
      ),
      AnalysisResults(
        agentName: 'Compliance',
        agentDescription: 'Evaluates regulatory compliance and legal risks',
        extractedData: {},
        summary: '',
        status: AgentStatus.running,
      ),
      AnalysisResults(
        agentName: 'Explainability',
        agentDescription:
            'Provides detailed explanation of analysis decisions and factors',
        extractedData: {},
        summary: '',
        status: AgentStatus.running,
      ),
    ];
  }

  // Helper to extract credit score from results
  String _extractCreditScore(List<AnalysisResults> results) {
    final creditAgent = results.firstWhere(
      (result) => result.agentName == 'Credit Score Rating',
      orElse: () => AnalysisResults(
        agentName: '',
        agentDescription: '',
        extractedData: {'credit_score': 'N/A'},
        summary: '',
      ),
    );

    return creditAgent.extractedData['credit_score']?.toString() ?? 'N/A';
  }

  void _broadcastUpdate(List<AnalysisResults> results) {
    _analysisStreamController.add(List.from(results));
  }

  void dispose() {
    _analysisStreamController.close();
  }
}
