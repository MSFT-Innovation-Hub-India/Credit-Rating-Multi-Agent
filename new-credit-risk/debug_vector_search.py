import json
import requests
from sentence_transformers import SentenceTransformer
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential

import os
from dotenv import load_dotenv

# Load environment variables from .env file in the root directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

# Copy your config from bureau_pipeline.py
AZURE_SEARCH_ENDPOINT = os.getenv("BEAURAU-SEARCH-ENDPOINT")
AZURE_SEARCH_KEY = os.getenv("BEAURAU-API-KEY")
INDEX_NAME = os.getenv("BEAURAU-INDEX-NAME")

print(AZURE_SEARCH_ENDPOINT, AZURE_SEARCH_KEY, INDEX_NAME)

# Initialize
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
search_client = SearchClient(
    endpoint=AZURE_SEARCH_ENDPOINT,
    index_name=INDEX_NAME,
    credential=AzureKeyCredential(AZURE_SEARCH_KEY)
)

def check_index_schema():
    """Check the actual index schema"""
    print("="*60)
    print("CHECKING INDEX SCHEMA")
    print("="*60)
    
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Index schema request status: {response.status_code}")
        
        if response.status_code == 200:
            schema = response.json()
            print("\nIndex fields:")
            for field in schema.get("fields", []):
                print(f"- {field['name']}: {field['type']}")
                if field['type'] == 'Collection(Edm.Single)':
                    print(f"  └─ Vector field dimensions: {field.get('dimensions', 'Not specified')}")
            
            # Check vector search configuration
            vector_search = schema.get("vectorSearch")
            if vector_search:
                print("\n✅ Vector search configuration found:")
                print(f"Profiles: {[p['name'] for p in vector_search.get('profiles', [])]}")
                print(f"Algorithms: {[a['name'] for a in vector_search.get('algorithms', [])]}")
            else:
                print("\n❌ NO VECTOR SEARCH CONFIGURATION FOUND!")
                return False
                
            return True
        else:
            print(f"Failed to get schema: {response.text}")
            return False
            
    except Exception as e:
        print(f"Error checking schema: {e}")
        return False

def test_simple_search():
    """Test basic text search"""
    print("\n" + "="*60)
    print("TESTING SIMPLE TEXT SEARCH")
    print("="*60)
    
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    # Simple search payload
    payload = {
        "search": "*",
        "top": 3,
        "select": ["id", "content"]
    }
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        print(f"Simple search status: {response.status_code}")
        
        if response.status_code == 200:
            results = response.json()
            doc_count = len(results.get("value", []))
            print(f"✅ Found {doc_count} documents")
            
            # Show sample document
            if doc_count > 0:
                sample_doc = results["value"][0]
                print(f"Sample document ID: {sample_doc.get('id', 'No ID')}")
                content_preview = sample_doc.get('content', '')[:100]
                print(f"Content preview: {content_preview}...")
                
                # Check for company identifiers
                content_full = sample_doc.get('content', '').lower()
                if 'novasynth' in content_full:
                    print("✅ Contains NovaSynth data")
                elif 'terradrive' in content_full:
                    print("✅ Contains TerraDrive data")
                else:
                    print("❓ Company not identified in content")
            return True
        else:
            print(f"❌ Simple search failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Simple search error: {e}")
        return False

def test_vector_search_minimal():
    """Test minimal vector search"""
    print("\n" + "="*60)
    print("TESTING MINIMAL VECTOR SEARCH")
    print("="*60)
    
    # Create a simple test vector
    test_query = "financial information"
    query_vector = embedding_model.encode(test_query).tolist()
    print(f"Generated vector with {len(query_vector)} dimensions")
    
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    # Minimal vector payload
    payload = {
        "vectors": [
            {
                "value": query_vector,
                "fields": "content_vector",
                "k": 3
            }
        ],
        "top": 3
    }
    
    print("Vector search payload:")
    print(json.dumps(payload, indent=2))
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        print(f"\nVector search status: {response.status_code}")
        
        if response.status_code == 200:
            results = response.json()
            doc_count = len(results.get("value", []))
            print(f"✅ Vector search successful! Found {doc_count} documents")
            return True
        else:
            print(f"❌ Vector search failed:")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Vector search error: {e}")
        return False

def test_hybrid_search():
    """Test hybrid search (text + vector)"""
    print("\n" + "="*60)
    print("TESTING HYBRID SEARCH")
    print("="*60)
    
    test_query = "assets liabilities financial"
    query_vector = embedding_model.encode(test_query).tolist()
    
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    # Hybrid search payload
    payload = {
        "search": test_query,
        "vectors": [
            {
                "value": query_vector,
                "fields": "content_vector",
                "k": 3
            }
        ],
        "top": 3
    }
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        print(f"Hybrid search status: {response.status_code}")
        
        if response.status_code == 200:
            results = response.json()
            doc_count = len(results.get("value", []))
            print(f"✅ Hybrid search successful! Found {doc_count} documents")
            return True
        else:
            print(f"❌ Hybrid search failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Hybrid search error: {e}")
        return False

def test_company_filtering():
    """Test company-specific filtering"""
    print("\n" + "="*60)
    print("TESTING COMPANY FILTERING")
    print("="*60)
    
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version=2023-07-01-preview"
    headers = {
        "Content-Type": "application/json",
        "api-key": AZURE_SEARCH_KEY
    }
    
    # Test different filter syntaxes
    filter_tests = [
        ("ID prefix search", "search.ismatch('novasynth_*', 'id')"),
        ("ID contains", "contains(id, 'novasynth')"),
        ("ID starts with", "startswith(id, 'novasynth')"),
    ]
    
    for test_name, filter_expr in filter_tests:
        print(f"\nTesting {test_name}: {filter_expr}")
        
        payload = {
            "search": "*",
            "filter": filter_expr,
            "top": 3,
            "select": ["id"]
        }
        
        try:
            response = requests.post(url, headers=headers, data=json.dumps(payload))
            if response.status_code == 200:
                results = response.json()
                doc_count = len(results.get("value", []))
                print(f"✅ {test_name} worked: {doc_count} documents")
                if doc_count > 0:
                    sample_ids = [doc["id"] for doc in results["value"]]
                    print(f"Sample IDs: {sample_ids}")
            else:
                print(f"❌ {test_name} failed: {response.text}")
        except Exception as e:
            print(f"❌ {test_name} error: {e}")

def test_sdk_search():
    """Test using Azure SDK instead of REST API"""
    print("\n" + "="*60)
    print("TESTING AZURE SDK SEARCH")
    print("="*60)
    
    try:
        # Simple SDK search
        print("Testing SDK text search...")
        results = search_client.search("*", top=3)
        doc_count = 0
        for result in results:
            doc_count += 1
            if doc_count <= 3:
                print(f"Document {doc_count}: ID = {result.get('id', 'No ID')}")
        
        print(f"✅ SDK search successful: {doc_count} documents found")
        return True
        
    except Exception as e:
        print(f"❌ SDK search failed: {e}")
        return False

def diagnose_vector_dimensions():
    """Check if vector dimensions match"""
    print("\n" + "="*60)
    print("DIAGNOSING VECTOR DIMENSIONS")
    print("="*60)
    
    # Test embedding dimensions
    test_text = "This is a test"
    test_vector = embedding_model.encode(test_text)
    print(f"SentenceTransformer vector dimensions: {len(test_vector)}")
    
    # Check index schema for vector field dimensions
    url = f"{AZURE_SEARCH_ENDPOINT}/indexes/{INDEX_NAME}?api-version=2023-07-01-preview"
    headers = {"api-key": AZURE_SEARCH_KEY}
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            schema = response.json()
            for field in schema.get("fields", []):
                if field.get("type") == "Collection(Edm.Single)":
                    index_dims = field.get("dimensions")
                    print(f"Index '{field['name']}' dimensions: {index_dims}")
                    
                    if index_dims and index_dims != len(test_vector):
                        print(f"❌ DIMENSION MISMATCH! Model: {len(test_vector)}, Index: {index_dims}")
                        return False
                    else:
                        print(f"✅ Dimensions match!")
                        return True
        return False
    except Exception as e:
        print(f"Error checking dimensions: {e}")
        return False

def run_all_tests():
    """Run comprehensive diagnostics"""
    print("AZURE SEARCH VECTOR DIAGNOSTIC TOOL")
    print("="*60)
    
    tests = [
        ("Index Schema", check_index_schema),
        ("Simple Search", test_simple_search),
        ("Vector Dimensions", diagnose_vector_dimensions),
        ("Vector Search", test_vector_search_minimal),
        ("Hybrid Search", test_hybrid_search),
        ("Company Filtering", test_company_filtering),
        ("SDK Search", test_sdk_search),
    ]
    
    results = {}
    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"❌ {test_name} crashed: {e}")
            results[test_name] = False
    
    # Summary
    print("\n" + "="*60)
    print("DIAGNOSTIC SUMMARY")
    print("="*60)
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name}: {status}")
    
    # Recommendations
    print("\n" + "="*60)
    print("RECOMMENDATIONS")
    print("="*60)
    
    if not results.get("Index Schema", False):
        print("🔧 Your index may not exist or have vector search configured")
    elif not results.get("Vector Dimensions", False):
        print("🔧 Vector dimension mismatch - recreate index with correct dimensions")
    elif not results.get("Vector Search", False):
        print("🔧 Vector search API issue - try using SDK or different API version")
    elif results.get("Simple Search", False):
        print("✅ Use simple text search as fallback")
    else:
        print("✅ Everything looks good - check your specific query")

if __name__ == "__main__":
    run_all_tests()