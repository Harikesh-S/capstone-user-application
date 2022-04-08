import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Socket _socket;
  List<int> _messageBuffer = [];
  List<int> _message = [];
  int _messageLength = -1;

  Uint8List _img1 = Uint8List(0);
  bool _imgAvail = false;

  final String _ip = '192.168.1.8';
  final List<int> aesKey = [
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112
  ];

  @override
  void initState() {
    super.initState();
    setupSocket();
  }

  void setupSocket() async {
    debugPrint("Connecting to IP : $_ip");
    _socket = await Socket.connect(_ip, 50001);
    _socket.listen(
      (List<int> event) {
        _messageBuffer += event;

        // Get message length if it is not set and is available in the buffer
        if (_messageLength == -1) {
          for (int i = 0; i < _messageBuffer.length; i++) {
            // ASCII value of | is 124
            if (_messageBuffer[i] == 124) {
              _messageLength =
                  int.parse(utf8.decode(_messageBuffer.sublist(0, i)));
              _messageBuffer.removeRange(0, i + 1);
              break;
            }
          }
        }

        // Get message if entire message is available
        if (_messageLength != -1) {
          if (_messageLength <= _messageBuffer.length) {
            _message = _messageBuffer.sublist(0, _messageLength);
            _messageBuffer.removeRange(0, _messageLength);
            _messageLength = -1;
            processCameraMessage();
          }
        }
      },
    );
  }

  void processCameraMessage() async {
    SecretKey secretKey = SecretKey(aesKey);

    List<int> iv = _message.sublist(0, 12);
    List<int> cipherText = _message.sublist(12, _message.length - 16);
    List<int> tag = _message.sublist(_message.length - 16);
    SecretBox secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));
    try {
      List<int> decrypted =
          await AesGcm.with128bits().decrypt(secretBox, secretKey: secretKey);
      _img1 = Uint8List.fromList(decrypted);
      _imgAvail = true;
      setState(() {});
    } on SecretBoxAuthenticationError {
      debugPrint("Authentication Error");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            child: (_imgAvail == true)
                ? Image.memory(
                    _img1,
                    gaplessPlayback: true,
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
