# === delete.py ===
# This script is used to delete an existing index from your Azure Cognitive Search service.
# Deleting an index will permanently remove all indexed data and schema for that index.
# Use this script with caution, especially in production environments.

from azure.core.credentials import AzureKeyCredential  # Import for Azure authentication
from azure.search.documents.indexes import SearchIndexClient  # Import for managing search indexes
import os
from dotenv import load_dotenv

load_dotenv()

# --- Azure Cognitive Search Configuration ---
endpoint = os.getenv("AI-SEARCH-ENDPOINT")  # The endpoint URL for your Azure Search service
key = os.getenv("AI-SEARCH-API-KEY")  # Admin API key for authentication (keep this secure!)
index_name = os.getenv("AI-SEARCH-INDEX-NAME-OLD")  # The name of the index you want to delete

# --- Create the SearchIndexClient ---
# This client allows you to manage (create, delete, update) indexes in your Azure Search service.
index_client = SearchIndexClient(endpoint=endpoint, credential=AzureKeyCredential(key))

# --- Delete the Index ---
# This command deletes the specified index from your Azure Search service.
# If the index does not exist, an error will be raised.
index_client.delete_index(index_name)

# --- Confirmation Output ---
# Print a confirmation message to indicate successful deletion.
print(f"Deleted index: {index_name}")

# === Notes ===
# - Make sure you have the correct endpoint, key, and index name before running this script.
# - Deleting an index cannot be undone. All data and schema in the index will be lost.
# - You must have admin privileges on the Azure Search service to delete indexes.
# - For production environments, consider adding error handling or confirmation prompts.