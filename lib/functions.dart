import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:path_provider/path_provider.dart';

class FunctionsHandler {
  Tool get functions =>
      Tool.functionDeclarations([_getMyName, _getDateTime]);

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
    }
    return responses;
  }
}
