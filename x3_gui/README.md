# X³ Credit Assistant Frontend

This is the Flutter frontend for X³ Credit Assistant, an AI-powered platform for corporate credit scoring and financial document analysis.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x recommended)
- Dart (comes with Flutter)
- Azure account (for Speech and Blob Storage services)

## Dependencies

All dependencies are managed via [`pubspec.yaml`](pubspec.yaml). 
Run the following to fetch dependencies:
```sh
flutter pub get
```

## Azure Setup

Edit [`lib/services/azure_config.dart`](lib/services/azure_config.dart):

- **Blob Storage**:  
  - `storageAccount`: Your Azure Storage account name  
  - `containerName`: Your Blob container name  
  - `sasToken`: SAS token with read/write/delete/list permissions

- **Speech Services**:  
  - `speechServiceKey`: Your Azure Speech API key  
  - `speechServiceRegion`: Your Azure region (e.g., `eastus`)
- **Agent Local Host API**
  - `agentBaseUrl`: given when running the agents 

Example:
```dart
class AzureConfig {
  static const String storageAccount = 'your_storage_account';
  static const String containerName = 'your_container_name';
  static const String sasToken = 'your_sas_token';
  static const String speechServiceKey = 'your_speech_api_key';
  static const String speechServiceRegion = 'your_region';
}
```

## Running the Frontend

### For Desktop (Windows)
```sh
flutter run -d windows
```

alternatively
```sh
flutter run
```
select windows as target build (usually ```[1]``` on command line)

## Troubleshooting
- If you encounter missing dependencies, run `flutter pub get`.
- If the build fails run `flutter clean` and rebuild
- Run `flutter doctor` for general troubleshooting
- For Azure errors, verify keys and permissions in [`lib/services/azure_config.dart`](lib/services/azure_config.dart).
- For platform-specific issues, consult the [Flutter documentation](https://docs.flutter.dev/).
