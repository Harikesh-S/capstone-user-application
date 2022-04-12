import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:user_application/node.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:crypto/crypto.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _nodeIDController;

  bool _gotPublicKey = false;
  late encrypt.Encrypter _encrypter;

  final Random _random = Random.secure();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _nodeIDController = TextEditingController();
    // Get public key
    http
        .get(
      Uri.http('192.168.1.2:3000', 'key'),
    )
        .then((res) {
      if (res.statusCode != 200) {
        debugPrint("Error getting key - ${res.statusCode}");
      } else {
        debugPrint("Got public key");
        _encrypter = encrypt.Encrypter(encrypt.RSA(
            publicKey: encrypt.RSAKeyParser().parse(res.body) as RSAPublicKey));
        _gotPublicKey = true;
      }
    }).onError((error, stackTrace) {
      debugPrint("$error");
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nodeIDController.dispose();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                constraints: BoxConstraints(maxHeight: 30.sp),
                width: (SizerUtil.orientation == Orientation.portrait)
                    ? 80.w
                    : 80.h,
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Username",
                    hintText: "Enter username",
                  ),
                ),
              ),
              SizedBox(
                  height: (SizerUtil.orientation == Orientation.portrait)
                      ? 1.h
                      : 1.w),
              Container(
                constraints: BoxConstraints(maxHeight: 30.sp),
                width: (SizerUtil.orientation == Orientation.portrait)
                    ? 80.w
                    : 80.h,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Password",
                    hintText: "Enter password",
                  ),
                ),
              ),
              SizedBox(
                  height: (SizerUtil.orientation == Orientation.portrait)
                      ? 1.h
                      : 1.w),
              Container(
                constraints: BoxConstraints(maxHeight: 30.sp),
                width: (SizerUtil.orientation == Orientation.portrait)
                    ? 80.w
                    : 80.h,
                child: TextField(
                  controller: _nodeIDController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Node ID",
                    hintText: "Enter node id",
                  ),
                ),
              ),
              SizedBox(
                  height: (SizerUtil.orientation == Orientation.portrait)
                      ? 1.h
                      : 1.w),
              ElevatedButton(
                onPressed: _onButtonPressed,
                style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(4.sp), minimumSize: Size.zero),
                child: const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onButtonPressed() async {
    if (!_gotPublicKey) {
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Error"),
              content: const Text("Error getting public key"),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          });
      return;
    }

    var username = _usernameController.text;
    var password = sha256.convert(utf8.encode(_passwordController.text));
    var nodeID = _nodeIDController.text;

    var key = List<int>.generate(16, (i) => _random.nextInt(256));
    var keyString = base64.encode(key);

    debugPrint("Username : $username");
    debugPrint("Password hash : $password");
    debugPrint("Node ID : $nodeID");
    debugPrint("Generated Key : $key");
    debugPrint("Generated Key(Base64) : $keyString");

    var data = jsonEncode(["valid", username, "$password", nodeID, keyString]);

    var encrypted = _encrypter.encrypt(data);

    debugPrint("Encrypted message : ${encrypted.base64}");

    var res = await http.post(
      //Uri.parse("http://192.168.1.2:3000/login"),
      Uri.http('192.168.1.2:3000', 'login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: jsonEncode([encrypted.base64]),
    );

    // Display alert if response has errors else connect to the node
    if (res.statusCode != 200) {
      await showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            String content;
            if (res.statusCode == 400) {
              content = "Unable to connect to node";
            } else if (res.statusCode == 401) {
              content = "Invalid credentials";
            } else if (res.statusCode == 403) {
              content = "Invalid node ID";
            } else if (res.statusCode == 418) {
              content = "Error communcating with node";
            } else {
              content = "Status code : ${res.statusCode}, data: ${res.body}";
            }
            return AlertDialog(
              title: Text("Response",
                  style: Theme.of(context).textTheme.bodyMedium),
              content:
                  Text(content, style: Theme.of(context).textTheme.bodyMedium),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "OK",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          });
    } else {
      var recvd = jsonDecode(res.body);
      var ip = recvd[0];
      var xor = base64.decode(recvd[1]);

      for (var i = 0; i < 16; i++) {
        key[i] = key[i] ^ xor[i];
      }
      //content = "Key : ${String.fromCharCodes(key)}";\
      debugPrint("Connecting to IP : $ip Key : $key");
      Socket socket = await Socket.connect(ip, 50001);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NodePage(
            socket: socket,
            aesKey: key,
            nodeID: nodeID,
          ),
        ),
      ).then(
        (value) {
          debugPrint("Disconnecting...");
          socket.close();
        },
      );
    }
  }
}
