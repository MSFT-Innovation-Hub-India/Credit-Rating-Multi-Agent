# ===========================
# Import Required Libraries
# ===========================

import json  # Used to parse JSON from assistant tool responses

# Azure authentication and SDKs
from azure.identity import DefaultAzureCredential  # Automatically handles Azure login credentials
from azure.ai.projects import AIProjectClient      # Client to interact with Azure AI Agent projects
from azure.ai.agents.models import ListSortOrder   # Used to sort conversation messages (chronologically)

# Custom AI agent pipelines from your core architecture
from core.bureau_pipeline import bureau_agent_pipeline  # Summarizes borrower credit history from blob + AI
from core.tools import (
    run_credit_tool,            # Credit scoring model
    run_fraud_tool,             # Fraud detection logic
    run_explainability_tool,    # Explains model decisions (e.g., SHAP)
    run_compliance_tool         # Validates decisions against compliance rules
)

# ===========================
# Output Template (default response structure)
# ===========================

# This dictionary defines the expected structure of the response
# Each component represents an AI agent's result (initially set to None)
output_template = {
    "bureau_summary": None,       # Output from Bureau Summarizer Agent
    "credit_scoring": None,       # Output from Credit Scoring Agent
    "fraud_detection": None,      # Output from Fraud Detection Agent (optional)
    "explainability": None,       # Output from Explainability Agent
    "compliance_check": None      # Output from Compliance Agent (optional)
}

# ===========================
# Azure AI Project Setup
# ===========================

# Authenticate with Azure using the default credentials available on the machine/environment
# (e.g., developer login, service principal, or managed identity)
project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"  # Your project endpoint
)

# Retrieve the controller agent (e.g., central planner that decides tool flow)
agent = project.agents.get_agent("asst_yv7fmqGQwS0xSBs4uE7D6zIO")

# ===========================
# Main Smart Pipeline Function
# ===========================

def run_smart_pipeline():
    """
    This function coordinates the execution of multiple AI agents to analyze financial data.
    
    Steps:
    1. Call Bureau Agent to get a summarized financial profile.
    2. Send the summary to a controller agent to decide which tools to run.
    3. Run selected tools (credit, fraud, explainability, compliance).
    4. Return a structured result containing all outputs.
    """

    # Create a fresh copy of the result template
    result = output_template.copy()

    # ---------------------------------------------------------
    # STEP 1: Run Bureau Agent (handles data loading + summary)
    # ---------------------------------------------------------
    bureau_output = bureau_agent_pipeline()  # Handles data fetch and summarization via Azure Blob + AI

    # Validate that bureau agent completed successfully
    if bureau_output.get("status") != "AgentStatus.complete":
        raise RuntimeError(f"Bureau agent failed: {bureau_output.get('errorMessage')}")

    # Extract the generated financial summary
    summary = bureau_output.get("summary", "").strip()
    if not summary:
        # Use fallback if summary is blank
        summary = "No detailed financial summary available."

    # Store bureau result in output
    result["bureau_summary"] = bureau_output

    # ---------------------------------------------------------
    # STEP 2: Use Controller Agent to Select Tools Dynamically
    # ---------------------------------------------------------

    # Create a new conversation thread for this pipeline run
    thread = project.agents.threads.create()

    # Provide input messages to the controller agent (summary + context)
    project.agents.messages.create(
        thread_id=thread.id,
        role="user",
        content="Analyze this financial summary and suggest which tools to use:"
    )
    project.agents.messages.create(
        thread_id=thread.id,
        role="user",
        content=summary  # Send the actual financial summary
    )

    # List of all tools the controller can choose from
    toolset_description = [
        "credit scoring",
        "fraud detection",
        "explainability",
        "compliance"
    ]

    # Controller agent instructions — must respond with JSON array of tool names
    instructions = f"""
You are an AI controller agent. Your job is to read the financial summary and decide which tools to invoke from the toolset below:

Toolset: {toolset_description}

Respond ONLY with a JSON list of tool names to run. Use exact names like:
- "credit scoring"
- "fraud detection"
- "explainability"
- "compliance"

Do NOT include explanations, markdown, or text outside the JSON list.
Only respond with: ["credit scoring", "fraud detection"] or similar.
"""

    # Trigger the agent to process the request using the provided instructions
    project.agents.runs.create_and_process(
        thread_id=thread.id,
        agent_id=agent.id,
        instructions=instructions
    )

    # ---------------------------------------------------------
    # STEP 3: Parse Controller Agent Response (tool selection)
    # ---------------------------------------------------------

    # Retrieve all messages in the thread (ordered chronologically)
    messages = list(project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING))

    # Extract the assistant's final message (tool recommendation in JSON format)
    tools_response = next((m.text_messages[-1].text.value for m in messages if m.role == "assistant"), "[]")

    try:
        # Safely parse the JSON string to a Python list
        tools_to_run = json.loads(tools_response)
    except Exception:
        # Handle malformed responses from the agent
        raise ValueError(f"Agent returned invalid JSON: {tools_response}")

    # ---------------------------------------------------------
    # STEP 4: Run AI Tools (based on controller recommendation)
    # ---------------------------------------------------------

    # Always run credit scoring and explainability
    result["credit_scoring"] = run_credit_tool(summary)
    result["explainability"] = run_explainability_tool(summary)

    # Run optional agents based on the toolset recommendation
    if "fraud detection" in tools_to_run:
        result["fraud_detection"] = run_fraud_tool(summary)

    if "compliance" in tools_to_run:
        result["compliance_check"] = run_compliance_tool(summary)

    # Return the structured dictionary containing all outputs
    return result
