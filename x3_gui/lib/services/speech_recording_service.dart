import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x3_gui/services/azure_speech_service.dart';

class SpeechRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final AzureSpeechService _speechService = AzureSpeechService();

  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentRecordingPath;

  // NEW: Real-time transcription state
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;

  // NEW: Callbacks for real-time feedback
  VoidCallback? _onRecordingStarted;
  VoidCallback? _onRecordingStopped;
  Function(String)? _onTranscriptionReceived;
  Function(String)? _onRecordingError;

  static final SpeechRecordingService _instance =
      SpeechRecordingService._internal();
  factory SpeechRecordingService() => _instance;
  SpeechRecordingService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check and request permissions
      if (await _recorder.hasPermission()) {
        _isInitialized = true;
        print('Speech recording service initialized');
      } else {
        throw Exception('Microphone permission denied');
      }
    } catch (e) {
      print('Failed to initialize speech recording: $e');
      throw Exception('Failed to initialize speech recording: $e');
    }
  }

  // NEW: Set callbacks for real-time feedback
  void setCallbacks({
    VoidCallback? onRecordingStarted,
    VoidCallback? onRecordingStopped,
    Function(String)? onTranscriptionReceived,
    Function(String)? onRecordingError,
  }) {
    _onRecordingStarted = onRecordingStarted;
    _onRecordingStopped = onRecordingStopped;
    _onTranscriptionReceived = onTranscriptionReceived;
    _onRecordingError = onRecordingError;
  }

  /// NEW: Enhanced start recording with real-time feedback
  Future<void> startRecording() async {
    if (!_isInitialized) await initialize();

    if (_isRecording) {
      print('Already recording');
      return;
    }

    try {
      // Get temporary directory for audio file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.wav';

      // Start recording with optimized settings
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // Optimal for Azure Speech
          bitRate: 16000,
          numChannels: 1, // Mono
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Start recording timer for real-time feedback
      _startRecordingTimer();

      if (_onRecordingStarted != null) {
        _onRecordingStarted!();
      }

      print('Recording started: $_currentRecordingPath');
    } catch (e) {
      print('Failed to start recording: $e');
      if (_onRecordingError != null) {
        _onRecordingError!('Failed to start recording: $e');
      }
      throw Exception('Failed to start recording: $e');
    }
  }

  /// NEW: Start timer for recording feedback
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      // Could add real-time audio level feedback here
      // For now, just ensure we're still recording
      _checkRecordingStatus();
    });
  }

  /// NEW: Check recording status
  void _checkRecordingStatus() async {
    try {
      final isRecording = await _recorder.isRecording();
      if (!isRecording && _isRecording) {
        // Recording stopped unexpectedly
        print('Recording stopped unexpectedly');
        await stopRecording();
      }
    } catch (e) {
      print('Error checking recording status: $e');
    }
  }

  /// NEW: Enhanced stop recording with immediate transcription
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      print('Not currently recording');
      return null;
    }

    try {
      // Stop the timer
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // Stop recording
      final recordingPath = await _recorder.stop();
      _isRecording = false;

      if (_onRecordingStopped != null) {
        _onRecordingStopped!();
      }

      if (recordingPath == null || !File(recordingPath).existsSync()) {
        throw Exception('Recording file not found');
      }

      // Calculate recording duration
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      print('Recording stopped. Duration: ${duration}ms, File: $recordingPath');

      // Check minimum recording duration
      if (duration < 500) {
        throw Exception('Recording too short (minimum 500ms required)');
      }

      // Read audio file and transcribe
      final audioFile = File(recordingPath);
      final audioBytes = await audioFile.readAsBytes();

      print('Audio file size: ${audioBytes.length} bytes');

      // Transcribe immediately
      final transcription = await _speechService.speechToText(audioBytes);

      if (_onTranscriptionReceived != null && transcription.isNotEmpty) {
        _onTranscriptionReceived!(transcription);
      }

      // Clean up the temporary file
      _cleanupRecordingFile(recordingPath);

      return transcription;
    } catch (e) {
      print('Failed to stop recording or transcribe: $e');
      if (_onRecordingError != null) {
        _onRecordingError!('Transcription failed: $e');
      }

      // Clean up on error
      if (_currentRecordingPath != null) {
        _cleanupRecordingFile(_currentRecordingPath!);
      }

      _isRecording = false;
      return null;
    } finally {
      _recordingStartTime = null;
      _currentRecordingPath = null;
    }
  }

  /// NEW: Cancel recording without transcription
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      await _recorder.stop();
      _isRecording = false;

      if (_currentRecordingPath != null) {
        _cleanupRecordingFile(_currentRecordingPath!);
      }

      if (_onRecordingStopped != null) {
        _onRecordingStopped!();
      }

      print('Recording cancelled');
    } catch (e) {
      print('Error cancelling recording: $e');
    } finally {
      _recordingStartTime = null;
      _currentRecordingPath = null;
    }
  }

  /// Clean up temporary recording files
  void _cleanupRecordingFile(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        print('Cleaned up recording file: $filePath');
      }
    } catch (e) {
      print('Failed to clean up recording file: $e');
    }
  }

  /// NEW: Get recording duration in real-time
  Duration? get currentRecordingDuration {
    if (_recordingStartTime == null || !_isRecording) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    if (_currentRecordingPath != null) {
      _cleanupRecordingFile(_currentRecordingPath!);
    }
  }
}
