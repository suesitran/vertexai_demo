import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
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

  final ValueNotifier<XFile?> attachment = ValueNotifier(null);

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
                sentAt: DateTime.now(),
              ),
            );

            _sendToGemini(text);
          },
          onAttachmentTap: () {
            // add attachment to chat message
            ImagePicker().pickImage(source: ImageSource.gallery).then((value) {
              if (value != null) {
                attachment.value = value;
              }
            });
          },
          builders: Builders(
            imageMessageBuilder: (context, image, index) {
              return kIsWeb
                  // Image does not support File on Web platform,
                  // therefore we use Image.network for web platform
                  ? Image.network(image.source, width: 300)
                  : Image.file(File(image.source), width: 300);
            },
            composerBuilder: (p0) {
              return Composer(
                attachmentIcon: ValueListenableBuilder<XFile?>(
                  valueListenable: attachment,
                  builder: (context, value, child) {
                    if (value == null) return const Icon(Icons.attachment);

                    return kIsWeb
                        // Image does not support File on Web platform,
                        // therefore we use Image.network for web platform
                        ? Image.network(value.path, height: 100)
                        : Image.file(File(value.path), height: 100);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendToGemini(String text) async {
    if (text.isEmpty && attachment.value == null) {
      // nothing to send
      return;
    }

    if (attachment.value != null) {
      chatController.insertMessage(
        Message.image(
          id: '${chatController.messages.length}',
          authorId: 'user',
          source: attachment.value!.path,
        ),
      );
    }

    final String id = '${chatController.messages.length}';
    String response = '';
    Message oldMessage = Message.text(
      id: id,
      authorId: 'model',
      text: response,
    );
    chatController.insertMessage(oldMessage);

    final Content content = Content('user', [
      if (text.isNotEmpty) TextPart(text),
      if (attachment.value != null)
        InlineDataPart('image/*', await attachment.value!.readAsBytes()),
    ]);

    chatSession
        .sendMessageStream(content)
        .listen(
          (event) {
            response = '$response ${event.text ?? ''}';
            final newMessage = Message.text(
              id: id,
              authorId: 'model',
              text: response,
            );
            chatController.updateMessage(oldMessage, newMessage);
            oldMessage = newMessage;
          },
          onDone: () {
            final newMessage = Message.text(
              id: oldMessage.id,
              authorId: oldMessage.authorId,
              text: response,
              sentAt: DateTime.now(),
            );
            chatController.updateMessage(oldMessage, newMessage);
          },
        );

    // clear attachment
    attachment.value = null;
  }
}
