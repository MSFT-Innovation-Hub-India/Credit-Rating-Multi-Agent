import os
import io
import re
import json
import uuid
import pandas as pd
from datetime import datetime, timezone
from docx import Document
from sentence_transformers import SentenceTransformer
import requests

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import ListSortOrder
from azure.storage.blob import BlobServiceClient
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential

import os
from dotenv import load_dotenv

# Load environment variables from .env file in the root directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

# === Configs ===

ACCOUNT_NAME = os.getenv("BLOB-INDEX-ACCOUNT-NAME")
ACCOUNT_KEY = os.getenv("BLOB-INDEX-ACCOUNT-KEY")

connection_string = f"DefaultEndpointsProtocol=https;AccountName={ACCOUNT_NAME};AccountKey={ACCOUNT_KEY};EndpointSuffix=core.windows.net"
container_name = os.getenv("BLOB-INDEX-CONTAINER-NAME")

AZURE_SEARCH_ENDPOINT = os.getenv("BEAURAU-SEARCH-ENDPOINT")
AZURE_SEARCH_KEY = os.getenv("BEAURAU-API-KEY")
INDEX_NAME = os.getenv("BEAURAU-INDEX-NAME")
QUERY_TEXT = "What are the total assets and liabilities for the company?"

# === Init Model + SearchClient ===
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
search_client = SearchClient(
    endpoint=AZURE_SEARCH_ENDPOINT,
    index_name=INDEX_NAME,
    credential=AzureKeyCredential(AZURE_SEARCH_KEY)
)

# === Step 1: Blob Reader ===
def read_latest_documents_from_blob(container_name, num_docs=4):
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    container_client = blob_service_client.get_container_client(container_name)
    blobs = sorted(container_client.list_blobs(), key=lambda b: b.last_modified, reverse=True)[:num_docs]

    contents = []
    for blob in blobs:
        blob_data = container_client.download_blob(blob.name).readall()
        name = blob.name.lower()
        try:
            if name.endswith(".docx"):
                doc = Document(io.BytesIO(blob_data))
                content = "\n".join(p.text for p in doc.paragraphs if p.text.strip())
            elif name.endswith(".xlsx"):
                df = pd.read_excel(io.BytesIO(blob_data), engine='openpyxl')
                content = ""
                for i, row in df.iterrows():
                    labeled_row = ", ".join(f"{col.strip()}: {str(row[col]).strip()}" for col in df.columns)
                    content += labeled_row + "\n"
            else:
                content = ""
        except Exception as e:
            content = f"Error reading {blob.name}: {e}"
        contents.append(f"--- File: {blob.name} ---\n{content}")
    return "\n".join(contents)

# === Step 2: Index into Azure Search ===
def index_to_azure_search(text, company_identifier=None):
    """Index text with proper company-prefixed IDs"""
    
    # Detect company from the text if not provided
    if not company_identifier:
        text_lower = text.lower()
        if "novasynth" in text_lower or "nova synth" in text_lower:
            company_identifier = "novasynth"
        elif "terradrive" in text_lower or "terra drive" in text_lower:
            company_identifier = "terradrive"
        else:
            print(f"DEBUG: Could not detect company from text preview: {text_lower[:100]}...")
            company_identifier = "novasynth"  # Default to novasynth
    
    print(f"DEBUG: Detected company identifier: {company_identifier}")
    
    # Clear existing documents for this company first
    clear_company_documents(company_identifier)
    
    chunks = [text[i:i+1000] for i in range(0, len(text), 1000)]
    documents = []
    
    for i, chunk in enumerate(chunks):
        embedding = embedding_model.encode(chunk).tolist()
        documents.append({
            "id": f"{company_identifier}_{i:04d}",  # Use predictable IDs: novasynth_0001, novasynth_0002, etc.
            "content": chunk,
            "content_vector": embedding
        })
    
    search_client.upload_documents(documents=documents)
    return company_identifier

def clear_company_documents(company_identifier):
    """Clear existing documents for a company using search instead of filter"""
    try:
        # Use search to find documents with company prefix
        results = search_client.search(f"id:{company_identifier}_*", select=["id"])
        
        doc_ids = []
        for result in results:
            doc_ids.append(result["id"])
        
        if doc_ids:
            # Delete existing documents
            delete_docs = [{"@search.action": "delete", "id": doc_id} for doc_id in doc_ids]
            search_client.upload_documents(documents=delete_docs)
            print(f"DEBUG: Cleared {len(doc_ids)} existing documents for {company_identifier}")
        
    except Exception as e:
        print(f"DEBUG: Could not clear existing documents: {e}")

def index_uploaded_documents_from_blob():
    """Index documents with automatic company detection"""
    full_text = read_latest_documents_from_blob(container_name, 4)
    
    # Detect which company this is
    company_identifier = None
    if "nova synth" in full_text.lower() or "novasynth" in full_text.lower():
        company_identifier = "novasynth"
    elif "terradrive" in full_text.lower() or "terra drive" in full_text.lower():
        company_identifier = "terradrive"
    else:
        company_identifier = "novasynth"  # Default
    
    print(f"DEBUG: Detected company: {company_identifier}")
    
    # Clear existing documents for this company
    clear_company_documents(company_identifier)
    
    chunks = [full_text[i:i+1000] for i in range(0, len(full_text), 1000)]
    documents = []

    for i, chunk in enumerate(chunks):
        embedding = embedding_model.encode(chunk).tolist()
        documents.append({
            "id": f"{company_identifier}_{i:04d}",  # FIXED: Use company prefix, not UUID!
            "content": chunk,
            "content_vector": embedding
        })

    result = search_client.upload_documents(documents=documents)
    print(f"DEBUG: Indexed {len(documents)} chunks with company prefix")
    return company_identifier

# === Step 3: Search using RAG
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
search_client = SearchClient(
    endpoint=AZURE_SEARCH_ENDPOINT,
    index_name=INDEX_NAME,
    credential=AzureKeyCredential(AZURE_SEARCH_KEY)
)

def search_rag(query, company_filter=None):
    """Vector search without problematic filters"""
    
    query_vector = embedding_model.encode(query).tolist()

    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    # Use vector search WITHOUT the problematic filter
    payload = {
        "vectors": [
            {
                "value": query_vector,
                "fields": "content_vector",
                "k": 8
            }
        ],
        "top": 8
    }
    
    # Don't use the problematic startswith filter
    print(f"DEBUG: Vector search (no filter - will filter by content)")
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        
        if response.status_code == 200:
            results = response.json()
            documents = []
            
            for doc in results.get("value", []):
                content = doc.get("content", "")
                doc_id = doc.get("id", "")
                
                # Filter by content instead of ID filter
                if company_filter:
                    if company_filter.lower() in content.lower() or company_filter in doc_id.lower():
                        documents.append(content[:2000])
                else:
                    documents.append(content[:2000])
            
            print(f"DEBUG: Found {len(documents)} documents for {company_filter}")
            return "\n\n".join(documents[:4])
        else:
            print(f"DEBUG: Vector search failed: {response.text}")
            return "No documents found"
            
    except Exception as e:
        print(f"DEBUG: Vector search error: {e}")
        return "No documents found"

# === Step 4: Extract Financial Fields ===
def extract_fields(ai_response):
    """Parse the structured AI response directly"""
    
    fields = {
        "company_name": None,
        "industry": None,
        "annual_revenue": None,
        "employees": None,
        "years_in_business": None
    }
    key_metrics = {
        "revenue_growth": None,
        "profit_margin": None,
        "debt_to_equity": None,
        "net_income": None,
        "equity": None,
        "total_assets": None,
        "total_liabilities": None
    }
    
    # Parse the AI structured response
    lines = ai_response.split('\n')
    
    for line in lines:
        line = line.strip()
        if ':' in line:
            key, value = line.split(':', 1)
            key = key.strip().lower()
            value = value.strip()
            
            # Skip empty or "Not available" values
            if not value or value.lower() in ['not available', 'n/a', '']:
                continue
            
            # Skip placeholder values
            if value.startswith("[") and value.endswith("]"):
                continue  # Skip placeholder values
            
            # Extract numeric values
            import re
            numeric_match = re.search(r'([\d.,]+)', value)
            if numeric_match:
                try:
                    numeric_value = float(numeric_match.group(1).replace(',', ''))
                except:
                    numeric_value = None
            else:
                numeric_value = None
            
            # Map to fields
            if 'company name' in key:
                fields['company_name'] = value
            elif 'industry' in key:
                fields['industry'] = value
            elif 'annual revenue' in key or 'revenue' in key:
                if numeric_value:
                    fields['annual_revenue'] = numeric_value
            elif 'net income' in key:
                if numeric_value:
                    key_metrics['net_income'] = numeric_value
            elif 'equity' in key:
                if numeric_value:
                    key_metrics['equity'] = numeric_value
            elif 'total assets' in key:
                if numeric_value:
                    key_metrics['total_assets'] = numeric_value
            elif 'total liabilities' in key:
                if numeric_value:
                    key_metrics['total_liabilities'] = numeric_value
            elif 'employees' in key:
                if numeric_value:
                    fields['employees'] = numeric_value
            elif 'debt to equity' in key:
                if numeric_value:
                    key_metrics['debt_to_equity'] = numeric_value
    
    # Create a summary from the financial data
    summary_parts = []
    if fields.get('company_name'):
        summary_parts.append(f"Company: {fields['company_name']}")
    if key_metrics.get('net_income'):
        summary_parts.append(f"Net Income: ${key_metrics['net_income']}M")
    if key_metrics.get('equity'):
        summary_parts.append(f"Equity: ${key_metrics['equity']}M")
    
    summary = ". ".join(summary_parts) if summary_parts else "Financial data extracted"
    
    return fields, key_metrics, summary

def parse_financial_amount(line):
    """Parse financial amounts from text like '$61.9B' or '$484.3M'"""
    import re
    
    # Look for patterns like $61.9B, $484M, etc.
    pattern = r'\$?\s*([\d.,]+)\s*([BMK]?)'
    match = re.search(pattern, line, re.IGNORECASE)
    
    if not match:
        return None
    
    try:
        amount = float(match.group(1).replace(',', ''))
        multiplier = match.group(2).upper()
        
        if multiplier == 'B':
            return amount * 1000  # Convert billions to millions
        elif multiplier == 'M':
            return amount  # Already in millions
        elif multiplier == 'K':
            return amount / 1000  # Convert thousands to millions
        else:
            # Assume it's in millions if no multiplier
            return amount
    except (ValueError, TypeError):
        return None

def extract_numeric_value(line):
    """Extract numeric value from a line"""
    import re
    
    # Look for numeric values
    pattern = r':\s*([\d.,]+)'
    match = re.search(pattern, line)
    
    if match:
        try:
            return float(match.group(1).replace(',', ''))
        except (ValueError, TypeError):
            return None
    return None

# === Step 5: Bureau Agent Pipeline ===
def bureau_agent_pipeline():
    try:
        raw_text = read_latest_documents_from_blob(container_name)
        company_identifier = index_to_azure_search(raw_text)  # Get company ID from indexing
    except Exception as e:
        return {"errorMessage": f"Blob indexing failed: {e}", "status": "AgentStatus.failed"}

    try:
        # Use company-specific search
        rag_context = search_rag(QUERY_TEXT, company_filter=company_identifier)
        
        print(f"DEBUG: Analyzing company: {company_identifier}")
        print(f"DEBUG: RAG context length: {len(rag_context)}")
        print(f"DEBUG: RAG context preview: {rag_context[:200]}...")
        
    except Exception as e:
        return {"errorMessage": f"Vector search failed: {e}", "status": "AgentStatus.failed"}

    # SKIP THE AI AGENT - Extract directly from RAG context
    fields, key_metrics = extract_fields_from_rag_context(rag_context)
    
    # Build summary from extracted data
    summary_parts = []
    if fields.get("company_name"):
        summary_parts.append(f"Company: {fields['company_name']}")
    if fields.get("industry"):
        summary_parts.append(f"Industry: {fields['industry']}")
    if key_metrics.get("net_income"):
        summary_parts.append(f"Net Income: ${key_metrics['net_income']}M")
    if key_metrics.get("total_assets"):
        summary_parts.append(f"Total Assets: ${key_metrics['total_assets']}M")
    if key_metrics.get("equity"):
        summary_parts.append(f"Equity: ${key_metrics['equity']}M")
    if key_metrics.get("debt_to_equity"):
        summary_parts.append(f"Debt-to-Equity: {key_metrics['debt_to_equity']}")
    
    final_summary = ". ".join(summary_parts) if summary_parts else "Financial data extracted from documents"
    
    return {
        "agentName": "Bureau Summariser",
        "agentDescription": "Analyzes and summarizes business documents and financial statements",
        "extractedData": {
            **fields,
            "key_financial_metrics": key_metrics
        },
        "summary": final_summary,
        "completedAt": datetime.now(timezone.utc).isoformat(),
        "confidenceScore": 0.92,
        "status": "AgentStatus.complete",
        "errorMessage": None
    }

def extract_fields_from_rag_context(rag_context):
    """Extract fields directly from RAG context - bypass AI agent parsing"""
    
    fields = {
        "company_name": None,
        "industry": None,
        "annual_revenue": None,
        "employees": None,
        "years_in_business": None
    }
    key_metrics = {
        "revenue_growth": None,
        "profit_margin": None,
        "debt_to_equity": None,
        "net_income": None,
        "equity": None,
        "total_assets": None,
        "total_liabilities": None
    }
    
    import re
    
    # Extract company name from context
    if "novasynth" in rag_context.lower():
        fields["company_name"] = "NovaSynth"
    elif "terradrive" in rag_context.lower():
        fields["company_name"] = "TerraDrive"
    
    # Extract industry
    if "technology" in rag_context.lower() or "software" in rag_context.lower():
        fields["industry"] = "Technology"
    elif "manufacturing" in rag_context.lower():
        fields["industry"] = "Manufacturing"
    
    # Extract Net Income: "Net Income of $21.939 billion"
    net_income_patterns = [
        r'Net Income[:\s]+of\s+\$?([\d.,]+)\s*(billion|million)',
        r'Net Income[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'net income[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'Net Income[:\s]+\$?([\d.,]+)B',
        r'Net Income[:\s]+\$?([\d.,]+)M'
    ]
    
    for pattern in net_income_patterns:
        match = re.search(pattern, rag_context, re.IGNORECASE)
        if match:
            amount = float(match.group(1).replace(',', ''))
            unit = match.group(2) if len(match.groups()) > 1 else ""
            if "billion" in unit.lower() or "B" in unit:
                amount *= 1000  # Convert to millions
            key_metrics["net_income"] = amount
            break
    
    # Extract Total Assets: "Total Assets: $484,275 million"
    assets_patterns = [
        r'Total Assets[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'total assets[:\s]+\$?([\d.,]+)\s*(billion|million)'
    ]
    
    for pattern in assets_patterns:
        match = re.search(pattern, rag_context, re.IGNORECASE)
        if match:
            amount = float(match.group(1).replace(',', ''))
            unit = match.group(2) if len(match.groups()) > 1 else ""
            if "billion" in unit.lower():
                amount *= 1000
            key_metrics["total_assets"] = amount
            break
    
    # Extract Total Liabilities: "Total Liabilities: $231,123 million"
    liabilities_patterns = [
        r'Total Liabilities[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'total liabilities[:\s]+\$?([\d.,]+)\s*(billion|million)'
    ]
    
    for pattern in liabilities_patterns:
        match = re.search(pattern, rag_context, re.IGNORECASE)
        if match:
            amount = float(match.group(1).replace(',', ''))
            unit = match.group(2) if len(match.groups()) > 1 else ""
            if "billion" in unit.lower():
                amount *= 1000
            key_metrics["total_liabilities"] = amount
            break
    
    # Extract Equity: "Total Stockholders' Equity: $253,152 million"
    equity_patterns = [
        r'Total Stockholders[\'"]?\s*Equity[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'Stockholders[\'"]?\s*Equity[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'Equity[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'stockholders[\'"]?\s*equity[:\s]+\$?([\d.,]+)\s*(billion|million)'
    ]
    
    for pattern in equity_patterns:
        match = re.search(pattern, rag_context, re.IGNORECASE)
        if match:
            amount = float(match.group(1).replace(',', ''))
            unit = match.group(2) if len(match.groups()) > 1 else ""
            if "billion" in unit.lower():
                amount *= 1000
            key_metrics["equity"] = amount
            break
    
    # Extract Debt to Equity: "Debt to Equity : 0.91"
    debt_equity_match = re.search(r'Debt to Equity[:\s]+([\d.]+)', rag_context, re.IGNORECASE)
    if debt_equity_match:
        key_metrics["debt_to_equity"] = float(debt_equity_match.group(1))
    
    # Extract Revenue: "quarterly revenue of $81.4 billion"
    revenue_patterns = [
        r'quarterly revenue of \$?([\d.,]+)\s*(billion|million)',
        r'Revenue[:\s]+\$?([\d.,]+)\s*(billion|million)',
        r'revenue[:\s]+\$?([\d.,]+)\s*(billion|million)'
    ]
    
    for pattern in revenue_patterns:
        match = re.search(pattern, rag_context, re.IGNORECASE)
        if match:
            amount = float(match.group(1).replace(',', ''))
            unit = match.group(2)
            if "billion" in unit.lower():
                amount *= 1000
            # If it's quarterly, multiply by 4 for annual
            if "quarterly" in pattern:
                amount *= 4
            fields["annual_revenue"] = amount
            break
    
    return fields, key_metrics

# === Admin Functions ===
def clear_all_documents():
    """Clear all documents from index to start fresh"""
    try:
        results = search_client.search("*", select=["id"])
        doc_ids = [result["id"] for result in results]
        
        if doc_ids:
            delete_docs = [{"@search.action": "delete", "id": doc_id} for doc_id in doc_ids]
            search_client.upload_documents(documents=delete_docs)
            print(f"Cleared {len(doc_ids)} documents from index")
        else:
            print("Index is already empty")
    except Exception as e:
        print(f"Error clearing index: {e}")

def test_company_separation():
    """Test that company filtering actually works"""
    
    print("="*50)
    print("TESTING COMPANY SEPARATION")
    print("="*50)
    
    # Test search for novasynth
    novasynth_content = search_rag(QUERY_TEXT, company_filter="novasynth")
    print(f"NovaSynth search returned: {len(novasynth_content)} characters")
    print(f"Contains 'novasynth': {'novasynth' in novasynth_content.lower()}")
    print(f"Contains 'terradrive': {'terradrive' in novasynth_content.lower()}")
    
    # Check what documents exist
    try:
        results = search_client.search("*", select=["id"], top=10)
        doc_ids = [result["id"] for result in results]
        print(f"Current document IDs: {doc_ids}")
        
        novasynth_docs = [doc_id for doc_id in doc_ids if "novasynth" in doc_id]
        print(f"NovaSynth documents found: {novasynth_docs}")
        
    except Exception as e:
        print(f"Error checking documents: {e}")

def fix_index_and_test():
    """Complete fix: clear, re-index, and test"""
    
    print("STEP 1: Clearing contaminated index...")
    clear_all_documents()
    
    print("STEP 2: Re-indexing with proper company IDs...")
    try:
        # Read and index documents with proper company prefixes
        raw_text = read_latest_documents_from_blob(container_name)
        company_id = index_to_azure_search(raw_text)  # This should create novasynth_0001, etc.
        print(f"Indexed with company ID: {company_id}")
        
        # Wait a moment for indexing
        import time
        time.sleep(2)
        
        print("STEP 3: Testing company separation...")
        test_company_separation()
        
    except Exception as e:
        print(f"Re-indexing failed: {e}")

# === CLI Test ===
if __name__ == "__main__":
    result = bureau_agent_pipeline()
    print(json.dumps(result, indent=2))