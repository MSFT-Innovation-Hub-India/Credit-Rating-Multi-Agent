class AzureConfig {
  //Blob Storage for Docs Configuration
  static const String storageAccount = 'YOUR-STORAGE-ACCOUNT-NAME';
  static const String containerName = 'YOUR-CONTAINER-NAME';
  static const String sasToken =
      'YOUR-SAS-TOKEN'; //MUST HAVE: Read/Write/Delete/List permissions

  static String get baseUrl =>
      'https://$storageAccount.blob.core.windows.net/$containerName';

  static String get sasQuery => '?$sasToken';

  //Azure Speech Services Configuration
  static const String speechServiceKey = 'YOUR-SPEECH';
  static const String speechServiceRegion =
      'YOUR-REGION'; // e.g., 'eastus', 'westus2'
  static const String speechServiceEndpoint =
      'https://$speechServiceRegion.api.cognitive.microsoft.com/';

  //Agent localhost base URL
  static const String agentBaseUrl =
      'YOUR-AGENT-LOCALHOST-URL'; // e.g., 'http://localhost:5000'
}
