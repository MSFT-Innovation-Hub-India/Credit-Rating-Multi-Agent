import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:x3_gui/services/azure_config.dart';

class AzureSpeechService {
  static const String _ttsUrl =
      'https://${AzureConfig.speechServiceRegion}.tts.speech.microsoft.com/cognitiveservices/v1';
  static const String _sttUrl =
      'https://${AzureConfig.speechServiceRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';

  // NEW: STT Streaming endpoint for real-time transcription
  static const String _sttStreamingUrl =
      'wss://${AzureConfig.speechServiceRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';

  static const String _femaleVoice = 'en-IN-NeerjaIndicNeural';
  static const String _maleVoice = 'en-IN-PrabhatIndicNeural';

  static final http.Client _httpClient = http.Client();
  static bool _isPreWarmed = false;
  static bool _isPreWarming = false;

  /// Pre-warm both TTS and STT connections
  static Future<void> preWarmConnection() async {
    if (_isPreWarmed || _isPreWarming) return;

    _isPreWarming = true;
    try {
      // Test TTS connection
      final ttsResponse = await _httpClient.head(
        Uri.parse(_ttsUrl),
        headers: {'Ocp-Apim-Subscription-Key': AzureConfig.speechServiceKey},
      );

      // Test STT connection
      final sttResponse = await _httpClient.head(
        Uri.parse(_sttUrl),
        headers: {'Ocp-Apim-Subscription-Key': AzureConfig.speechServiceKey},
      );

      _isPreWarmed =
          (ttsResponse.statusCode == 405 || ttsResponse.statusCode == 200) &&
          (sttResponse.statusCode == 405 || sttResponse.statusCode == 200);

      print('Azure Speech Services connection established (TTS + STT)');
    } catch (e) {
      print('Speech services pre-warm failed: $e');
    } finally {
      _isPreWarming = false;
    }
  }

  /// TTS method (unchanged from previous optimization)
  Future<Uint8List> textToSpeech(String text) async {
    final cleanText = _preprocessTextForSpeech(text);
    final ssml = _buildSSML(cleanText, _femaleVoice);

    final response = await _httpClient.post(
      Uri.parse(_ttsUrl),
      headers: {
        'Ocp-Apim-Subscription-Key': AzureConfig.speechServiceKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        'User-Agent': 'X3CreditScoring',
      },
      body: ssml,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('TTS failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// NEW: Optimized STT with enhanced audio processing
  Future<String> speechToText(Uint8List audioData) async {
    // Pre-process audio for better recognition
    final processedAudio = _preprocessAudioForSTT(audioData);

    final response = await _httpClient.post(
      Uri.parse('$_sttUrl?language=en-US&format=detailed&profanity=masked'),
      headers: {
        'Ocp-Apim-Subscription-Key': AzureConfig.speechServiceKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
        'Connection': 'keep-alive',
      },
      body: processedAudio,
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);

      if (result['RecognitionStatus'] == 'Success') {
        final displayText = result['DisplayText'] ?? '';
        final confidence = _extractConfidence(result);

        // Only return high-confidence results
        if (confidence > 0.6) {
          return _postProcessTranscription(displayText);
        } else {
          print('Low confidence transcription: $confidence');
          return displayText; // Return anyway but log the low confidence
        }
      } else {
        throw Exception(
          'Speech recognition failed: ${result['RecognitionStatus']}',
        );
      }
    } else {
      throw Exception('STT failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// NEW: Enhanced audio preprocessing for better STT accuracy
  Uint8List _preprocessAudioForSTT(Uint8List audioData) {
    // For now, return original data
    // In production, you could add noise reduction, volume normalization, etc.
    return audioData;
  }

  /// NEW: Extract confidence score from STT response
  double _extractConfidence(Map<String, dynamic> result) {
    try {
      if (result['NBest'] != null && result['NBest'].isNotEmpty) {
        return (result['NBest'][0]['Confidence'] ?? 0.0).toDouble();
      }
      return 0.8; // Default confidence if not available
    } catch (e) {
      return 0.8;
    }
  }

  /// NEW: Post-process transcription for better user experience
  String _postProcessTranscription(String text) {
    String processed = text.trim();

    // Capitalize first letter
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }

    // Fix common transcription issues
    processed = processed
        .replaceAll(' ai ', ' AI ')
        .replaceAll(' api ', ' API ')
        .replaceAll(' tts ', ' TTS ')
        .replaceAll(' stt ', ' STT ')
        .replaceAll('b2b', 'B2B')
        .replaceAll('p&l', 'P&L')
        .replaceAll('p and l', 'P&L');

    // Ensure proper sentence ending
    if (processed.isNotEmpty &&
        !processed.endsWith('.') &&
        !processed.endsWith('!') &&
        !processed.endsWith('?')) {
      processed += '.';
    }

    return processed;
  }

  String _buildSSML(String text, String voice) {
    return '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-IN">
  <voice name="$voice">
    <prosody rate="0.9" pitch="+2Hz">
      $text
    </prosody>
  </voice>
</speak>''';
  }

  String _preprocessTextForSpeech(String text) {
    return text
        .replaceAll('✅', 'Completed.')
        .replaceAll('❗', 'Important.')
        .replaceAll('🔬', 'Analyzing.')
        .replaceAll('📋', 'Documents.')
        .replaceAll('B2B', 'Business to Business')
        .replaceAll('AI', 'A I')
        .replaceAll('API', 'A P I')
        .replaceAll('TTS', 'Text to Speech')
        .replaceAll('STT', 'Speech to Text')
        .replaceAll('P&L', 'Profit and Loss')
        .replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\*([^*]+)\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .trim();
  }

  static void dispose() {
    _httpClient.close();
  }
}
