import 'package:flutter/material.dart';
import 'package:vertexai_demo/gen/assets.gen.dart';

class QrCode extends StatelessWidget {
  const QrCode({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Source code available at \nhttps://github.com/suesitran/vertexai_demo',
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Assets.vertexAiDemo.image(),
          ),
        ],
      ),
    );
  }
}
