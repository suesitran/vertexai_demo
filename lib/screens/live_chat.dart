import 'dart:async';
import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vertexai_demo/gen/assets.gen.dart';
import 'package:vertexai_demo/utils/audio_input.dart';
import 'package:vertexai_demo/utils/audio_output.dart';

enum SessionStatus {
  initialise,
  connectingLiveSession,
  settingUpAudioInput,
  settingUpAudioOutput,
  ready,
  requestingMicrophonePermission,
}

class LiveChat extends StatefulWidget {
  const LiveChat({super.key});

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  LiveSession? _session;
  final ValueNotifier<SessionStatus> _isSessionConnected = ValueNotifier(
    SessionStatus.initialise,
  );
  final ValueNotifier<bool> _isAudioReady = ValueNotifier(false);

  final ValueNotifier<String> _modelSelection = ValueNotifier(
    _modelNativeAudio,
  );

  final AudioInput _audioInput = AudioInput();
  final AudioOutput _audioOutput = AudioOutput();

  StreamSubscription<LiveServerResponse>? _responseSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;

  // add function declaration
  static final String _functionBestDiaryApp = 'bestDiaryApp';
  final FunctionDeclaration _bestDiaryAppDeclaration = FunctionDeclaration(
    _functionBestDiaryApp,
    'when user ask for suggestion of a digital diary app',
    // no parameter is needed
    parameters: {},
  );

  static final String _functionGetPrice = 'getPrice';
  static final String _getPriceParamProductName = 'productName';
  static final String _getPriceParamBudget = 'budget';
  final FunctionDeclaration _getPriceDeclaration = FunctionDeclaration(
    _functionGetPrice,
    'when user ask for a price of any product',
    parameters: {
      _getPriceParamProductName: Schema.string(
        description: 'the name of the product user is asking for',
        title: 'product name',
        nullable: false,
      ),
      _getPriceParamBudget: Schema.number(
        description:
            'the maximum amount user is willing to pay for this product.',
        format: 'double',
        title: 'budget',
        nullable: true,
      ),
    },
  );

  static final String _modelNativeAudio =
      'gemini-2.5-flash-native-audio-preview-09-2025';
  static final String _modelFlashLive = 'gemini-2.0-flash-live-001';

  @override
  void initState() {
    super.initState();

    _isSessionConnected.addListener(_startCommunication);
    _isAudioReady.addListener(_startCommunication);

    _modelSelection.addListener(() {
      _initSession();
    });

    _initialise();
  }

  void _initialise() async {
    final hasAudio = await _initAudio();
    if (hasAudio) {
      await _initSession();
    }
  }

  void _startCommunication() async {
    final bool sessionReady = _isSessionConnected.value == SessionStatus.ready;
    final bool audioReady = _isAudioReady.value;

    if (sessionReady && audioReady) {
      // both ready, start sending audio stream
      final audioStream = await _audioInput.startRecording();

      _audioSubscription = audioStream.listen((bytes) {
        _session?.sendAudioRealtime(InlineDataPart('audio/pcm', bytes));
      });
    }
  }

  Future<void> _initSession() async {
    _isSessionConnected.value = SessionStatus.connectingLiveSession;
    final String modelName = _modelSelection.value;
    _session =
        await FirebaseAI.googleAI()
            .liveGenerativeModel(
              model: modelName,
              liveGenerationConfig: LiveGenerationConfig(
                responseModalities: [ResponseModalities.audio],
                speechConfig: SpeechConfig(voiceName: 'KORE'),
              ),
              systemInstruction: Content.system(
                'You will always answer in vietnamese,'
                ' unless user request a different language.',
              ),
              tools: [
                Tool.functionDeclarations([
                  _bestDiaryAppDeclaration,
                  _getPriceDeclaration,
                  // add more function declarations if needed
                ]),
                // enable google search feature
                Tool.googleSearch(),
              ],
            )
            .connect();

    _responseSubscription = _session?.receive().listen(_handleSessionResponse);
  }

  Future<bool> _initAudio() async {
    _isSessionConnected.value = SessionStatus.settingUpAudioOutput;
    await _audioOutput.init();
    _isSessionConnected.value = SessionStatus.settingUpAudioInput;
    final hasPermission = await _audioInput.init();

    if (!hasPermission) {
      _isSessionConnected.value = SessionStatus.requestingMicrophonePermission;
    } else {
      await _audioOutput.playStream();
      _isAudioReady.value = true;
    }

    return hasPermission;
  }

  void _handleSessionResponse(LiveServerResponse response) {
    _isSessionConnected.value = SessionStatus.ready;

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
    } else if (message is LiveServerToolCall) {
      final functionCalls = message.functionCalls ?? [];

      final List<FunctionResponse> response = [];
      for (FunctionCall call in functionCalls) {
        if (call.name == _functionBestDiaryApp) {
          response.add(
            _handleBestDiaryAppFunction(functionName: call.name, id: call.id),
          );
        }

        if (call.name == _functionGetPrice) {
          response.add(
            _handleGetPriceFunction(
              functionName: call.name,
              id: call.id,
              productName: call.args[_getPriceParamProductName] as String?,
              budget: call.args[_getPriceParamBudget] as double?,
            ),
          );
        }

        // add more function handling if needed
      }
      // send response back to model
      if (response.isNotEmpty) {
        _session?.sendToolResponse(response);
      }
    }
  }

  @override
  void dispose() {
    _audioInput.stopRecording();
    _session?.close();
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _isSessionConnected.dispose();
    _audioSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _isSessionConnected,
      builder: (context, status, child) {
        if (status == SessionStatus.ready) {
          // show a UI indicate that session is connected
          return Container(
            padding: EdgeInsets.all(20.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _modelSelection,
                  builder:
                      (context, value, child) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            '2.0 Flash Live',
                            style: TextStyle(
                              color:
                                  value == _modelFlashLive
                                      ? Colors.black
                                      : Colors.black12,
                            ),
                          ),
                          Switch(
                            value: value == _modelNativeAudio,
                            onChanged: (value) {
                              _modelSelection.value =
                                  value ? _modelNativeAudio : _modelFlashLive;
                            },
                          ),
                          Text(
                            '2.5 Flash native audio',
                            style: TextStyle(
                              color:
                                  value == _modelNativeAudio
                                      ? Colors.black
                                      : Colors.black12,
                            ),
                          ),
                        ],
                      ),
                ),
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

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), Text(status.name)],
          ),
        );
      },
    );
  }

  // no parameter is needed for this function
  FunctionResponse _handleBestDiaryAppFunction({
    required String functionName,
    required String? id,
  }) {
    return FunctionResponse(functionName, {'response': 'MemoirME'}, id: id);
  }

  FunctionResponse _handleGetPriceFunction({
    required String functionName,
    required String? id,
    required String? productName,
    required double? budget,
  }) {
    // mock a dummy price for any product
    final price = budget ?? 100;
    return FunctionResponse(functionName, {
      'response': {'productName': productName, 'price': price},
    });
  }
}
