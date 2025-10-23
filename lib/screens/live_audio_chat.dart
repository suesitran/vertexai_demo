import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vertexai_demo/gen/assets.gen.dart';
import 'package:vertexai_demo/utils/audio_input.dart';
import 'package:vertexai_demo/utils/audio_output.dart';

class LiveAudioChat extends StatefulWidget {
  const LiveAudioChat({super.key});

  @override
  State<LiveAudioChat> createState() => _LiveAudioChatState();
}

class _LiveAudioChatState extends State<LiveAudioChat> {
  late final LiveSession _session;
  final ValueNotifier<bool> _isSessionConnected = ValueNotifier(false);
  final ValueNotifier<bool> _isAudioReady = ValueNotifier(false);

  final AudioInput _audioInput = AudioInput();
  final AudioOutput _audioOutput = AudioOutput();

  StreamSubscription<LiveServerResponse>? _responseSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;

  @override
  void initState() {
    super.initState();

    _isSessionConnected.addListener(_startCommunication);
    _isAudioReady.addListener(_startCommunication);

    _initSession();
    _initAudio();
  }

  void _startCommunication() async {
    final bool sessionReady = _isSessionConnected.value;
    final bool audioReady = _isAudioReady.value;

    if (sessionReady && audioReady) {
      // both ready, start sending audio stream
      final audioStream = await _audioInput.startRecording();

      _audioSubscription = audioStream.listen((bytes) {
        _session.sendAudioRealtime(InlineDataPart('audio/pcm', bytes));
      },);
    }
  }

  Future<void> _initSession() async {
    _session =
        await FirebaseAI.vertexAI()
            .liveGenerativeModel(
              model: 'gemini-2.0-flash-exp',
              liveGenerationConfig: LiveGenerationConfig(
                responseModalities: [ResponseModalities.audio],
              ),
            )
            .connect();

    _responseSubscription = _session.receive().listen(_handleSessionResponse);
  }

  Future<void> _initAudio() async {
    await _audioOutput.init();
    _isAudioReady.value = await _audioInput.init();

    await _audioOutput.playStream();
  }

  void _handleSessionResponse(LiveServerResponse response) {
    _isSessionConnected.value = true;

    final LiveServerMessage message = response.message;

    if (message is LiveServerContent) {
      final Content? content = message.modelTurn;

      if (content != null) {
        for (Part part in content.parts) {
          if (part is TextPart) {
            // handle text part
          } else if (part is InlineDataPart) {
            // handle inline data
            _audioOutput.addAudioDataStream(part.bytes);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _audioInput.stopRecording();
    _session.close();
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _isSessionConnected.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _isSessionConnected,
      builder: (context, connected, child) {
        if (connected) {
          // show a UI indicate that session is connected
          return Container(
            padding: EdgeInsets.all(20.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Session connected'),
                ValueListenableBuilder(
                  valueListenable: _isAudioReady,
                  builder:
                      (context, value, child) =>
                          Text('Audio ${value ? 'ready' : 'not ready'}'),
                ),
                Text(
                  'Source code available at \nhttps://github.com/suesitran/vertexai_demo',
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Assets.vertexAiDemo.image(),
                ),
                TextButton(
                  onPressed: () {
                    _audioInput.isPaused.then((pause) {
                      if (pause) {
                        _audioInput.resume();
                      } else {
                        _audioInput.pause();
                      }
                    });
                  },
                  child: ValueListenableBuilder<RecordingState>(
                    valueListenable: _audioInput.state,
                    builder: (context, state, child) {
                      final bool recording = state == RecordingState.recording;
                      String label = recording ? 'Pause audio' : 'Resume audio';

                      return Text(label);
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return Center(child: CircularProgressIndicator());
      },
    );
  }
}
