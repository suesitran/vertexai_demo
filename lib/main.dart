import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vertexai_demo/firebase_options.dart';
import 'package:vertexai_demo/screens/generative_chat.dart';
import 'package:vertexai_demo/screens/live_chat.dart';
import 'package:vertexai_demo/screens/qr_code.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

enum Screens {
  generative,
  live,
  qrCode;

  String get title => switch (this) {
    Screens.generative => "Generative model demo",
    Screens.live => "Gemini LiveAPI demo",
    Screens.qrCode => 'Source code',
  };
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final ValueNotifier<Screens> _selectedScreen = ValueNotifier(
    Screens.generative,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: Text('Firebase AI Logic Demo'),
        actions: [
          Builder(
            builder: (context) {
              return IconButton.outlined(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder:
                        (context) => Center(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: Screens.values.length,
                            itemBuilder:
                                (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _selectedScreen.value =
                                          Screens.values[index];
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(Screens.values[index].title),
                                  ),
                                ),
                          ),
                        ),
                  );
                },
                icon: Icon(Icons.settings),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _selectedScreen,
        builder: (context, value, child) {
          return switch (value) {
            Screens.generative => GenerativeChat(),
            Screens.live => LiveChat(),
            Screens.qrCode => QrCode(),
          };
        },
      ),
    ),
  );

  @override
  void dispose() {
    _selectedScreen.dispose();
    super.dispose();
  }
}
