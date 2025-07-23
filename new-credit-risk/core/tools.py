# =======================
# Importing Core Pipelines
# =======================

# Importing the main pipeline functions from each AI agent module
# Each of these represents a key function of the credit risk & fraud detection system

from core.credit_pipeline import credit_scoring_pipeline               # Generates credit risk score and limit recommendation
from core.fraud_pipeline import fraud_detection_pipeline               # Detects potentially fraudulent behavior
from core.explainability_pipeline import explainability_agent_pipeline # Explains AI decisions using techniques like SHAP
from core.compliance_pipeline import compliance_agent_pipeline         # Validates decision against compliance/regulatory rules

# =======================
# Tool Runner Functions
# =======================

# Each function below is a wrapper that takes a single input (summary_text)
# and runs it through the appropriate pipeline (tool/agent).
# The input is expected to be a pre-summarized credit or transaction profile.
# The output is always a dictionary (usually containing scores, flags, or explanations).

def run_credit_tool(summary_text: str) -> dict:
    """
    Runs the Credit Scoring Agent.

    Parameters:
    - summary_text (str): Summarized customer or credit profile text.

    Returns:
    - dict: Credit scoring results (e.g., PD score, recommended credit limit).
    """
    return credit_scoring_pipeline(summary_text)


def run_fraud_tool(summary_text: str) -> dict:
    """
    Runs the Fraud Detection Agent.

    Parameters:
    - summary_text (str): Summarized transaction or customer behavior text.

    Returns:
    - dict: Fraud analysis results, including anomaly flags or risk probabilities.
    """
    return fraud_detection_pipeline(summary_text)


def run_explainability_tool(summary_text: str) -> dict:
    """
    Runs the Explainability Agent.

    Parameters:
    - summary_text (str): The input on which a decision was made (for explanation).

    Returns:
    - dict: Explanation of the decision (e.g., feature contributions, SHAP values).
    """
    return explainability_agent_pipeline(summary_text)


def run_compliance_tool(summary_text: str) -> dict:
    """
    Runs the Compliance Agent.

    Parameters:
    - summary_text (str): Text summary of AI-generated decision or profile.

    Returns:
    - dict: Validation results against compliance rules or regulatory guidelines.
    """
    return compliance_agent_pipeline(summary_text)
