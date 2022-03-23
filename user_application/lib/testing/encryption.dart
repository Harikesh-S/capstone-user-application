import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';

class EncryptedLoginPage extends StatefulWidget {
  const EncryptedLoginPage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<EncryptedLoginPage> createState() => _EncryptedLoginPageState();
}

class _EncryptedLoginPageState extends State<EncryptedLoginPage> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Username",
                  hintText: "Enter username",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Password",
                  hintText: "Enter password",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () async {
                    var username = _usernameController.text;
                    var password =
                        sha256.convert(utf8.encode(_passwordController.text));

                    debugPrint(username);
                    debugPrint("$password");

                    var data = jsonEncode(["valid", username, "$password"]);

                    // Get public key
                    var keyRes = await http.get(
                      Uri.http('192.168.1.2:3000', 'key'),
                    );

                    if (keyRes.statusCode != 200) {
                      debugPrint("Error getting key - ${keyRes.statusCode}");
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

                    final publicKey = encrypt.RSAKeyParser().parse(keyRes.body)
                        as RSAPublicKey;

                    var encrypter =
                        encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));

                    var encrypted = encrypter.encrypt(data);

                    debugPrint(encrypted.base64);

                    var res = await http.post(
                      //Uri.parse("http://192.168.1.2:3000/login"),
                      Uri.http('192.168.1.2:3000', 'login'),
                      headers: <String, String>{
                        'Content-Type': 'application/json; charset=UTF-8'
                      },
                      body: jsonEncode([encrypted.base64]),
                    );

                    await showDialog<void>(
                        context: context,
                        builder: (BuildContext context) {
                          String content;
                          if (res.statusCode == 200) {
                            content = "Response : ${res.body}";
                          } else {
                            content = "Status code : ${res.statusCode}";
                          }
                          return AlertDialog(
                            title: const Text("Response"),
                            content: Text(content),
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
                  },
                  child: const Text("Login"))
            ],
          )),
    );
  }
}
