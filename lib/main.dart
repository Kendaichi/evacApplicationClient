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
  bool showIntro = false;

  @override
  void initState() {
    super.initState();
    checkFirstLaunch();
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
      home: showIntro ? const IntroScreen() : const MapScreen(),
    );
  }
}
