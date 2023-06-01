import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'intro.dart';
import 'map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? savedId;
  bool showIntro = true;

  @override
  void initState() {
    super.initState();
    checkSavedId().then((value) {
      if (value == null) {
        setState(() {
          showIntro = true;
        });
      } else {
        setState(() {
          showIntro = false;
          savedId = value;
        });
      }
    });
  }

  Future<String?> checkSavedId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('id');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: showIntro ? const IntroScreen() : MapScreen(id: savedId!),
    );
  }
}
