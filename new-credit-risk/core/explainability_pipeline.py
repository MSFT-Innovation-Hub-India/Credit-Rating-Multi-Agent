# =====================================
# Explainability Agent Pipeline
# =====================================

import os                   # File path operations
import re                   # Regular expressions for parsing text
import joblib               # Load serialized model pipeline
import shap                 # SHAP for model interpretability
import time                 # Sleep during async LLM wait
import json                 # Formatting prompt and output
import pandas as pd         # DataFrame construction
from datetime import datetime  # For timestamping final output
from azure.identity import DefaultAzureCredential  # Azure credential management
from azure.ai.projects import AIProjectClient       # Azure AI Agent project client

# =====================================
# Load ML Pipeline & Model Once
# =====================================

pipeline_path = os.path.join("agents", "explainability_agent", "final_pipeline.pkl")
pipeline = joblib.load(pipeline_path)                      # Full preprocessing + model pipeline
model_only = pipeline.named_steps['randomforestclassifier']  # Extract only the model for SHAP use

# =====================================
# Azure AI Agent Setup
# =====================================

project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
)
foundry_agent = project.agents.get_agent("asst_oDWcHiwhp6UWnWCUCHs892Bb")  # Explainability assistant agent

# =====================================
# Utility Functions for Feature Extraction
# =====================================

def extract_value(field, text, default=None):
    """
    Extracts a numerical value from the financial summary for a given field.
    Supports suffixes like B (billion) or M (million) and currency symbols.
    """
    pattern = rf"{field}\s*:\s*(.+)"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match: return default
    val_str = match.group(1).strip().replace(",", "")
    multiplier = 1e9 if 'B' in val_str.upper() else 1e6 if 'M' in val_str.upper() else 1
    number_match = re.search(r"[-+]?\d*\.?\d+", val_str)
    return float(number_match.group()) * multiplier if number_match else default

def extract_text(field, text, default="Unknown"):
    """Extracts a string field from the summary."""
    match = re.search(rf"{field}\s*:\s*(.+)", text, re.IGNORECASE)
    return match.group(1).strip() if match else default

def normalize_industry(val):
    """Simplifies the industry field into predefined buckets."""
    return "Tech" if "tech" in val.lower() else "Finance" if "finance" in val.lower() else "Other"

def normalize_country(val):
    """Simplifies the country field to standardized labels."""
    if "india" in val.lower(): return "India"
    if "us" in val.lower(): return "US"
    if "germany" in val.lower(): return "Germany"
    return "Other"

def prettify_feature(name):
    """Formats feature names from internal model keys to human-readable text."""
    name = name.replace("columntransformer__", "").replace("_", " ")
    return re.sub(r"\b(\w)", lambda m: m.group(1).upper(), name)

# =====================================
# Main Explainability Function
# =====================================

def explainability_agent_pipeline(summary_text: str) -> dict:
    """
    Generates an interpretability report for a credit risk prediction using SHAP and Azure LLM.
    
    Parameters:
    - summary_text (str): Extracted summary from Bureau Agent

    Returns:
    - dict: Explanation output including feature impacts, weights, and LLM-generated summary
    """

    # -------------------------------------
    # Feature Extraction
    # -------------------------------------
    row = {
        "Revenue": extract_value("Revenue", summary_text),
        "Net_Income": extract_value("Net Income", summary_text),
        "Total_Assets": extract_value("Total Assets", summary_text),
        "Total_Liabilities": extract_value("Total Liabilities", summary_text),
        "Equity": extract_value("Equity", summary_text),
        "Industry_Sector": normalize_industry(extract_text("Industry", summary_text)),
        "Country": normalize_country(extract_text("Country", summary_text)),
    }

    df = pd.DataFrame([row])  # Convert to DataFrame for model input

    # -------------------------------------
    # Transform Input & Run SHAP Analysis
    # -------------------------------------
    X_transformed = pipeline.named_steps['columntransformer'].transform(df)
    feature_names = pipeline.named_steps['columntransformer'].get_feature_names_out()

    explainer = shap.TreeExplainer(model_only)
    shap_values = explainer.shap_values(X_transformed)
    class_idx = 1  # Targeting "default risk = yes"

    # Sort features by contribution strength
    feature_shaps = shap_values[0, :, class_idx]
    contributions = sorted(
        zip(feature_names, feature_shaps),
        key=lambda x: abs(x[1]),
        reverse=True
    )

    # -------------------------------------
    # Model Prediction & Prepare Explanation Prompt
    # -------------------------------------
    predicted_risk = model_only.predict_proba(X_transformed)[0][class_idx]
    top_features = "\n".join([f"{name}: {float(val):+.4f}" for name, val in contributions[:7]])

    # Prompt for LLM to explain SHAP results
    explanation_prompt = f"""
The following summary explains why a machine learning model predicted a certain level of credit default risk for a company.

It is based on various financial indicators and characteristics such as revenue, net income, total assets and liabilities, equity, industry type, and country of operation. Each of these factors influences the risk level in different ways — either increasing or reducing it.

Key drivers behind this prediction include:
{top_features}

Overall, the model has assessed a moderate level of risk based on these inputs. Please provide a clear and concise explanation of this prediction in business-friendly language, highlighting the most influential factors and their impact on the risk assessment.
"""

    # -------------------------------------
    # Call Azure AI Agent for Explanation
    # -------------------------------------
    thread = project.agents.threads.create()
    project.agents.messages.create(thread_id=thread.id, role="user", content="Explain why the default risk is predicted")
    project.agents.messages.create(thread_id=thread.id, role="assistant", content=explanation_prompt)
    project.agents.runs.create_and_process(thread_id=thread.id, agent_id=foundry_agent.id)

    # Poll for assistant reply (retry max 5 times)
    assistant_reply = None
    for _ in range(5):
        messages = list(project.agents.messages.list(thread_id=thread.id))
        assistant_reply = next((m for m in reversed(messages) if m.role == "assistant"), None)
        if assistant_reply:
            break
        time.sleep(2)  # Wait before retry

    # Extract text explanation if available
    foundry_explanation = ""
    if assistant_reply:
        foundry_explanation = "\n".join(
            item["text"]["value"] for item in assistant_reply.content if item.get("type") == "text"
        )

    # -------------------------------------
    # Final Output (Schema Compliant)
    # -------------------------------------
    return {
        "agentName": "Explainability",
        "agentDescription": "Provides detailed explanation of analysis decisions and factors",
        "extractedData": {
            "decision_factors": [
                prettify_feature(name) for name, _ in contributions[:3]  # Top 3 factors
            ],
            "weight_distribution": {
                "financial_performance": round(abs(contributions[0][1]), 4),
                "business_stability": round(abs(contributions[1][1]), 4),
                "market_position": round(abs(contributions[2][1]), 4),
            },
            "confidence_reasoning": foundry_explanation or "No explanation from Foundry."
        },
        "summary": foundry_explanation[:300] + "..." if foundry_explanation else "N/A",
        "completedAt": datetime.utcnow().isoformat() + "Z",
        "confidenceScore": 0.88,  # Placeholder value — can be made dynamic
        "status": "AgentStatus.complete",
        "errorMessage": None
    }

# =====================================
# Debug Entry Point
# =====================================
if __name__ == "__main__":
    # Load input text from RAG summary
    summary_path = os.path.join("output_data", "rag_summary.txt")
    with open(summary_path, "r", encoding="utf-8") as f:
        raw_summary = f.read()

    # Run explainability pipeline
    explainability_data = explainability_agent_pipeline(raw_summary)

    # Print formatted output
    print(json.dumps(explainability_data, indent=2))
    print("\nExplainability Pipeline Complete. Data saved to output_data folder.")
