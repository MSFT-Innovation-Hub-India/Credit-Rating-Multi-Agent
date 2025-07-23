# === app.py ===
# This is the main entry point for the Credit Risk Assessment backend API.
# It uses Flask to expose HTTP endpoints for running various AI/ML pipelines,
# including bureau summarization, credit scoring, fraud detection, compliance checking,
# explainability, and a smart controller that orchestrates the entire workflow.
# Each endpoint reads the latest summary from disk and returns the result as JSON.
# All core pipelines are imported from the core/ directory.

from flask import Flask, request, jsonify  # Flask web framework for API endpoints
from core.bureau_pipeline import bureau_agent_pipeline  # Bureau summary pipeline
from core.credit_pipeline import credit_scoring_pipeline  # Credit scoring pipeline
from core.fraud_pipeline import fraud_detection_pipeline  # Fraud detection pipeline
from core.compliance_pipeline import compliance_agent_pipeline  # Compliance checking pipeline
from core.explainability_pipeline import explainability_agent_pipeline  # Explainability pipeline
from core.smart_pipeline import run_smart_pipeline  # Smart controller pipeline (orchestrates all tools)
import traceback  # For printing detailed error tracebacks in case of exceptions
from core.blob_utils import upload_file_to_blob  # Utility for uploading files to Azure Blob Storage
from mcp.validator import validate_input_against_schema, validate_output_against_schema  # Input/output schema validators
import json  # For JSON serialization/deserialization
import os  # For file path operations
from core.agent_registry import AGENT_PIPELINES  # Central registry for all agent pipelines
import asyncio  # For running asynchronous tasks
from my_SemanticKernel.my_sk_orchestrator import SemanticKernelOrchestrator

# === Flask App Initialization ===
# This creates the Flask application instance, which will handle all incoming HTTP requests.
app = Flask(__name__)


#Initialize SK orchestrator 
sk_orchestrator = SemanticKernelOrchestrator()

# === Health Check Endpoint ===
@app.route("/", methods=["GET"])
def index():
    """
    Health check endpoint.
    Returns a simple message to confirm the API is running.
    """
    return "API is up and running!"

# === Fraud Detection Endpoint ===
@app.route("/run-fraud", methods=["POST"])
def run_fraud():
    """
    Endpoint to run the fraud detection pipeline.
    Reads the summary text from the output_data folder, runs the fraud detection pipeline,
    and returns the result as JSON.
    """
    try:
        # Read the latest summary text from disk (output_data/rag_summary.txt)
        summary_text = open("output_data/rag_summary.txt", encoding="utf-8").read()
        # Run the fraud detection pipeline on the summary
        fraud_result = fraud_detection_pipeline(summary_text)
        # Return the result as a JSON response with HTTP 200 status
        return jsonify(fraud_result), 200
    except Exception as e:
        # If any error occurs, return the error message as JSON with HTTP 500 status
        return jsonify({"error": str(e)}), 500

# === Compliance Checking Endpoint ===
@app.route("/run-compliance", methods=["POST"])
def run_compliance():
    """
    Endpoint to run the compliance checking pipeline.
    Reads the summary text from the output_data folder, runs the compliance pipeline,
    and returns the result as JSON.
    """
    try:
        summary_text = open("output_data/rag_summary.txt", encoding="utf-8").read()
        compliance_result = compliance_agent_pipeline(summary_text)
        return jsonify(compliance_result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# === Explainability Endpoint ===
@app.route("/run-explainability", methods=["POST"])
def run_explainability():
    """
    Endpoint to run the explainability pipeline.
    Reads the summary text from the output_data folder, runs the explainability pipeline,
    and returns the result as JSON.
    """
    try:
        summary_text = open("output_data/rag_summary.txt", encoding="utf-8").read()
        explain_result = explainability_agent_pipeline(summary_text)
        return jsonify(explain_result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# === Smart Controller Endpoint ===
@app.route("/run-smart-controller", methods=["POST"])
def run_smart_controller():
    """
    Endpoint to run the smart pipeline controller.
    This orchestrates the entire credit risk workflow, running all relevant agents/tools,
    and returns the aggregated results as JSON.
    """
    try:
        final_result = run_smart_pipeline()
        return jsonify(final_result), 200
    except Exception as e:
        # Print the full traceback to the server logs for debugging
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500




## Semantic Kernel Endpoints
@app.route("/run-sk-smart-controller", methods=["POST"])
def run_sk_smart_controller():
    try:
        # Handle case where request.json is None
        requirements = []
        if request.json and "requirements" in request.json:
            requirements = request.json["requirements"]
        
        print(f"Processing requirements: {requirements}")
        
        #Run async orchestrator
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(sk_orchestrator.run_smart_analysis(requirements))
        loop.close()

        return jsonify(result), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route("/run-sk-credit-analysis", methods=["POST"])
def run_sk_credit_analysis():
    """Full credit analysis using SK orchestration."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            sk_orchestrator.run_credit_analysis()
        )
        loop.close()
        
        return jsonify({"analysis": result}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# === Main Entrypoint ===
# This block runs the Flask app when the script is executed directly.
# The app listens on all interfaces (0.0.0.0) at port 5000.
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)