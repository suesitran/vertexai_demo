import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:vertexai_demo/utils/audio_input.dart';

class LiveChat extends StatefulWidget {
  const LiveChat({super.key});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  late final LiveSession _session;
  StreamSubscription<LiveServerResponse>? _responseSubscription;
  final ValueNotifier<bool> _isSessionConnected = ValueNotifier(false);
  final ValueNotifier<bool> _isAudioReady = ValueNotifier(false);

  final AudioInput _audioInput = AudioInput();

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

        _session.sendMediaStream(
          audioStream.map((bytes) => InlineDataPart('audio/pcm', bytes)),
        );
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
    _isAudioReady.value = await _audioInput.init();
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
          }
        }
      }
    }
  }

  @override
  void dispose() async {
    await _session.close();
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
          return Center(
            child: Column(
              children: [
                Text('Session connected'),
                ValueListenableBuilder(
                  valueListenable: _isAudioReady,
                  builder:
                      (context, value, child) =>
                          Text('Audio ${value ? 'ready' : 'not ready'}'),
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
