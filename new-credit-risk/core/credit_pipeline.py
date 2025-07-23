# =====================================
# Credit Scoring Agent Pipeline
# =====================================

import os                    # For file path handling (not used here, but common in pipelines)
import re                    # For string and pattern parsing
import json                  # To parse agent response as JSON
from datetime import datetime  # To timestamp pipeline output
from azure.identity import DefaultAzureCredential  # Azure credential setup
from azure.ai.projects import AIProjectClient       # Azure AI Project client for managing agents
from azure.ai.agents.models import ListSortOrder    # Sorts agent message threads

# =====================================
# Safe Float Utility
# =====================================

def safe_float(value, default=0.0):
    """
    Converts a value to float safely. Returns a default value (0.0) on failure.

    Parameters:
    - value: Any input expected to be convertible to float
    - default: Value returned if conversion fails

    Returns:
    - float: Parsed float value or fallback
    """
    try:
        return float(value)
    except (ValueError, TypeError):
        return default

# =====================================
# Main Credit Scoring Function
# =====================================

def credit_scoring_pipeline(summary: str) -> dict:
    """
    Calls an Azure AI agent to evaluate creditworthiness based on a financial summary.

    Parameters:
    - summary (str): Structured summary text from Bureau Agent

    Returns:
    - dict: Structured result including credit score, PD, risk factors, confidence, and status
    """

    # -------------------------------------
    # Azure Project & Agent Setup
    # -------------------------------------
    project = AIProjectClient(
        credential=DefaultAzureCredential(),
        endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"
    )
    agent = project.agents.get_agent("asst_OPFiIidA5lUgry5IBnze5eKd")  # Credit scoring agent

    # -------------------------------------
    # Prompt to AI Agent
    # -------------------------------------
    prompt = f"""
    You are a credit scoring assistant. Based on the structured summary below, return:

    - Credit Score (AAA to DDD)
    - Probability of Default (PD Score) as a decimal (e.g., 0.04)
    - Risk Factors (bullet points or comma-separated list)
    - Financial Strength Score (0–1)
    - Market Position Score (0–1)
    - Summary for the rating

    Format strictly as JSON with keys:
    credit_score, probability_of_default, risk_factors, financial_strength_score, market_position_score, summary

    Summary:
    {summary}
    """

    # -------------------------------------
    # Agent Interaction: Create Thread & Send Prompt
    # -------------------------------------
    thread = project.agents.threads.create()
    project.agents.messages.create(thread_id=thread.id, role="user", content=prompt)
    project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)

    # Retrieve messages from the agent (sorted oldest to newest)
    messages = project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)

    # Parse the agent's final message (the LLM response)
    output = ""
    for msg in messages:
        if msg.role == "assistant" and msg.text_messages:
            output = msg.text_messages[-1].text.value
            break

    # -------------------------------------
    # Clean Output: Remove Markdown Formatting if Present
    # -------------------------------------
    if output.startswith("```json"):
        output = output.strip("```json").strip("`").strip()

    # -------------------------------------
    # Parse Agent Output into JSON
    # -------------------------------------
    try:
        # Try parsing directly as valid JSON
        data = json.loads(output)
    except json.JSONDecodeError:
        # If not valid JSON, fallback to manual parsing
        data = {}
        for line in output.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                k = key.strip().lower().replace(" ", "_")  # Normalize keys to match expected format
                v = val.strip()

                # Handle lists (risk_factors)
                if k == "risk_factors":
                    data[k] = [r.strip() for r in re.split(r",|-", v)]
                # Handle floats
                elif re.match(r"^\d+(\.\d+)?$", v):
                    data[k] = float(v)
                else:
                    data[k] = v

    # -------------------------------------
    # Return Final Structured Response
    # -------------------------------------
    return {
        "agentName": "Credit Score Rating",
        "agentDescription": "Calculates credit risk and assigns AAA–DDD rating",
        "extractedData": {
            "credit_score": data.get("credit_score", "Unknown"),
            "probability_of_default": safe_float(data.get("probability_of_default")),
            "risk_factors": data.get("risk_factors", []),
            "financial_strength_score": safe_float(data.get("financial_strength_score")),
            "market_position_score": safe_float(data.get("market_position_score"))
        },
        "summary": data.get("summary", ""),  # Human-readable explanation
        "completedAt": datetime.utcnow().isoformat() + "Z",  # UTC timestamp
        "confidenceScore": 0.89,  # Static score (could be dynamic based on LLM quality)
        "status": "AgentStatus.complete",
        "errorMessage": None
    }
