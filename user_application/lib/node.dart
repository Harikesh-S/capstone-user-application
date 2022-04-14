import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
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
  final TextStyle _error = TextStyle(color: Colors.red.shade700);
  final TextEditingController _setValueTextFieldController =
      TextEditingController();

  bool _waitingForStructure = true;
  dynamic _structure;

  // Buffers used when receiving larger messages from camera nodes
  List<int> _messageBuffer = [];
  List<int> _message = [];
  int _messageLength = -1;

  @override
  void initState() {
    super.initState();

    widget.socket.listen(
      (List<int> event) async {
        if (_waitingForStructure) {
          try {
            SecretKey secretKey = SecretKey(widget.aesKey);

            List<int> iv = event.sublist(0, 12);
            List<int> cipherText = event.sublist(12, event.length - 16);
            List<int> tag = event.sublist(event.length - 16);
            SecretBox secretBox =
                SecretBox(cipherText, nonce: iv, mac: Mac(tag));

            List<int> decrypted = await AesGcm.with128bits()
                .decrypt(secretBox, secretKey: secretKey);
            String decoded = utf8.decode(decrypted);
            setState(() {
              _waitingForStructure = false;
              try {
                _structure = jsonDecode(decoded);
                if (_structure["type"] == "camera") {
                  _structure["imgAvail"] = false;
                }
              } on FormatException catch (e) {
                debugPrint("$e");
                _structure = null;
              }
            });
          } on SecretBoxAuthenticationError {
            debugPrint("Authentication Error");
          }
        } else {
          processMessage(event);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connected to node " + widget.nodeID),
      ),
      body: Padding(
        padding: EdgeInsets.all(2.w > 2.h ? 2.w : 2.h),
        child: Center(
          child: ListView(
            children: <Widget>[
              if (_structure == null) ...[
                if (_waitingForStructure == true)
                  const Text("Loading...")
                else
                  Text("Error getting data from node!", style: _error)
              ] else ...[
                if (_structure["type"] == "gateway") ...[
                  generateGatewayOptions(context),
                  SizedBox(height: 6.sp),
                  Container(
                    color: const Color.fromARGB(255, 60, 60, 60),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(5),
                          child: Text("BLE nodes"),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w > 2.h ? 1.w : 1.h),
                          child: Column(
                            children: [
                              for (var node in _structure["nodes"].keys)
                                generateNode(context, node),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_structure["type"] == "camera") ...[
                  (_structure["imgAvail"] == true)
                      ? Column(children: [
                          Image.memory(
                            _structure["img"],
                            gaplessPlayback: true,
                          )
                        ])
                      : Column(children: const [CircularProgressIndicator()]),
                  SizedBox(
                    height: 4.sp,
                  ),
                  generateCameraNodeInputs(context),
                ] else ...[
                  Text("Invalid node type!", style: _error)
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }

  Column generateCameraNodeInputs(BuildContext context) {
    var inputTags = _structure["input-tags"];
    var inputValues = _structure["input-values"];

    if (inputTags.length == 0) {
      return Column();
    }

    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Input",
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          SizedBox(
            width: 10.sp,
          ),
        ],
      ),
      for (var i = 0; i < inputTags.length; i++)
        Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(inputTags[i]),
            Row(children: [
              Text(inputValues[i]),
              SizedBox(width: 10.sp),
              ElevatedButton(
                  onPressed: () {
                    _setValueTextFieldController.clear();
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            "Set Value for ${inputTags[i]}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          content: TextField(
                            controller: _setValueTextFieldController,
                          ),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("Cancel",
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                var value = _setValueTextFieldController.text;
                                debugPrint(
                                    "Set value field : ${inputTags[i]}, index : $i, value : $value");
                                var message = ["set", i, value];
                                debugPrint(message.join('|'));

                                final nonce = AesGcm.with128bits().newNonce();
                                final secretKey = SecretKey(widget.aesKey);
                                final secretBox =
                                    await AesGcm.with128bits().encrypt(
                                  utf8.encode(message.join('|')),
                                  secretKey: secretKey,
                                  nonce: nonce,
                                );
                                widget.socket.add(nonce +
                                    secretBox.cipherText +
                                    secretBox.mac.bytes);

                                Navigator.pop(context);
                              },
                              child: Text("Set",
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  },
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(2.sp), minimumSize: Size.zero),
                  child: Text(
                    "Set Value",
                    style: Theme.of(context).textTheme.bodyMedium,
                  )),
            ]),
          ]),
          if (i + 1 < inputTags.length)
            Divider(
              height: 3.sp,
              thickness: 1.sp,
            ),
        ]),
    ]);
  }

  Container generateNode(BuildContext context, node) {
    var outputTags = _structure["nodes"][node]["output-tags"];
    var outputValues = _structure["nodes"][node]["output-values"];
    var inputTags = _structure["nodes"][node]["input-tags"];
    var inputValues = _structure["nodes"][node]["input-values"];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3.sp),
      color: Theme.of(context).scaffoldBackgroundColor,
      width: double.infinity,
      child: Column(children: [
        Text("Node ID - $node"),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w > 2.h ? 1.w : 1.h),
          child: Column(children: [
            if (outputTags.length > 0)
              Text("Output",
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            for (var i = 0; i < outputTags.length; i++)
              Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(outputTags[i]), Text(outputValues[i])]),
                if (i < outputTags.length - 1)
                  Divider(
                    height: 3.sp,
                    thickness: 1.sp,
                  )
              ]),
            if (inputTags.length > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Input",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary)),
                  SizedBox(
                    width: 10.sp,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        // TODO Request input data refresh
                        var message = ["refresh", node];
                        debugPrint(jsonEncode(message));
                      },
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.all(2.sp),
                          minimumSize: Size.zero),
                      child: Text(
                        "Refresh Data",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ))
                ],
              ),
            for (var i = 0; i < inputTags.length; i++)
              Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(inputTags[i]),
                      Row(children: [
                        Text(inputValues[i]),
                        SizedBox(width: 10.sp),
                        ElevatedButton(
                            onPressed: () {
                              _setValueTextFieldController.clear();
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text(
                                      "Set Value for ${inputTags[i]} for node $node",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    content: TextField(
                                      controller: _setValueTextFieldController,
                                    ),
                                    actions: <Widget>[
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text("Cancel",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          var value =
                                              _setValueTextFieldController.text;
                                          debugPrint(
                                              "Set value node : $node, field : ${inputTags[i]}, index : $i, value : $value");
                                          // TODO make request for this
                                          var message = [
                                            "set-value",
                                            node,
                                            i,
                                            value
                                          ];
                                          debugPrint(jsonEncode(message));

                                          final nonce =
                                              AesGcm.with128bits().newNonce();
                                          final secretKey =
                                              SecretKey(widget.aesKey);
                                          final secretBox =
                                              await AesGcm.with128bits()
                                                  .encrypt(
                                            utf8.encode(jsonEncode(message)),
                                            secretKey: secretKey,
                                            nonce: nonce,
                                          );
                                          widget.socket.add(nonce +
                                              secretBox.cipherText +
                                              secretBox.mac.bytes);

                                          Navigator.pop(context);
                                        },
                                        child: Text("Set",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium),
                                      ),
                                    ],
                                  );
                                },
                              );
                              return;
                            },
                            style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.all(2.sp),
                                minimumSize: Size.zero),
                            child: Text(
                              "Set Value",
                              style: Theme.of(context).textTheme.bodyMedium,
                            )),
                      ]),
                    ]),
                if (i + 1 < inputTags.length)
                  Divider(
                    height: 3.sp,
                    thickness: 1.sp,
                  ),
              ]),
            SizedBox(
              height: 4.sp,
            ),
          ]),
        ),
      ]),
    );
  }

  Container generateGatewayOptions(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 60, 60, 60),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.all(5),
          child: Text("Gateway node options"),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w > 2.h ? 1.w : 1.h),
          child: Column(children: [
            for (var option in _structure["options"].keys)
              Container(
                margin: EdgeInsets.symmetric(vertical: 5.sp),
                //color: Colors.amber,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(option),
                      SizedBox(
                        height: 20.sp,
                        width: 30.sp,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch(
                              value: _structure["options"]
                                  [option], //_structure["options"][option],
                              onChanged: (newValue) {
                                setState(() async {
                                  // TODO replace with request
                                  var message = [
                                    "set-option",
                                    option,
                                    newValue
                                  ];
                                  debugPrint(jsonEncode(message));

                                  final nonce = AesGcm.with128bits().newNonce();
                                  final secretKey = SecretKey(widget.aesKey);
                                  final secretBox =
                                      await AesGcm.with128bits().encrypt(
                                    utf8.encode(jsonEncode(message)),
                                    secretKey: secretKey,
                                    nonce: nonce,
                                  );
                                  widget.socket.add(nonce +
                                      secretBox.cipherText +
                                      secretBox.mac.bytes);
                                });
                              }),
                        ),
                      )
                    ]),
              ),
          ]),
        ),
      ]),
    );
  }

  void processMessage(messageData) async {
    if (_structure["type"] == "gateway") {
      SecretKey secretKey = SecretKey(widget.aesKey);
      List<int> iv = messageData.sublist(0, 12);
      List<int> cipherText = messageData.sublist(12, messageData.length - 16);
      List<int> tag = messageData.sublist(messageData.length - 16);
      SecretBox secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));

      dynamic message;
      try {
        List<int> decrypted =
            await AesGcm.with128bits().decrypt(secretBox, secretKey: secretKey);
        String decoded = utf8.decode(decrypted);

        message = jsonDecode(decoded);
      } on Exception catch (e) {
        debugPrint("$e");
      }
      if (message != null) {
        debugPrint("$message");
        if (message[0] == "options") {
          setState(() {
            for (var option in message[1].keys) {
              try {
                _structure["options"][option] = message[1][option];
              } on NoSuchMethodError catch (e) {
                debugPrint("$e");
              }
            }
          });
        } else {
          var node = _structure["nodes"][message[0]];
          if (node == null) {
            debugPrint("Invalid message - Node not found");
          } else if (node[message[1]] == null) {
            debugPrint("Invalid message - Field not found");
          } else {
            setState(() {
              try {
                for (var i = 0; i < node[message[1]].length; i++) {
                  node[message[1]][i] = message[2][i];
                }
              } on RangeError catch (e) {
                debugPrint("$e");
              }
            });
          }
        }
      }
    } else if (_structure["type"] == "camera") {
      _messageBuffer += messageData;
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
          SecretKey secretKey = SecretKey(widget.aesKey);

          List<int> iv = _message.sublist(0, 12);
          List<int> cipherText = _message.sublist(12, _message.length - 16);
          List<int> tag = _message.sublist(_message.length - 16);
          SecretBox secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));
          try {
            List<int> decrypted = await AesGcm.with128bits()
                .decrypt(secretBox, secretKey: secretKey);
            // Image data is always larger than 1000 bytes,
            // if the message is smaller it has to be input-values
            if (decrypted.length > 1000) {
              _structure["img"] = Uint8List.fromList(decrypted);
              _structure["imgAvail"] = true;
              setState(() {});
            } else {
              debugPrint("$decrypted");
              // Set input-values
              List<String> values = String.fromCharCodes(decrypted).split('|');
              debugPrint("$values");
              for (int i = 0; i < values.length; i++) {
                _structure["input-values"][i] = values[i];
              }
              setState(() {});
            }
          } on SecretBoxAuthenticationError {
            debugPrint("Authentication Error");
          }
        }
      }
    }
  }
}
