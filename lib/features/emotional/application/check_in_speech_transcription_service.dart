import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

final checkInSpeechTranscriptionServiceProvider =
    Provider<CheckInSpeechTranscriptionService>((ref) {
      return NativeCheckInSpeechTranscriptionService();
    });

abstract class CheckInSpeechTranscriptionService {
  bool get isListening;

  Future<bool> initialize({
    required String localeId,
    required void Function(String status) onStatus,
    required void Function(Object error) onError,
  });

  Future<void> listen({
    required String localeId,
    required void Function(String text) onResult,
  });

  Future<void> stop();

  Future<void> cancel();
}

class NativeCheckInSpeechTranscriptionService
    implements CheckInSpeechTranscriptionService {
  NativeCheckInSpeechTranscriptionService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  void Function(String status)? _onStatus;
  void Function(Object error)? _onError;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    required String localeId,
    required void Function(String status) onStatus,
    required void Function(Object error) onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    return _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
      finalTimeout: const Duration(seconds: 1),
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text) onResult,
  }) async {
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 40),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  void _handleStatus(String status) {
    _onStatus?.call(status);
  }

  void _handleError(SpeechRecognitionError error) {
    _onError?.call(error);
  }
}
