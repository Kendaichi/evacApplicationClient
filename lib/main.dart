import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  String? savedId = "";

  bool showIntro = false;

  @override
  void initState() {
    super.initState();
    checkFirstLaunch().then((value) {
      if (!showIntro) {
        getID();
      }
    });
  }

  void getID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedId = prefs.getString('id') ?? "";
    });
  }

  Future<void> checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

    setState(() {
      showIntro = isFirstLaunch;
    });

    if (isFirstLaunch) {
      prefs.setBool('first_launch', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: showIntro
            ? IntroScreen()
            : MapScreen(
                id: savedId!,
              ));
  }
}
