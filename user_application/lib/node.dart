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

  @override
  void initState() {
    super.initState();

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
          if (_waitingForStructure) {
            setState(() {
              _waitingForStructure = false;
              try {
                _structure = jsonDecode(decoded);
              } on FormatException catch (e) {
                debugPrint("$e");
                _structure = null;
              }
            });
          } else {
            debugPrint(decoded);
            processMessage(decoded);
          }
        } on SecretBoxAuthenticationError {
          debugPrint("Authentication Error");
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

  void processMessage(messageString) {
    dynamic message;
    try {
      message = jsonDecode(messageString);
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
  }
}
