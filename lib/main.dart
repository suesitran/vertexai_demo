import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:vertexai_demo/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final InMemoryChatController chatController = InMemoryChatController();

  final ChatSession chatSession =
      FirebaseVertexAI.instance
          .generativeModel(model: 'gemini-2.0-flash')
          .startChat();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Vertex AI in Firebase')),
        body: Chat(
          currentUserId: 'user',
          resolveUser: (id) => Future.value(User(id: id, name: 'User')),
          chatController: chatController,
          onMessageSend: (text) {
            // send message to Gemini
            chatController.insertMessage(
              Message.text(
                id: '${chatController.messages.length}',
                authorId: 'user',
                text: text,
              ),
            );

            _sendToGemini(text);
          },
          onAttachmentTap: () {
            // add attachment to chat message
          },
        ),
      ),
    );
  }

  Future<void> _sendToGemini(String text) async {
    final String id = '${chatController.messages.length}';
    String response = '';
    Message oldMessage = Message.text(
      id: id,
      authorId: 'model',
      text: response,
    );
    chatController.insertMessage(oldMessage);
    chatSession.sendMessageStream(Content.text(text)).listen((event) {
      response = '$response ${event.text ?? ''}';
      final newMessage = Message.text(
        id: id,
        authorId: 'model',
        text: response,
      );
      chatController.updateMessage(oldMessage, newMessage);
      oldMessage = newMessage;
    });
  }
}
