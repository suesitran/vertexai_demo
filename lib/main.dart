import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vertexai_demo/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

            // _sendToGemini(text); // Removed AI call
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
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    kIsWeb
                        // Image does not support File on Web platform,
                        // therefore we use Image.network for web platform
                        ? Image.network(image.source, width: 300)
                        : Image.file(File(image.source), width: 300),
              );
            },
            composerBuilder: (p0) {
              return Composer(
                attachmentIcon: ValueListenableBuilder<XFile?>(
                  valueListenable: attachment,
                  builder: (context, value, child) {
                    final size = 30.0;
                    if (value == null) {
                      return Icon(Icons.attachment, size: size);
                    }

                    return kIsWeb
                        // Image does not support File on Web platform,
                        // therefore we use Image.network for web platform
                        ? Image.network(value.path, height: size)
                        : Image.file(File(value.path), height: size);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
