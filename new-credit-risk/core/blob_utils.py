# =====================================
# Azure Blob Upload Utility
# =====================================

from azure.storage.blob import BlobServiceClient
import os
from dotenv import load_dotenv

# =====================================
# Azure Storage Configuration
# =====================================

# Load environment variables from .env file in the root directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))


# Connection string to authenticate with Azure Blob Storage

AccountName =  os.getenv("BLOB_ACCOUNT_NAME")
AccountKey = os.getenv("BLOB_ACCOUNT_KEY")
# Name of the container where files will be uploaded
container_name = os.getenv("BLOB_CONTAINER_NAME")

connection_string = (
    "DefaultEndpointsProtocol=https;"
    f"AccountName={AccountName};"
    f"AccountKey={AccountKey};"
    "EndpointSuffix=core.windows.net"
)



# Initialize the BlobServiceClient and get a container client for use across uploads
blob_service_client = BlobServiceClient.from_connection_string(connection_string)
container_client = blob_service_client.get_container_client(container_name)

# =====================================
# Upload Function
# =====================================

def upload_file_to_blob(file_obj, blob_name: str):
    """
    Uploads a file-like object to Azure Blob Storage.

    Parameters:
    - file_obj: An object with a `.stream` attribute (e.g., Flask FileStorage or BytesIO).
    - blob_name (str): The name under which the file should be stored in the blob container.

    Returns:
    - str: Success message indicating the blob name uploaded.
    
    Behavior:
    - Overwrites any existing blob with the same name.
    - Suitable for real-time document uploads via web forms or pipelines.
    """
    # Upload the file stream to the specified blob
    container_client.upload_blob(name=blob_name, data=file_obj.stream, overwrite=True)
    
    return f"Uploaded to blob: {blob_name}"
