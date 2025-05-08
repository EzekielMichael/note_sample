import 'package:flutter_tts/flutter_tts.dart';

enum TtsLanguage { english, swahili }

class TextToSpeechServiceDb {
  final FlutterTts _tts = FlutterTts();
  TtsLanguage _currentLanguage = TtsLanguage.english;
  bool _isSpeaking = false;

  TextToSpeechServiceDb() {
    initialize();
  }

  /// Initializes the TTS engine with default settings
  Future<void> initialize() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS Error: $msg');
      });
    } catch (e) {
      print('Failed to initialize TTS: $e');
    }
  }

  /// Sets the language for speech synthesis
  Future<void> setLanguage(TtsLanguage language) async {
    try {
      _currentLanguage = language;
      await _tts.setLanguage(language == TtsLanguage.english ? "en-US" : "sw-TZ");
    } catch (e) {
      print('Failed to set language: $e');
    }
  }

  /// Speaks the given text and waits until completion
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.speak(text);
      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('Failed to speak: $e');
    }
  }

  /// Stops any ongoing speech
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Failed to stop TTS: $e');
    }
  }

  /// Toggles between English and Swahili
  Future<void> toggleLanguage() async {
    final newLanguage = _currentLanguage == TtsLanguage.english
        ? TtsLanguage.swahili
        : TtsLanguage.english;
    await setLanguage(newLanguage);
  }

  /// Returns the current language name
  String get currentLanguageName => _currentLanguage == TtsLanguage.english
      ? "English"
      : "Swahili";

  /// Returns the text for the language toggle button
  String get switchLanguageButtonText => _currentLanguage == TtsLanguage.english
      ? "Switch to Swahili"
      : "Switch to English";

  /// Checks if TTS is currently speaking
  bool get isSpeaking => _isSpeaking;
}