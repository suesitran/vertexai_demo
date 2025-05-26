import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:path_provider/path_provider.dart';

class FunctionsHandler {
  Tool get functions =>
      Tool.functionDeclarations([_getMyName, _getDateTime, _generateImage]);

  final FunctionDeclaration _getMyName = FunctionDeclaration(
    '_getMyName',
    'When user ask questions "what is your name", then check this function to get answer',
    parameters: {},
  );

  final FunctionDeclaration _getDateTime = FunctionDeclaration(
    '_getDateTime',
    'when need to check current device\'s date time, then check this function to get answer',
    parameters: {},
  );

  final FunctionDeclaration _generateImage = FunctionDeclaration(
    '_generateImage',
    'when user request to generate image, call this function and pass in user\'s prompt to create an image',
    parameters: {
      'prompt': Schema.string(description: 'user\'s prompt to create image'),
    },
  );

  Future<List<FunctionResponse>> handleFunctionCalls(
    Iterable<FunctionCall> calls,
    ValueChanged<String> onFileCreated,
  ) async {
    final List<FunctionResponse> responses = [];
    for (FunctionCall call in calls) {
      if (call.name == _getMyName.name) {
        responses.add(FunctionResponse(call.name, {'name': 'Ducky'}));
      }

      if (call.name == _getDateTime.name) {
        responses.add(
          FunctionResponse(call.name, {'dateTime': DateTime.now().toString()}),
        );
      }

      if (call.name == _generateImage.name) {
        // invoke
        final ImagenModel imagenModel = FirebaseAI.vertexAI().imagenModel(
          model: 'imagen-3.0-generate-002',
        );
        final String prompt = call.args['prompt'] as String;

        final ImagenInlineImage image =
            (await imagenModel.generateImages(prompt)).images.first;
        final Directory appCache = await getApplicationCacheDirectory();
        final File file = File(
          '${appCache.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(image.bytesBase64Encoded);

        onFileCreated(file.path);
        responses.add(FunctionResponse(call.name, {'imagePath': file.path}));
      }
    }
    return responses;
  }
}
