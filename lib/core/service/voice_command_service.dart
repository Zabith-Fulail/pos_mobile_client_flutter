import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCommandService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (e) => print('Speech error: $e'),
      onStatus: (s) => print('Speech status: $s'),
    );
    return _available;
  }

  bool get isListening => _speech.isListening;

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
      ),

    );
  }

  Future<void> stop() async => _speech.stop();
  Future<void> cancel() async => _speech.cancel();
}