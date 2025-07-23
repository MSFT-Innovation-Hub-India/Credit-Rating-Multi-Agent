# =====================================
# Fraud Detection Script with Azure AI Agent
# =====================================
# Loads a trained fraud detection model, extracts data from a RAG summary,
# performs prediction, and calls an Azure AI agent to summarize findings.

import os
import re
import pandas as pd
import joblib
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import ListSortOrder

# =====================================
# STEP 1: Load Model
# =====================================

model_path = os.path.join("agents", "fraud_detection", "fraud_model.joblib")
model = joblib.load(model_path)

# =====================================
# STEP 2: Load RAG Summary
# =====================================

rag_summary_path = os.path.join("output_data", "rag_summary.txt")
if not os.path.exists(rag_summary_path):
    raise FileNotFoundError("RAG summary not found. Run bureau agent first.")

with open(rag_summary_path, "r", encoding="utf-8") as f:
    text = f.read()

# =====================================
# STEP 3: Utility Functions for Extraction
# =====================================

def extract_amount(field, text):
    """
    Extracts numeric values in billions (e.g., ₹2.5 B) for financial fields.
    """
    pattern = rf"{field}:\s*\$?₹?([\d.,]+)\s*B"
    match = re.search(pattern, text, re.IGNORECASE)
    return float(match.group(1).replace(",", "")) * 1e9 if match else 0.0

def extract_string(field, text):
    """
    Extracts raw string value from 'Field: value' pattern.
    """
    pattern = rf"{field}:\s*(.+)"
    match = re.search(pattern, text)
    return match.group(1).strip() if match else "Unknown"

# =====================================
# STEP 4: Extract Features from Summary
# =====================================

revenue = extract_amount("Revenue", text)
net_income = extract_amount("Net Income", text)
total_assets = extract_amount("Total Assets", text)
liabilities = extract_amount("Total Liabilities", text)
equity = extract_amount("Equity", text)
country = extract_string("Country", text)
industry = extract_string("Industry", text)

# =====================================
# STEP 5: Create Model Input
# =====================================

input_df = pd.DataFrame([{
    "Revenue": revenue,
    "Net_Income": net_income,
    "Total_Assets": total_assets,
    "Total_Liabilities": liabilities,
    "Equity": equity,
    "Industry_Sector": industry,
    "Country": country
}])

# =====================================
# STEP 6: Run Prediction
# =====================================

prediction = model.predict(input_df)[0]
proba = model.predict_proba(input_df)[0]
result_text = (
    f" Fraud Detection Result\n"
    f"Prediction: {'Fraudulent' if prediction else 'Not Fraudulent'}\n"
    f"Confidence: {max(proba) * 100:.2f}%"
)

print("\n" + result_text)

# =====================================
# STEP 7: Call Foundry Agent for Summary
# =====================================

project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
)

agent_id = "asst_jma5gWHJMxPQt271vldw4mwg"
agent = project.agents.get_agent(agent_id)
thread = project.agents.threads.create()

# Send context and summary path as messages
project.agents.messages.create(
    thread_id=thread.id,
    role="user",
    content="Run fraud detection based on the extracted RAG summary."
)
project.agents.messages.create(
    thread_id=thread.id,
    role="assistant",
    content=rag_summary_path  # You may want to send content instead in production
)

# Execute agent logic
project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)

# =====================================
# STEP 8: Print Assistant Response
# =====================================

messages = project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)
for m in messages:
    if m.text_messages:
        print("\n🧾 Agent Response:\n" + m.text_messages[-1].text.value)
