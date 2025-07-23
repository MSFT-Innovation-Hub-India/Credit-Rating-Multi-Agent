# =====================================
# Explainability Script: SHAP + Foundry Agent
# =====================================
# This script loads a RAG summary, extracts features, runs SHAP analysis on a trained pipeline,
# formats a business-friendly explanation, and passes it to an Azure AI Agent (Foundry) for interpretation.

import os
import re
import time
import shap
import joblib
import pandas as pd
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# =====================================
# STEP 1: Load Summary File
# =====================================

summary_path = os.path.join("output_data", "rag_summary.txt")

if not os.path.exists(summary_path):
    raise FileNotFoundError("Summary file not found.")

with open(summary_path, "r", encoding="utf-8") as f:
    raw_summary = f.read()

# =====================================
# STEP 2: Feature Extraction Utilities
# =====================================

def extract_value(field, text, default=None):
    pattern = rf"{field}\s*:\s*(.+)"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match: return default
    value_str = match.group(1).strip().replace(",", "")
    multiplier = 1e9 if 'B' in value_str.upper() else 1e6 if 'M' in value_str.upper() else 1
    number_match = re.search(r"[-+]?\d*\.?\d+", value_str)
    return float(number_match.group()) * multiplier if number_match else default

def extract_text(field, text, default="Unknown"):
    match = re.search(rf"{field}\s*:\s*(.+)", text, re.IGNORECASE)
    return match.group(1).strip() if match else default

def normalize_industry(val):
    return "Tech" if "tech" in val.lower() else "Finance" if "finance" in val.lower() else "Other"

def normalize_country(val):
    if "india" in val.lower(): return "India"
    if "us" in val.lower(): return "US"
    if "germany" in val.lower(): return "Germany"
    return "Other"

# =====================================
# STEP 3: Prepare Feature Input Row
# =====================================

row = {
    "Revenue": extract_value("Revenue", raw_summary),
    "Net_Income": extract_value("Net Income", raw_summary),
    "Total_Assets": extract_value("Total Assets", raw_summary),
    "Total_Liabilities": extract_value("Total Liabilities", raw_summary),
    "Equity": extract_value("Equity", raw_summary),
    "Industry_Sector": normalize_industry(extract_text("Industry", raw_summary)),
    "Country": normalize_country(extract_text("Country", raw_summary))
}
df = pd.DataFrame([row])

# =====================================
# STEP 4: Load Pipeline and Run SHAP
# =====================================

pipeline_path = os.path.join("agents", "explainability_agent", "final_pipeline.pkl")
pipeline = joblib.load(pipeline_path)

X_transformed = pipeline.named_steps['columntransformer'].transform(df)
feature_names = pipeline.named_steps['columntransformer'].get_feature_names_out()
model_only = pipeline.named_steps['randomforestclassifier']

explainer = shap.TreeExplainer(model_only)
shap_values = explainer.shap_values(X_transformed)
class_idx = 1  # Assuming '1' = higher credit risk

feature_shaps = shap_values[0, :, class_idx]
contributions = list(zip(feature_names, feature_shaps))
contributions.sort(key=lambda x: abs(x[1]), reverse=True)

top_features = "\n".join([f"{name}: {float(value):+.4f}" for name, value in contributions[:7]])
predicted_probabilities = model_only.predict_proba(X_transformed)[0]
predicted_risk = predicted_probabilities[class_idx]

# =====================================
# STEP 5: Prepare LLM Explanation Prompt
# =====================================

explanation = f"""
The following summary explains why a machine learning model predicted a certain level of credit default risk for a company.

It is based on various financial indicators and characteristics such as revenue, net income, total assets and liabilities, equity, industry type, and country of operation. Each of these factors influences the risk level in different ways — either increasing or reducing it.

Key drivers behind this prediction include:
{top_features}

Overall, the model has assessed a moderate level of risk based on these inputs. Please provide a clear and concise explanation of this prediction in business-friendly language, highlighting the most influential factors and their impact on the risk assessment.
"""

# =====================================
# STEP 6: Call Foundry Agent for Interpretation
# =====================================

project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
)
agent = project.agents.get_agent("asst_oDWcHiwhp6UWnWCUCHs892Bb")

# Create thread and send prompt
thread = project.agents.threads.create()
project.agents.messages.create(thread_id=thread.id, role="user", content="Explain why the default risk is predicted")
project.agents.messages.create(thread_id=thread.id, role="assistant", content=explanation)
project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)

# Poll for assistant response
max_wait = 10  # seconds
sleep_interval = 2
waited = 0
assistant_reply = None

while waited < max_wait:
    messages = list(project.agents.messages.list(thread_id=thread.id))
    assistant_reply = next((m for m in reversed(messages) if m.role == "assistant"), None)
    if assistant_reply:
        break
    time.sleep(sleep_interval)
    waited += sleep_interval

# =====================================
# STEP 7: Prettify and Display Output
# =====================================

def prettify_feature(name):
    name = name.replace("columntransformer__", "").replace("_", " ")
    name = re.sub(r"\b(\w)", lambda m: m.group(1).upper(), name)
    name = name.replace("Industry Sector", "Industry Sector (Encoded)")
    name = name.replace("Country", "Country (Encoded)")
    return name

print("\n=== 🧠 Credit Default Risk Explanation ===\n")

print("📊 Top 7 Feature Contributions:\n")
print(f"{'Feature':<40} {'Impact on Risk':>15}")
print("-" * 58)
for name, value in contributions[:7]:
    pretty_name = prettify_feature(name)
    print(f"{pretty_name:<40} {value:>+15.4f}")

print("\n🔢 Predicted Default Risk Score:")
print(f"    {predicted_risk:.4f} (Probability of default)\n")

# Foundry LLM Output
if assistant_reply:
    print("🧾 Foundry Agent Interpretation:\n")
    for item in assistant_reply.content:
        if item.get("type") == "text":
            print(item["text"]["value"])
else:
    print("⚠️  No response from Foundry agent.")
