import 'dart:convert';
import 'package:sizer/sizer.dart';

import 'package:flutter/material.dart';

class NodePage extends StatefulWidget {
  const NodePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  final TextStyle _error = TextStyle(color: Colors.red.shade700);

  final String _structureString =
      '{"type":"gateway","options":{"Auto Light Control":true},'
      '"nodes":{"1":{"output-tags":["Temperature (°C)","Relative Humidity (%)","Heat Index (°C)","Light (0-4095)"],"output-values":["N/A","N/A","N/A","N/A"],"input-tags":["Sleep time (seconds)"],"input-values":["N/A"]}'
      ',"2":{"output-tags":["1","2"],"output-values":["-","-"],"input-tags":[],"input-values":[]}'
      ',"3":{"output-tags":[],"output-values":[],"input-tags":["1","2"],"input-values":["-","-"]}'
      ',"4":{"output-tags":[],"output-values":[],"input-tags":[],"input-values":[]}'
      '}}';
  dynamic _structure;

  final TextEditingController _setValueTextFieldController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    try {
      _structure = jsonDecode(_structureString);
    } on FormatException catch (e) {
      debugPrint("$e");
      _structure = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(2.w > 2.h ? 2.w : 2.h),
        child: Center(
          child: ListView(
            children: <Widget>[
              if (_structure == null) ...[
                Text("Error getting data from node!", style: _error)
              ] else ...[
                if (_structure["type"] == "gateway") ...[
                  generateTest(context),
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

  Container generateTest(BuildContext context) {
    return Container(
        child: Column(children: [
      ElevatedButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Test"),
                  content: TextField(
                    controller: _setValueTextFieldController,
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        var value = _setValueTextFieldController.text;
                        // Simulating data received
                        processMessage(value);

                        Navigator.pop(context);
                      },
                      child: const Text("Set"),
                    ),
                  ],
                );
              });
        },
        child: const Text("Test"),
      )
    ]));
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
                                        onPressed: () {
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
                                setState(() {
                                  // TODO replace with request
                                  var message = [
                                    "set-option",
                                    option,
                                    newValue
                                  ];
                                  debugPrint(jsonEncode(message));
                                  //_structure["options"][option] = newValue;
                                  //print(_structure);
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
              for (var i = 2; i < message.length; i++) {
                node[message[1]][i - 2] = message[i];
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
