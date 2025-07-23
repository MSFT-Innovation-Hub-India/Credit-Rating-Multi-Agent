# =====================================
# Agent Registry Mapping
# =====================================
# This module acts as a central registry of all agent pipelines.
# It allows dynamic lookup and invocation of agents via a single dictionary.
# Useful for modular orchestration, dynamic routing, and clean API integration.

# =====================================
# Imports: Core Agent Pipelines
# =====================================

from core.bureau_pipeline import bureau_agent_pipeline               # Bureau summarization agent
from core.credit_pipeline import credit_scoring_pipeline             # Credit scoring/risk agent
from core.fraud_pipeline import fraud_detection_pipeline             # Fraud detection agent
from core.compliance_pipeline import compliance_agent_pipeline       # Compliance validation agent
from core.explainability_pipeline import explainability_agent_pipeline  # SHAP/LLM explanation agent

# =====================================
# Agent Registry Dictionary
# =====================================

# Maps string keys to their respective pipeline functions.
# Enables dynamic access and execution based on agent name.
# Can be used like: `AGENT_PIPELINES["fraud"](summary_text)`

AGENT_PIPELINES = {
    "bureau": bureau_agent_pipeline,
    "credit": credit_scoring_pipeline,
    "fraud": fraud_detection_pipeline,
    "compliance": compliance_agent_pipeline,
    "explainability": explainability_agent_pipeline,
}
# =====================================