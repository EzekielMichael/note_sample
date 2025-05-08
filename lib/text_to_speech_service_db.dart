import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsLanguage { english, swahili }

class TextToSpeechServiceDb {
  final FlutterTts _tts = FlutterTts();
  TtsLanguage _currentLanguage = TtsLanguage.english;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  Timer? _debounceTimer;

  TextToSpeechServiceDb() {
    initialize().then((success) {
      if (!success) {
        print('TTS initialization failed. Prompt user to install TTS engine.');
      }
    });
  }

  /// Checks if a TTS engine is available
  Future<bool> isTtsAvailable() async {
    try {
      return await _tts.isLanguageAvailable("en-US");
    } catch (e) {
      print('TTS Availability Check Error: $e');
      return false;
    }
  }

  /// Checks if a language is supported
  Future<bool> isLanguageSupported(String languageCode) async {
    try {
      return await _tts.isLanguageAvailable(languageCode);
    } catch (e) {
      print('Language Support Check Error: $e');
      return false;
    }
  }

  /// Initializes the TTS engine with default settings
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (!await isTtsAvailable()) {
        print('TTS engine not available on this device');
        return false;
      }
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
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Failed to initialize TTS: $e');
      return false;
    }
  }

  /// Sets the language for speech synthesis
  Future<void> setLanguage(TtsLanguage language) async {
    try {
      final languageCode = language == TtsLanguage.english ? "en-US" : "sw-TZ";
      if (await isLanguageSupported(languageCode)) {
        _currentLanguage = language;
        await _tts.setLanguage(languageCode);
      } else if (language == TtsLanguage.swahili && await isLanguageSupported("sw-KE")) {
        _currentLanguage = language;
        await _tts.setLanguage("sw-KE");
      } else {
        print('Language $languageCode not supported. Falling back to en-US.');
        _currentLanguage = TtsLanguage.english;
        await _tts.setLanguage("en-US");
      }
    } catch (e) {
      print('Failed to set language: $e');
    }
  }

  /// Speaks the given text and waits until completion
  Future<void> speak(String text) async {
    if (text.trim().isEmpty || _isSpeaking) return;
    if (!_isInitialized) await initialize();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final completer = Completer<void>();
        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          completer.complete();
        });
        _tts.setErrorHandler((msg) {
          _isSpeaking = false;
          completer.completeError(Exception(msg));
        });
        await _tts.speak(text);
        await completer.future;
      } catch (e) {
        print('Failed to speak: $e');
        rethrow;
      }
    });
  }

  /// Stops any ongoing speech
  Future<void> stop() async {
    _debounceTimer?.cancel();
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