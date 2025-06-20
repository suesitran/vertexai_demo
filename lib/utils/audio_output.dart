import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioOutput {
  AudioSource? stream;
  SoundHandle? handle;

  Future<void> init() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init(sampleRate: 24000, channels: Channels.quad);
    }

    if (SoLoud.instance.isInitialized) {
      // SoLoud is initialised successfully
      // stop any current stream, if there is
      await stopStream();

      // create new stream
      stream = SoLoud.instance.setBufferStream(
        maxBufferSizeBytes: 1024 * 1024 * 10, // 10MB
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0,
        onBuffering: (isBuffering, handle, time) {
          // do nothing
        },
      );
      // reset handle, to be used when stream starts
      handle = null;
    }
  }

  Future<AudioSource?> playStream() async {
    if (stream != null) {
      // play new stream
      handle = await SoLoud.instance.play(stream!);
    }
    // TODO what if stream is null?
    return stream;
  }

  Future<void> stopStream() async {
    if (stream != null &&
        handle != null &&
        SoLoud.instance.getIsValidVoiceHandle(handle!)) {
      SoLoud.instance.setDataIsEnded(stream!);
      await SoLoud.instance.stop(handle!);

      // reinit and ready to start new stream
      await init();
    }
  }

  void addAudioDataStream(Uint8List audioChunk) {
    try {
      SoLoud.instance.addAudioDataStream(stream!, audioChunk);
    } catch (e, stack) {
      debugPrintStack(stackTrace: stack, label: e.toString());
    }
  }
}
