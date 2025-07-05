import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

enum RecordingState {
  uninitialised,
  initialised,
  recording,
  paused,
  stopped,
}
final class AudioInput {
  final _recorder = AudioRecorder();
  final AudioEncoder _encoder = AudioEncoder.pcm16bits;

  Stream<Uint8List>? audioStream;
  final ValueNotifier<RecordingState> state = ValueNotifier(RecordingState.uninitialised);

  Future<bool> init() async {
    // check permission
    final permission = await _recorder.hasPermission();

    return permission;
  }

  Future<Stream<Uint8List>> startRecording() async {
    var recordConfig = RecordConfig(
      encoder: _encoder,
      sampleRate: 24000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
      iosConfig: const IosRecordConfig(categoryOptions: []),
    );
    await _recorder.listInputDevices();
    final stream = await _recorder.startStream(recordConfig);
    state.value = RecordingState.recording;
    audioStream = stream;

    return stream;
  }

  Future<void> stopRecording() async {
    await _recorder.stop();
    state.value = RecordingState.stopped;
  }

  Future<void> pause() async {
    await _recorder.pause();
    state.value = RecordingState.paused;
  }

  Future<void> resume() async {
    await _recorder.resume();
    state.value = RecordingState.recording;
  }

  Future<bool> get isPaused => _recorder.isPaused();
}
