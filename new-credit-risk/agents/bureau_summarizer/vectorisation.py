# =====================================
# Create & Populate Azure Cognitive Vector Index
# =====================================
# This script:
# - Creates a vector index on Azure Search
# - Downloads DOCX/XLSX files from Azure Blob Storage
# - Converts them into embeddings using SentenceTransformer
# - Uploads them to the index for vector search

import os
import uuid
import docx2txt
import pandas as pd
from sentence_transformers import SentenceTransformer
from azure.core.credentials import AzureKeyCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents import SearchClient
from azure.search.documents.indexes.models import (
    SearchIndex, SearchField, SimpleField, SearchableField,
    SearchFieldDataType, VectorSearch, VectorSearchProfile,
    HnswAlgorithmConfiguration
)
from azure.storage.blob import BlobServiceClient
import os
from dotenv import load_dotenv

# =====================================
# Configuration
# =====================================
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

# Azure Search Configuration
AZURE_SEARCH_ENDPOINT = os.getenv("BEAURAU-SEARCH-ENDPOINT")
AZURE_SEARCH_KEY =  os.getenv("BEAURAU-API-KEY")
INDEX_NAME = os.getenv("BEAURAU-INDEX-NAME")


# Blob Storage Configuration
BLOB_ACCOUNT_NAME = os.getenv("BLOB-INDEX-ACCOUNT-NAME")
BLOB_ACCOUNT_KEY = os.getenv("BLOB-INDEX-ACCOUNT-KEY")
CONTAINER_NAME = os.getenv("BLOB-INDEX-CONTAINER-NAME")
# Azure Blob Configuration
BLOB_CONNECTION_STRING = (
    "DefaultEndpointsProtocol=https;"
    f"AccountName={BLOB_ACCOUNT_NAME};"
    f"AccountKey={BLOB_ACCOUNT_KEY};"
    "EndpointSuffix=core.windows.net"
)

# Output folder for temporary file downloads
DOWNLOAD_FOLDER = os.path.join("output_data")
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# Load SentenceTransformer model for text embedding
model = SentenceTransformer("all-MiniLM-L6-v2")

# =====================================
# Define Search Index Schema
# =====================================

fields = [
    SimpleField(name="id", type=SearchFieldDataType.String, key=True),
    SearchableField(name="filename", type=SearchFieldDataType.String),
    SearchableField(name="content", type=SearchFieldDataType.String),
    SearchField(
        name="content_vector",
        type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
        searchable=True,
        vector_search_dimensions=384,
        vector_search_profile_name="default"
    )
]

# Vector search configuration using HNSW algorithm
vector_search = VectorSearch(
    profiles=[
        VectorSearchProfile(name="default", algorithm_configuration_name="my-hnsw")
    ],
    algorithms=[
        HnswAlgorithmConfiguration(name="my-hnsw", kind="hnsw", parameters={"m": 4, "efConstruction": 400})
    ]
)

# Create the index definition
index = SearchIndex(name=INDEX_NAME, fields=fields, vector_search=vector_search)
print(f"Creating index: {INDEX_NAME} with fields: {fields}")


# Create the index on Azure
index_client = SearchIndexClient(endpoint=AZURE_SEARCH_ENDPOINT, credential=AzureKeyCredential(AZURE_SEARCH_KEY))
try:
    index_client.create_index(index)
    print(f"✅ Created index: {INDEX_NAME}")
except Exception as e:
    print(f"⚠️ Index creation failed: {e}")

# =====================================
# Download & Preprocess Files from Blob Storage
# =====================================

blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
container_client = blob_service_client.get_container_client(CONTAINER_NAME)

blobs = list(container_client.list_blobs())
documents = []

for blob in blobs:
    if blob.name.endswith('/'):  # Skip folders
        continue

    download_path = os.path.join(DOWNLOAD_FOLDER, blob.name)
    
    # Download the file
    with open(download_path, "wb") as f:
        stream = container_client.download_blob(blob.name)
        f.write(stream.readall())
    print(f"📥 Downloaded: {download_path}")

    # Extract content
    if blob.name.endswith(".docx"):
        content = docx2txt.process(download_path)
    elif blob.name.endswith(".xlsx"):
        try:
            df = pd.read_excel(download_path, sheet_name=None)
            content = "\n".join([df[sheet].to_string() for sheet in df])
        except Exception as e:
            print(f"⚠️ Error reading {blob.name}: {e}")
            content = ""
    else:
        # Fallback: Read as plain text
        with open(download_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

    # Generate vector embedding
    embedding = model.encode(content).tolist()

    # Prepare document for upload
    documents.append({
        "id": str(uuid.uuid4()),
        "filename": blob.name,
        "content": content,
        "content_vector": embedding
    })

# =====================================
# Upload to Azure Vector Search Index
# =====================================

search_client = SearchClient(endpoint=AZURE_SEARCH_ENDPOINT, index_name=INDEX_NAME, credential=AzureKeyCredential(AZURE_SEARCH_KEY))
result = search_client.upload_documents(documents)

print(f"\n📤 Upload result: {result}")
for item in result:
    if item.succeeded:
        print(f"✅ {item.key}")
    else:
        print(f"❌ Failed: {item.key} | Error: {item.error_message}")
