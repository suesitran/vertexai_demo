import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

final class AudioInput {
  final _recorder = AudioRecorder();
  final AudioEncoder _encoder = AudioEncoder.pcm16bits;

  Stream<Uint8List>? audioStream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> init() async {
    // check permission
    final permission = await _recorder.hasPermission();

    return permission;
  }

  Future<void> startRecording() async {
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
    audioStream = await _recorder.startStream(recordConfig);
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    await _recorder.stop();
  }
}