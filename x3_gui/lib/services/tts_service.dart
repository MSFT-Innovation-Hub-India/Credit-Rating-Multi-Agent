import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:collection';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show VoidCallback;
import 'package:path_provider/path_provider.dart';
import 'package:x3_gui/services/azure_speech_service.dart';

class TTSService {
  final AzureSpeechService _azureSpeechService = AzureSpeechService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  VoidCallback? _onCompleted;
  VoidCallback? _onStarted;
  VoidCallback? _onAudioPlaying;
  VoidCallback? _onAudioPaused;

  // Streaming variables
  bool _isStreaming = false;
  final Queue<String> _audioFileQueue = Queue<String>();
  bool _isPlayingQueue = false;
  bool _hasStartedSpeaking = false;
  bool _isActuallyPlaying = false;

  // NEW: Track if we're in a user-initiated stop vs automatic transition
  bool _isUserStop = false;
  bool _isTransitioning = false; // NEW: Flag for sentence transitions

  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await AzureSpeechService.preWarmConnection();

      // Set up audio player state listeners
      _audioPlayer.onPlayerComplete.listen((_) {
        _onAudioComplete();
      });

      // FIXED: Only trigger state changes for user actions, not transitions
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        final wasPlaying = _isActuallyPlaying;
        _isActuallyPlaying = state == PlayerState.playing;

        // FIXED: Ignore state changes during sentence transitions
        if (_isTransitioning) return;

        if (_isActuallyPlaying && !wasPlaying && !_isUserStop) {
          // Audio started playing (and it wasn't a user stop)
          if (_onAudioPlaying != null) _onAudioPlaying!();
        } else if (!_isActuallyPlaying && wasPlaying && _isUserStop) {
          // Audio stopped due to user action
          if (_onAudioPaused != null) _onAudioPaused!();
          _isUserStop = false; // Reset the flag
        }
      });

      _isInitialized = true;
      print('TTS Service initialized successfully');
    } catch (e) {
      print('Error initializing TTS: $e');
      throw Exception('Failed to initialize TTS service: $e');
    }
  }

  void setCompletionHandler(VoidCallback onCompleted) {
    _onCompleted = onCompleted;
  }

  void setStartedHandler(VoidCallback onStarted) {
    _onStarted = onStarted;
  }

  void setAudioPlayingHandler(VoidCallback onAudioPlaying) {
    _onAudioPlaying = onAudioPlaying;
  }

  void setAudioPausedHandler(VoidCallback onAudioPaused) {
    _onAudioPaused = onAudioPaused;
  }

  bool get isActuallyPlaying => _isActuallyPlaying;

  /// Enhanced speak method with proper state signaling
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();

    await stop();
    _hasStartedSpeaking = false;
    _isUserStop = false; // Reset user stop flag

    final processedText = _preprocessTextForNaturalSpeech(text);

    try {
      if (processedText.length <= 200) {
        await _speakImmediately(processedText);
      } else {
        await _speakWithStreaming(processedText);
      }
    } catch (e) {
      print('TTS failed: $e');
      if (_onCompleted != null) {
        _onCompleted!();
      }
    }
  }

  /// Immediate TTS for short text
  Future<void> _speakImmediately(String text) async {
    final audioData = await _azureSpeechService.textToSpeech(text);

    if (_onStarted != null && !_hasStartedSpeaking) {
      _hasStartedSpeaking = true;
      _onStarted!();
    }

    await _playAudioData(audioData);
  }

  /// Streaming TTS with proper state management
  Future<void> _speakWithStreaming(String text) async {
    _isStreaming = true;
    _audioFileQueue.clear();

    final sentences = _splitIntoSentences(text);

    if (sentences.isEmpty) {
      if (_onCompleted != null) _onCompleted!();
      return;
    }

    for (int i = 0; i < sentences.length; i++) {
      if (!_isStreaming) break;

      final sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;

      try {
        final audioData = await _azureSpeechService.textToSpeech(sentence);
        final audioPath = await _saveAudioToFile(audioData);

        _audioFileQueue.add(audioPath);

        if (i == 0 && !_isPlayingQueue) {
          if (_onStarted != null && !_hasStartedSpeaking) {
            _hasStartedSpeaking = true;
            _onStarted!();
          }
          _playNextFromQueue();
        }
      } catch (e) {
        print('Failed to generate TTS for sentence: $e');
        continue;
      }
    }

    if (_audioFileQueue.isEmpty) {
      _isStreaming = false;
      if (_onCompleted != null) _onCompleted!();
    }
  }

  /// Split text into sentences intelligently
  List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final parts = text.split(RegExp(r'[.!?]+(?=\s+[A-Z]|$)'));

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isNotEmpty) {
        if (i < parts.length - 1) {
          sentences.add('$part.');
        } else {
          if (!part.endsWith('.') &&
              !part.endsWith('!') &&
              !part.endsWith('?')) {
            sentences.add('$part.');
          } else {
            sentences.add(part);
          }
        }
      }
    }

    if (sentences.length <= 1 && text.length > 200) {
      return _splitByLength(text, 150);
    }

    return sentences;
  }

  /// Split long text by length for streaming
  List<String> _splitByLength(String text, int maxLength) {
    final chunks = <String>[];
    final words = text.split(' ');
    String currentChunk = '';

    for (final word in words) {
      if (currentChunk.length + word.length + 1 <= maxLength) {
        currentChunk += (currentChunk.isEmpty ? '' : ' ') + word;
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
        }
        currentChunk = word;
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// Save audio data to temporary file
  Future<String> _saveAudioToFile(Uint8List audioData) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/tts_${timestamp}.mp3');

    await tempFile.writeAsBytes(audioData);

    Timer(Duration(minutes: 5), () {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    return tempFile.path;
  }

  /// FIXED: Play next audio file with transition handling
  void _playNextFromQueue() {
    if (_audioFileQueue.isEmpty) {
      _isPlayingQueue = false;
      if (!_isStreaming) {
        if (_onCompleted != null) _onCompleted!();
      }
      return;
    }

    _isPlayingQueue = true;
    final audioPath = _audioFileQueue.removeFirst();

    // FIXED: Mark as transitioning to ignore state changes
    _isTransitioning = true;

    _audioPlayer
        .play(DeviceFileSource(audioPath))
        .then((_) {
          // FIXED: Small delay then clear transition flag
          Timer(Duration(milliseconds: 100), () {
            _isTransitioning = false;
          });
        })
        .catchError((e) {
          print('Failed to play audio: $e');
          _isTransitioning = false; // Clear flag on error too
          Timer(Duration(milliseconds: 50), () {
            _playNextFromQueue();
          });
        });
  }

  /// FIXED: Handle audio completion without triggering pause state
  void _onAudioComplete() {
    if (_isStreaming && _audioFileQueue.isNotEmpty) {
      // FIXED: Mark as transitioning during sentence changes
      _isTransitioning = true;
      Timer(Duration(milliseconds: 50), () {
        _playNextFromQueue();
      });
    } else {
      // All streaming complete
      _isPlayingQueue = false;
      _isStreaming = false;
      _hasStartedSpeaking = false;
      _isTransitioning = false;
      if (_onCompleted != null) {
        _onCompleted!();
      }
    }
  }

  /// Play audio data immediately (for short text)
  Future<void> _playAudioData(Uint8List audioData) async {
    final audioPath = await _saveAudioToFile(audioData);
    await _audioPlayer.play(DeviceFileSource(audioPath));
  }

  /// FIXED: Stop method marks as user-initiated
  Future<void> stop() async {
    _isUserStop = true; // FIXED: Mark this as a user stop
    _isStreaming = false;
    _isPlayingQueue = false;
    _hasStartedSpeaking = false;
    _isTransitioning = false;

    await _audioPlayer.stop();

    // Clear queue and cleanup files
    while (_audioFileQueue.isNotEmpty) {
      final audioPath = _audioFileQueue.removeFirst();
      final file = File(audioPath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }

    if (_onCompleted != null) {
      _onCompleted!();
    }
  }

  String _preprocessTextForNaturalSpeech(String text) {
    String processed = text;
    processed = processed.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    processed = processed.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    processed = processed.replaceAll(RegExp(r'#{1,6}\s*'), '');
    processed = processed.replaceAll('✅', 'Completed.');
    processed = processed.replaceAll('❗', 'Important.');
    processed = processed.replaceAll('P&L', 'Profit and Loss');
    processed = processed.replaceAll('B2B', 'Business to Business');
    processed = processed.replaceAll('AI', 'A I');
    return processed.trim();
  }

  void dispose() {
    _audioPlayer.dispose();
    AzureSpeechService.dispose();
  }
}
