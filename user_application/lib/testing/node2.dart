import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class NodePage extends StatefulWidget {
  const NodePage({
    Key? key,
    required this.socket,
    required this.aesKey,
    required this.nodeID,
  }) : super(key: key);

  final Socket socket;
  final List<int> aesKey;
  final String nodeID;

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  String _receivedData = "";
  bool isListening = false;

  @override
  Widget build(BuildContext context) {
    if (!isListening) {
      widget.socket.listen(
        (List<int> event) async {
          SecretKey secretKey = SecretKey(widget.aesKey);

          List<int> iv = event.sublist(0, 12);
          List<int> cipherText = event.sublist(12, event.length - 16);
          List<int> tag = event.sublist(event.length - 16);
          SecretBox secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));
          try {
            List<int> decrypted = await AesGcm.with128bits()
                .decrypt(secretBox, secretKey: secretKey);
            String decoded = utf8.decode(decrypted);
            setState(
              () {
                _receivedData = decoded;
                debugPrint(_receivedData);
              },
            );
          } on SecretBoxAuthenticationError {
            debugPrint("Authentication Error");
          }
        },
      );
      isListening = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Connected to node " + widget.nodeID),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                final nonce = AesGcm.with128bits().newNonce();
                final secretKey = SecretKey(widget.aesKey);
                final secretBox = await AesGcm.with128bits().encrypt(
                  utf8.encode("Hello"),
                  secretKey: secretKey,
                  nonce: nonce,
                );
                widget.socket
                    .add(nonce + secretBox.cipherText + secretBox.mac.bytes);
              },
              child: const Text("Send data"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text("Received : "),
                Text(_receivedData),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Disconnect"),
            ),
          ],
        ),
      ),
    );
  }
}
