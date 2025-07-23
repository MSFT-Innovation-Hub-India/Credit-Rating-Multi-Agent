# === createindex.py ===
# This script creates an Azure Cognitive Search index and uploads financial data documents to it.
# It is intended for initializing your search environment and populating it with structured company data.
# Use this script to enable fast, faceted, and full-text search over your financial datasets.

import json  # For loading data from JSON files
from azure.core.credentials import AzureKeyCredential  # For authenticating with Azure services
from azure.search.documents.indexes import SearchIndexClient  # For managing search indexes (create, update, delete)
from azure.search.documents.indexes.models import (
    SearchIndex, SimpleField, SearchFieldDataType  # For defining the schema of the search index
)
from azure.search.documents import SearchClient  # For uploading/searching documents in the index
import os
from dotenv import load_dotenv
import uuid  # For generating unique IDs for each document


load_dotenv()

# --- Azure Cognitive Search Configuration ---
endpoint = os.getenv("AI-SEARCH-ENDPOINT")  # The endpoint URL for your Azure Search service
key = os.getenv("AI-SEARCH-API-KEY")  # Admin API key for authentication (keep this secure!)
index_name = os.getenv("AI-SEARCH-INDEX-NAME")  # The name of the index to create/use

# --- Define the Search Index Schema ---
# Each field describes a property of the documents you want to search.
# You can control which fields are searchable, filterable, sortable, facetable, etc.
fields = [
    # Unique document ID (required, must be key=True)
    SimpleField(name="id", type=SearchFieldDataType.String, key=True, filterable=True, retrievable=True, sortable=False, facetable=False, searchable=False),
    # Company name (searchable and sortable)
    SimpleField(name="company_name", type=SearchFieldDataType.String, key=False, filterable=True, retrievable=True, sortable=True, facetable=False, searchable=True),
    # CIK (company identifier, not searchable)
    SimpleField(name="cik", type=SearchFieldDataType.String, key=False, filterable=True, retrievable=True, sortable=True, facetable=False, searchable=False),
    # Fiscal year (for filtering and sorting)
    SimpleField(name="fiscal_year", type=SearchFieldDataType.String, key=False, filterable=True, retrievable=True, sortable=True, facetable=False, searchable=False),
    # Financial metrics (all filterable, sortable, facetable, but not searchable)
    SimpleField(name="revenue", type=SearchFieldDataType.Double, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    SimpleField(name="assets", type=SearchFieldDataType.Double, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    SimpleField(name="liabilities", type=SearchFieldDataType.Double, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    SimpleField(name="equity", type=SearchFieldDataType.Double, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    SimpleField(name="net_income", type=SearchFieldDataType.Double, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    # Country and industry (for filtering, faceting, and sorting)
    SimpleField(name="country", type=SearchFieldDataType.String, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    SimpleField(name="industry", type=SearchFieldDataType.String, key=False, filterable=True, retrievable=True, sortable=True, facetable=True, searchable=False),
    # Report URL (retrievable only, not searchable)
    SimpleField(name="report_url", type=SearchFieldDataType.String, key=False, filterable=False, retrievable=True, sortable=False, facetable=False, searchable=False),
    # Main content field (searchable, stores the full text or summary for search)
    SimpleField(name="content", type=SearchFieldDataType.String, key=False, filterable=False, retrievable=True, sortable=False, facetable=False, searchable=True),
]

# --- Create the Search Index ---
# This block creates the index in Azure Cognitive Search if it does not already exist.
index = SearchIndex(name=index_name, fields=fields)
index_client = SearchIndexClient(endpoint=endpoint, credential=AzureKeyCredential(key))
try:
    # Attempt to create the index. If it already exists, an exception will be raised.
    index_client.create_index(index)
    print(f"Index '{index_name}' created successfully.")
except Exception as e:
    # If the index already exists or another error occurs, print the error message.
    print(f"Index may already exist or error occurred: {e}")

# --- Load Data to be Indexed ---
# Load your data (list of dicts) from a JSON file.
# Each record should contain all the fields defined in the index schema.
with open("normalized_financial_data (1).json", "r") as f:
    records = json.load(f)  # This is likely a list of dicts, each representing a company or report

# --- Prepare Documents for Upload ---
# For each record, create a document dictionary matching the index schema.
documents = []
for record in records:
    documents.append({
        "id": str(uuid.uuid4()),  # Generate a unique ID for each document
        "company_name": record.get("company_name", "Apple Inc."),  # Default to Apple Inc. if missing
        "cik": record.get("cik", "0000320193"),
        "fiscal_year": record.get("fiscal_year", "2023"),
        "revenue": record.get("net_sales", 0),
        "assets": record.get("total_assets", 0),
        "liabilities": record.get("total_liabilities", 0),
        "equity": record.get("shareholders_equity", 0),
        "net_income": record.get("net_income", 0),
        "country": record.get("country", "United States"),
        "industry": record.get("industry", "Technology"),
        "report_url": record.get("report_url", "https://example.com/apple-q1-2023-report"),
        "content": record.get("content", "Full text or summary of the document here")
    })

# --- Upload Documents to Azure Search Index ---
# Create a SearchClient for the index and upload all documents in a batch.
client = SearchClient(endpoint=endpoint, index_name=index_name, credential=AzureKeyCredential(key))

# Upload the documents to the index. The result contains status for each document.
result = client.upload_documents(documents=documents)

# --- Debug/Verification Output ---
# Print the first document for inspection and confirm the upload count.
import pprint
pprint.pprint(documents[0])  # Print the first document to verify structure and content
print("Uploaded", len(documents), "documents:", result)  # Print the number of documents uploaded and the result

# === Notes ===
# - This script creates an Azure Cognitive Search index and uploads financial data for search and analytics.
# - Make sure your Azure Search service is running and the admin key is valid.
# - The index schema must match the structure of your input data.
# - You can customize the schema and fields as needed for your use case.
# - For large datasets, consider batching uploads and handling errors for individual documents.
# - Always keep your admin keys secure and never expose them in public repositories.