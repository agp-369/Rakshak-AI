import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceLanguage { english, hindi }

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  stt.SpeechToText? _speech;
  FlutterTts? _tts;
  bool _speechInitialized = false;
  bool _ttsInitialized = false;
  VoiceLanguage _language = VoiceLanguage.english;

  bool get isSpeechInitialized => _speechInitialized;
  bool get isTtsInitialized => _ttsInitialized;
  bool get isListening => _speech?.isListening ?? false;
  VoiceLanguage get language => _language;

  String get _sttLocale {
    switch (_language) {
      case VoiceLanguage.hindi: return 'hi_IN';
      case VoiceLanguage.english: return 'en_US';
    }
  }

  String get _ttsLanguage {
    switch (_language) {
      case VoiceLanguage.hindi: return 'hi-IN';
      case VoiceLanguage.english: return 'en-US';
    }
  }

  Future<bool> initialize() async {
    try {
      _speech = stt.SpeechToText();
      _speechInitialized = await _speech!.initialize();
    } catch (e) {
      debugPrint('[!] STT init failed: $e');
    }

    try {
      _tts = FlutterTts();
      await _tts!.setLanguage(_ttsLanguage);
      await _tts!.setSpeechRate(0.45);
      await _tts!.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[!] TTS init failed: $e');
    }

    return _speechInitialized || _ttsInitialized;
  }

  void setLanguage(VoiceLanguage lang) {
    _language = lang;
    if (_ttsInitialized) {
      _tts?.setLanguage(_ttsLanguage);
    }
  }

  Future<bool> startListening({
    required ValueChanged<String> onResult,
    VoidCallback? onError,
  }) async {
    if (!_speechInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError?.call();
        return false;
      }
    }

    try {
      await _speech!.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: _sttLocale,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
        onSoundLevelChange: (level) {},
      );
      return true;
    } catch (e) {
      debugPrint('[!] STT listen error: $e');
      onError?.call();
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech?.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    try {
      await _speech?.cancel();
    } catch (_) {}
  }

  Future<bool> speak(String text) async {
    if (!_ttsInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      await _tts?.awaitSpeakCompletion(true);
      await _tts?.speak(text);
      return true;
    } catch (e) {
      debugPrint('[!] TTS speak error: $e');
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  void dispose() {
    _speech?.cancel();
    _tts?.stop();
  }
}
