import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vertexai_demo/firebase_options.dart';
import 'package:vertexai_demo/functions.dart';

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
  final FunctionsHandler functionsHandler = FunctionsHandler();

  late final ChatSession chatSession =
      FirebaseAI.vertexAI()
          .generativeModel(
            model: 'gemini-2.0-flash',
            tools: [functionsHandler.functions],
        systemInstruction: Content.system('You are Ducky, a smart chatbot that can help user with anything he needs.')
          )
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

  Future<void> _sendToGemini(
    String text, {
    List<FunctionResponse>? functionResponses,
    Message? oldMessage,
    String response = '',
  }) async {
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

    oldMessage ??= Message.text(
      id: '${chatController.messages.length}',
      authorId: 'model',
      text: response,
    );
    // only create empty message if functionResponse is null
    if (functionResponses == null || functionResponses.isEmpty) {
      chatController.insertMessage(oldMessage);
    }

    final Content content = Content.multi([
      if (text.isNotEmpty) TextPart(text),
      if (attachment.value != null)
        InlineDataPart('image/*', await attachment.value!.readAsBytes()),
      if (functionResponses != null && functionResponses.isNotEmpty)
        ...functionResponses,
    ]);

    chatSession.sendMessageStream(content).listen((event) async {
      if (event.functionCalls.isNotEmpty) {
        List<FunctionResponse> functionResponses = await functionsHandler
            .handleFunctionCalls(event.functionCalls);

        _sendToGemini(
          text,
          functionResponses: functionResponses,
          oldMessage: oldMessage,
          response: response,
        );
        return;
      }

      response = '$response ${event.text ?? ''}'.trim();
      final newMessage = Message.text(
        id: oldMessage!.id,
        authorId: oldMessage!.authorId,
        text: response,
        sentAt: DateTime.now(),
      );
      chatController.updateMessage(oldMessage!, newMessage);
      oldMessage = newMessage;
    });

    // clear attachment
    attachment.value = null;
  }
}
