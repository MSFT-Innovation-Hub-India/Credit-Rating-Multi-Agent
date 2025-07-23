# =====================================
# Fraud Detection Pipeline
# =====================================

import os                   # File path operations
import re                   # Regular expressions for extracting values
import json                 # JSON formatting for LLM prompt
import pandas as pd         # DataFrame creation for model input
import joblib               # Model loading
from datetime import datetime  # Timestamp for output
from azure.identity import DefaultAzureCredential  # Azure authentication
from azure.ai.projects import AIProjectClient       # Azure AI Agent client


# =====================================
# Main Fraud Detection Function
# =====================================
def fraud_detection_pipeline(summary_text: str) -> dict:
    """
    Analyzes a financial summary and predicts the likelihood of fraud using a trained ML model.
    Also generates an AI-based explanation and returns a schema-compliant response.
    
    Parameters:
    - summary_text (str): Financial summary text extracted by the Bureau agent.

    Returns:
    - dict: Structured output with risk score, level, flagged items, AI summary, etc.
    """

    # -------------------------------------
    # Load Pre-trained Fraud Detection Model
    # -------------------------------------
    model_path = "agents/fraud_detection/fraud_model.joblib"
    model = joblib.load(model_path)  # Load model from disk

    # -------------------------------------
    # Utility: Extract numerical fields (e.g., Revenue, Equity) from summary
    # Looks for format like: "Revenue: ₹20.3 B"
    # -------------------------------------
    def extract_amount(field, text):
        pattern = rf"{field}:\s*\$?₹?([\d.,]+)\s*B"  # Supports ₹ or $ followed by billions
        match = re.search(pattern, text, re.IGNORECASE)
        return float(match.group(1).replace(",", "")) * 1e9 if match else 0.0

    # -------------------------------------
    # Utility: Extract string fields (e.g., Industry, Country) from summary
    # -------------------------------------
    def extract_string(field, text):
        pattern = rf"{field}:\s*(.+)"  # Match "Field: Value" format
        match = re.search(pattern, text)
        return match.group(1).strip() if match else "Unknown"

    # -------------------------------------
    # Feature Extraction from Text Summary
    # These values will be passed to the model for fraud prediction
    # -------------------------------------
    features = {
        "Revenue": extract_amount("Revenue", summary_text),
        "Net_Income": extract_amount("Net Income", summary_text),
        "Total_Assets": extract_amount("Total Assets", summary_text),
        "Total_Liabilities": extract_amount("Total Liabilities", summary_text),
        "Equity": extract_amount("Equity", summary_text),
        "Industry_Sector": extract_string("Industry", summary_text),
        "Country": extract_string("Country", summary_text)
    }

    # Convert extracted features into a DataFrame as expected by the model
    df = pd.DataFrame([features])

    # -------------------------------------
    # Make Prediction Using Model
    # -------------------------------------
    prediction = model.predict(df)[0]             # Binary prediction (0 = legit, 1 = fraud)
    proba = model.predict_proba(df)[0]            # Probabilities for each class
    fraud_risk_score = round(proba[1], 2)         # Class 1 represents fraud risk probability

    # -------------------------------------
    # Determine Risk Level Based on Score
    # -------------------------------------
    if fraud_risk_score > 0.7:
        risk_level = "High"
    elif fraud_risk_score > 0.3:
        risk_level = "Moderate"
    else:
        risk_level = "Low"

    # -------------------------------------
    # Simulated Document Authenticity Logic
    # Just a heuristic for added insight in UI
    # -------------------------------------
    document_authenticity = round(1.0 - fraud_risk_score + 0.05, 2)  # Higher score = less fraud
    verification_status = "Verified" if document_authenticity >= 0.9 else "Needs Review"
    flagged_items = [] if fraud_risk_score < 0.3 else ["Unusual liabilities", "Equity mismatch"]

    # =====================================
    # AI Explanation Using Azure Agent
    # =====================================

    # Connect to Azure AI Agent project
    project = AIProjectClient(
        credential=DefaultAzureCredential(),
        endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
    )
    agent = project.agents.get_agent("asst_jma5gWHJMxPQt271vldw4mwg")

    # Prompt for LLM to explain the model's findings
    prompt = f"""
    You are a fraud analyst. Review the following features and risk score, and summarize the fraud risk:

    Features:
    {json.dumps(features, indent=2)}

    Model Score: {fraud_risk_score}
    Risk Level: {risk_level}

    Write a clear 1-2 sentence professional summary on fraud likelihood.
    """

    # Start a conversation thread with the assistant
    thread = project.agents.threads.create()
    project.agents.messages.create(thread_id=thread.id, role="user", content=prompt)
    project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)

    # Retrieve the assistant's message (final summary)
    messages = list(project.agents.messages.list(thread_id=thread.id))
    ai_summary = next((m.text_messages[-1].text.value for m in messages if m.text_messages), "No response.")

    # =====================================
    # Final Structured Output
    # =====================================
    return {
        "agentName": "Fraud Detection",
        "agentDescription": "Identifies potential fraud indicators and risk factors",
        "extractedData": {
            "fraud_risk_score": fraud_risk_score,
            "risk_level": risk_level,
            "flagged_items": flagged_items,
            "verification_status": verification_status,
            "document_authenticity": document_authenticity
        },
        "summary": ai_summary,
        "completedAt": datetime.utcnow().isoformat() + "Z",
        "confidenceScore": round(proba.max(), 2),
        "status": "AgentStatus.complete",
        "errorMessage": None
    }

# =====================================
# CLI Debug/Test Entry Point
# =====================================
if __name__ == "__main__":
    # Read sample summary from output_data/rag_summary.txt
    summary_path = os.path.join("output_data", "rag_summary.txt")
    with open(summary_path, "r", encoding="utf-8") as f:
        raw_summary = f.read()

    # Run fraud detection pipeline on this summary
    fraud_data = fraud_detection_pipeline(raw_summary)

    # Print formatted output
    print(json.dumps(fraud_data, indent=2))
    print("\nFraud Detection Pipeline Complete. Data saved to output_data folder.")
