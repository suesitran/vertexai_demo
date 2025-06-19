import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

class LiveChat extends StatefulWidget {
  const LiveChat({super.key});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  late final LiveSession _session;
  StreamSubscription<LiveServerResponse>? _responseSubscription;
  ValueNotifier<bool> _isSessionConnected = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _initSession();
  }

  Future<void> _initSession() async {
    _session = await FirebaseAI.vertexAI().liveGenerativeModel(model: 'gemini-2.0-flash-exp', liveGenerationConfig: LiveGenerationConfig(
      responseModalities: [ResponseModalities.audio],
    )).connect();

    _responseSubscription = _session.receive().listen(_handleSessionResponse);
  }

  void _handleSessionResponse(LiveServerResponse response) {
    _isSessionConnected.value = true;

    print('SUESI - response ${response.message.runtimeType}');
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
    return ValueListenableBuilder(valueListenable: _isSessionConnected, builder: (context, connected, child) {
      if (connected) {
        // show a UI indicate that session is connected
        return Center(
          child: Text('Session connected'),
        );
      }

      return Placeholder();
    },);
  }
}
