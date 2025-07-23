# Credit Risk Assessment Platform

## Overview

This project is a modular, production-grade backend platform for **automated credit risk analysis, fraud detection, compliance checking, and explainability** using Azure AI, LLM agents, and machine learning models. It is designed to process financial documents, extract structured summaries, orchestrate multiple AI/ML pipelines, and return actionable insights for credit and fraud risk assessment.

The system is built with **Python**, leverages **Flask** for API endpoints, and integrates deeply with **Azure Cognitive Services**, **Azure AI Studio**, and **Azure Cognitive Search**. It is highly extensible, with each analysis component (bureau summary, credit scoring, fraud detection, explainability, compliance) implemented as a separate pipeline and orchestrated via a smart controller.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Setup & Installation](#setup--installation)
- [Environment Variables](#environment-variables)
- [Azure Prerequisites](#azure-prerequisites)
- [Running the Application](#running-the-application)
- [API Endpoints](#api-endpoints)
- [Pipeline Details](#pipeline-details)
- [Data Flow](#data-flow)
- [Development & Testing](#development--testing)
- [Extending the Platform](#extending-the-platform)
- [Security & Best Practices](#security--best-practices)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- **Automated Document Ingestion**: Upload and process financial documents (PDF, DOCX, XLSX) via Azure Blob Storage.
- **Bureau Summarization**: Extracts structured business and financial summaries from raw documents.
- **Credit Scoring**: Assigns credit ratings (AAA–DDD), probability of default, and risk factors using LLM agents.
- **Fraud Detection**: Predicts fraud risk using a trained ML model and provides LLM-generated explanations.
- **Compliance Checking**: Checks summaries against legal and regulatory norms using Azure agents.
- **Explainability**: Uses SHAP and LLMs to explain model decisions in business-friendly language.
- **Smart Orchestration**: A controller agent dynamically decides which tools to run based on the summary.
- **Modular & Extensible**: Each pipeline is pluggable and can be invoked independently or as part of the smart pipeline.
- **Azure Native**: Deep integration with Azure AI Studio, Cognitive Search, Blob Storage, and secure authentication.

---

## Architecture

```
[User Upload/API]
      |
      v
[Azure Blob Storage] <---> [Document Ingestion]
      |
      v
[Bureau Summarizer Agent] --(summary)--> [Smart Controller Agent]
      |                                         |
      |                                         v
      |-------------------[Tool Selection]---->[Credit Scoring]
      |                                         [Fraud Detection]
      |                                         [Explainability]
      |                                         [Compliance]
      |                                         |
      |                                         v
      |-------------------[Results Aggregation]<-
      |
      v
[API Response / Dashboard / Azure Search Index]
```

---

## Folder Structure

```
Credit_risk/
│
├── app.py                      # Flask API entrypoint
├── requirements.txt            # Python dependencies
├── .env                        # Environment variables (not committed)
├── README.md                   # This file
│
├── agents/                     # Agent-specific code and models
│   ├── bureau_summarizer/
│   ├── credit_scoring/
│   ├── explainability_agent/
│   ├── fraud_detection/
│   └── meta_summarizer/
│
├── core/                       # Core pipelines and utilities
│   ├── agent_registry.py       # Central registry for all agent pipelines
│   ├── blob_utils.py           # Azure Blob Storage utilities
│   ├── bureau_pipeline.py      # Bureau summary pipeline
│   ├── compliance_pipeline.py  # Compliance checking pipeline
│   ├── credit_pipeline.py      # Credit scoring pipeline
│   ├── explainability_pipeline.py # Explainability pipeline
│   ├── fraud_pipeline.py       # Fraud detection pipeline
│   ├── smart_pipeline.py       # Smart controller pipeline
│   └── tools.py                # Wrappers for running each tool
│
├── data_ingestion/             # Data ingestion scripts/utilities
│
├── mcp/                        # Model compliance/validation utilities
│
├── output_data/                # Output summaries, intermediate files, and results
│
├── createindex.py              # Script to create Azure Cognitive Search index
├── delete.py                   # Script to delete Azure Cognitive Search index
├── normalized_financial_data (1).json # Example input data for indexing
└── ...
```

---

## Setup & Installation

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd Credit_risk
```

### 2. Create and Activate a Virtual Environment

```bash
python -m venv env
source env/bin/activate  # On Windows: env\Scripts\activate
```

### 3. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Copy `.env.example` to `.env` and fill in all required Azure credentials and configuration:

```env
AZURE_TENANT_ID=...
AZURE_CLIENT_ID=...
AZURE_CLIENT_SECRET=...
AZURE_SUBSCRIPTION_ID=...
AZURE_RESOURCE_GROUP=...
AZURE_PROJECT_NAME=...
# ...other keys as needed
```

---

## Environment Variables

- **All Azure credentials and sensitive configuration are loaded from `.env` using `python-dotenv`.**
- Never commit your `.env` file to version control.
- Required variables include Azure tenant ID, client ID, client secret, subscription ID, resource group, and project name.

---

## Azure Prerequisites

- **Azure Cognitive Search**: For document indexing and search.
- **Azure Blob Storage**: For document uploads and retrieval.
- **Azure AI Studio**: For LLM agents and orchestration.
- **Azure Service Principal**: For secure, automated authentication.
- **Azure AI Project**: With all required agents deployed (credit scoring, fraud detection, compliance, explainability, controller).

---

## Running the Application

### 1. Start the Flask API

```bash
python app.py
```

The API will be available at `http://localhost:5000/`.

### 2. Upload Documents

- Use the `/upload` endpoint (not shown here) or upload directly to Azure Blob Storage.
- Supported formats: PDF, DOCX, XLSX.

### 3. Run Pipelines

- Use the provided API endpoints to trigger each pipeline or the smart controller.

---

## API Endpoints

| Endpoint                   | Method | Description                                                      |
|----------------------------|--------|------------------------------------------------------------------|
| `/`                        | GET    | Health check                                                     |
| `/run-fraud`               | POST   | Run fraud detection pipeline                                     |
| `/run-compliance`          | POST   | Run compliance checking pipeline                                 |
| `/run-explainability`      | POST   | Run explainability pipeline                                      |
| `/run-smart-controller`    | POST   | Run the full smart pipeline (all relevant agents/tools)          |

- All endpoints return JSON responses.
- Each endpoint reads the latest summary from `output_data/rag_summary.txt` (can be customized).

---

## Pipeline Details

### Bureau Summarizer

- Reads the latest uploaded document from Azure Blob Storage.
- Extracts structured fields and key financial metrics.
- Outputs a summary JSON for downstream analysis.

### Credit Scoring

- Uses an Azure LLM agent to assign a credit rating, probability of default, and risk factors.
- Returns a structured JSON with all results.

### Fraud Detection

- Extracts features from the summary.
- Runs a trained ML model (RandomForest) to predict fraud risk.
- Uses an LLM agent to generate a business-friendly explanation.

### Compliance Checking

- Checks the summary against a list of legal and regulatory norms.
- Uses an Azure agent to return compliance issues, risk level, and recommendations.

### Explainability

- Uses SHAP to compute feature importance for the ML model's prediction.
- Sends SHAP results to an LLM agent for a business-friendly explanation.

### Smart Pipeline

- Orchestrates the full workflow.
- Uses a controller agent to decide which tools to run based on the summary.
- Aggregates all results into a single output.

---

## Data Flow

1. **Document Upload**: User uploads a document to Azure Blob Storage.
2. **Bureau Pipeline**: Reads and summarizes the document.
3. **Smart Controller**: Decides which analysis tools to run.
4. **Tool Pipelines**: Credit scoring, fraud detection, explainability, and compliance run as needed.
5. **Results Aggregation**: All results are combined and returned via the API.
6. **(Optional) Indexing**: Results can be indexed in Azure Cognitive Search for analytics and retrieval.

---

## Development & Testing

- **Run any pipeline directly** by importing and calling its function in a Python shell or script.
- **Test the API** using Postman, curl, or any HTTP client.
- **Debug output** is printed to the console for all CLI runs.
- **Unit tests** can be added for each pipeline and utility.

---

## Extending the Platform

- **Add new agents/tools** by creating a new pipeline in `core/` and registering it in `agent_registry.py`.
- **Add new endpoints** by defining new Flask routes in `app.py`.
- **Customize the smart pipeline** by updating the controller agent's logic or toolset.

---

## Security & Best Practices

- **Never commit secrets**: Keep `.env` and all credentials out of version control.
- **Use Azure-managed identities** and service principals for authentication.
- **Follow Azure code generation and deployment best practices** (see internal docs or use Azure tools).
- **Validate all inputs** using the provided schema validators in `mcp/validator.py`.
- **Monitor and log** all API and pipeline activity for audit and debugging.

---

## Troubleshooting

- **Azure Authentication Errors**: Check your `.env` and Azure portal for correct credentials.
- **Blob/File Not Found**: Ensure documents are uploaded to the correct Azure Blob container.
- **Agent/Model Errors**: Verify that all required agents are deployed and accessible in Azure AI Studio.
- **Indexing Issues**: Ensure your Azure Cognitive Search index schema matches your data.

---

## License

This project is for demonstration and educational purposes. For production use, ensure compliance with all Microsoft and Azure licensing terms.

---

## Credits

- Built by Microsoft and community contributors.
- Uses Azure AI, Cognitive Search, and open-source Python libraries.

---

**For more details, see the code comments in each file. Every pipeline and utility is fully documented for clarity and extensibility.**