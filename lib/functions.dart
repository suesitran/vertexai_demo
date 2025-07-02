import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

enum FileType {
  picture,
  video,
  audio;

  String get extension => switch (this) {
    FileType.picture => 'png',
    FileType.video => 'mp4',
    FileType.audio => 'm4a',
  };
}

class FileGenerated {
  final String path;
  final FileType type;

  FileGenerated({required this.path, required this.type});
}

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
      'prompt': Schema.string(
        description:
            'user\'s prompt to create image. Translate all prompt to English',
      ),
    },
  );

  Future<List<FunctionResponse>> handleFunctionCalls(
    Iterable<FunctionCall> calls,
    ValueChanged<FileGenerated> onFileCreated,
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
          generationConfig: ImagenGenerationConfig(
            imageFormat: ImagenFormat.png(),
            aspectRatio: ImagenAspectRatio.square1x1,
            numberOfImages: 1,
          ),
        );
        final String prompt = call.args['prompt'] as String;

        final List<ImagenInlineImage> images =
            (await imagenModel.generateImages(prompt)).images;

        if (images.isNotEmpty) {
          final image = images.first;
          final File file = await createEmptyFile(FileType.picture);
          await file.writeAsBytes(image.bytesBase64Encoded);

          onFileCreated(FileGenerated(path: file.path, type: FileType.picture));
          responses.add(FunctionResponse(call.name, {'imagePath': file.path}));
        } else {
          responses.add(
            FunctionResponse(call.name, {'result': 'failed to generate image'}),
          );
        }
      }
    }
    return responses;
  }

  Future<File> createEmptyFile(FileType type) async {
    final Directory appCache = await getApplicationCacheDirectory();
    return File(
      '${appCache.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}.${type.extension}',
    );
  }
}
