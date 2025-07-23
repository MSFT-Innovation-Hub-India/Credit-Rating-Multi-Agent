import openai
from openai import AzureOpenAI
import os
from dotenv import load_dotenv

# Load environment variables from .env file in the root directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

# Retrieve sensitive information from environment variables
azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
api_key = os.getenv("AZURE_OPENAI_API_KEY")
api_version = os.getenv("AZURE_OPENAI_API_VERSION")
deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")

# Initialize AzureOpenAI client
client = AzureOpenAI(
    azure_endpoint=azure_endpoint,
    api_key=api_key,
    api_version=api_version
)

try:
    response = client.chat.completions.create(
        model=deployment_name,  # Use the deployment name from .env
        messages=[{"role": "user", "content": "Hello, test connection"}],
        max_tokens=10
    )
    print("Connection successful!")
    print(response.choices[0].message.content)
except Exception as e:
    print(f"Connection failed: {e}")