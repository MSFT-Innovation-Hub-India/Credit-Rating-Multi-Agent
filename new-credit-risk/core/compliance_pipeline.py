# =====================================
# Compliance Agent Pipeline
# =====================================

import os                    # For reading the summary file
import json                  # For parsing JSON-formatted responses
from azure.identity import DefaultAzureCredential  # Azure authentication
from azure.ai.projects import AIProjectClient       # Main entry to interact with Azure AI project
from azure.ai.agents.models import ListSortOrder    # Sort messages when reading agent replies

# =====================================
# Azure AI Project Initialization
# =====================================

# Create client to interact with the Azure AI Agent Project
project = AIProjectClient(
    credential=DefaultAzureCredential(),  # Automatically handles Azure credentials
    endpoint="https://akshitasurya.services.ai.azure.com/api/projects/CreditRiskAssessor"  # Replace with your project URL
)

# =====================================
# Legal Compliance Checklist
# =====================================

# List of rules to check the document against — these guide the LLM's compliance evaluation
LEGAL_NORMS = [
    "Does the document comply with KYC norms?",
    "Are there any signs of money laundering or suspicious activities?",
    "Is the content aligned with GDPR or Indian IT Act regulations?",
    "Have all required regulatory disclosures been properly made?",
    "Is there verifiable consent obtained from clients or stakeholders?",
    "Are there risks of legal liability or omission of critical terms?",
    "Does it violate financial or operational transparency norms?"
]

# =====================================
# Compliance Agent Pipeline Logic
# =====================================

def compliance_agent_pipeline(summary_text: str) -> dict:
    """
    Evaluates a financial document summary for compliance issues using Azure AI Agent.

    Parameters:
    - summary_text (str): Text summary of the document to be checked

    Returns:
    - dict: Output containing detected compliance issues, risk level, and recommendations
    """

    # Get the specific Azure agent for legal compliance
    agent = project.agents.get_agent("asst_jma5gWHJMxPQt271vldw4mwg")

    # Construct the prompt for the assistant (LLM) to evaluate
    prompt = f"""
    You are a legal compliance checker agent. Given the following document summary, identify any violations or risks:

    Summary:
    {summary_text}

    Check the following:
    {chr(10).join(f"- {norm}" for norm in LEGAL_NORMS)}  # Insert checklist as bullet points

    Respond in JSON format with keys: "compliance_issues", "risk_level", and "recommendations".
    """

    try:
        # -------------------------------------
        # Initiate Agent Interaction
        # -------------------------------------
        thread = project.agents.threads.create()  # Create new message thread
        project.agents.messages.create(thread_id=thread.id, role="user", content=prompt)  # Send user message
        project.agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)    # Start and run the agent

        # -------------------------------------
        # Retrieve and Parse Agent Response
        # -------------------------------------
        messages = list(project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING))
        assistant_reply = next((m for m in reversed(messages) if m.role == "assistant"), None)

        # If no valid response found
        if not assistant_reply:
            return {"error": "No response from agent."}

        # Extract actual text from the agent's reply
        content = assistant_reply.text_messages[0].text.value if assistant_reply.text_messages else ""

        # Remove Markdown-style code block if wrapped in ```json
        if content.startswith("```json"):
            content = content.strip("```json").strip("`").strip()

        # Return parsed JSON output
        return json.loads(content)

    except Exception as e:
        # Fallback in case parsing fails or agent misbehaves
        return {
            "error": "Unable to parse agent response.",
            "raw_output": content if 'content' in locals() else "",
            "details": str(e)
        }

# =====================================
# Standalone Testing Entry Point
# =====================================

if __name__ == "__main__":
    # Read the document summary from local file
    summary_path = os.path.join("output_data", "rag_summary.txt")
    with open(summary_path, "r", encoding="utf-8") as f:
        raw_summary = f.read()

    # Run the compliance agent pipeline
    compliance_result = compliance_agent_pipeline(raw_summary)

    # Print results in pretty JSON format
    print(json.dumps(compliance_result, indent=2, ensure_ascii=False))
