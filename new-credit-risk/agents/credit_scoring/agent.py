# =====================================
# Credit Scoring Agent Runner
# =====================================
# This script sends a summary to an Azure AI agent, extracts credit scoring values,
# computes a credit rating, and saves the output to a text file.

import os
import re
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import ListSortOrder

# =====================================
# File Paths (Relative to project root)
# =====================================
rag_summary_path = os.path.join("output_data", "rag_summary.txt")
output_path = os.path.join("output_data", "credit_scoring_result.txt")

# =====================================
# Check if input file exists
# =====================================
if not os.path.exists(rag_summary_path):
    raise FileNotFoundError("RAG summary file not found. Run bureau_agent.py first.")

# Read input summary
with open(rag_summary_path, "r", encoding="utf-8") as f:
    summary_content = f.read()

# =====================================
# Azure AI Project Setup
# =====================================
project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
)

# Select the credit scoring assistant agent
agent = project.agents.get_agent("asst_OPFiIidA5lUgry5IBnze5eKd")

# =====================================
# Prompt Template
# =====================================
prompt = f"""
You are a credit scoring assistant. Based on the structured summary below, return:

- Probability of Default (PD Score) in % (e.g., 4.5%)
- Suggested Credit Limit (in INR crores)
- Risk Category (Low / Moderate / High)

Use only the data provided in the summary. Format strictly as:
PD Score: <value>%
Credit Limit: ₹<value> Cr
Risk Category: <category>

Summary:
{summary_content}
"""

# =====================================
# Send Prompt to Agent
# =====================================
thread = project.agents.threads.create()
project.agents.messages.create(thread_id=thread.id, role="user", content=prompt)
project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)

# =====================================
# Parse Agent Response
# =====================================
messages = project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)

scoring_result = ""
for m in messages:
    if m.text_messages:
        scoring_result = m.text_messages[-1].text.value

print("\n🔎 Credit Scoring Result (Raw):\n")
print(scoring_result)

# =====================================
# Compute Credit Rating from Extracted Values
# =====================================

def compute_credit_rating(pd_score: float, risk_category: str) -> str:
    """
    Maps PD score and risk category to a credit rating.
    """
    if pd_score <= 5.0 and risk_category == "Low":
        return "AAA"
    elif pd_score <= 10.0 and risk_category in ["Low", "Moderate"]:
        return "AA"
    elif pd_score <= 15.0:
        return "A"
    elif pd_score <= 25.0:
        return "BBB"
    elif pd_score <= 40.0:
        return "BB"
    elif pd_score <= 60.0:
        return "B"
    else:
        return "CCC"

# Extract values using regex
pd_match = re.search(r"PD Score:\s*([\d.]+)%", scoring_result)
risk_match = re.search(r"Risk Category:\s*(\w+)", scoring_result)

if pd_match and risk_match:
    pd_score = float(pd_match.group(1))
    risk_category = risk_match.group(1)
    credit_rating = compute_credit_rating(pd_score, risk_category)
    scoring_result += f"\nCredit Rating: {credit_rating}"
else:
    scoring_result += "\nCredit Rating: Not computable due to missing values."

# =====================================
# Save Final Output
# =====================================
print("\n✅ Final Credit Scoring Result (With Rating):\n")
print(scoring_result)

# Write to output file
with open(output_path, "w", encoding="utf-8") as f:
    f.write(scoring_result)

print(f"\n📁 Credit scoring result saved to: {output_path}")
