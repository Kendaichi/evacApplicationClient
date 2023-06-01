import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:introduction_screen/introduction_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:loading_icon_button/loading_icon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final position = LatLng(8.973949, 125.407456);

  //ipAdd
  String ipAddress =
      'http://192.168.0.128'; //replace with the ipaddress of your server

//formkey which will be used for validation
  final _formKey = GlobalKey<FormState>();

  //loadingbuttonController

  final LoadingButtonController _btnController = LoadingButtonController();

  //texteditingcontrollers. used to store the inputted datas on the TextFormFields
  final TextEditingController _nameController = TextEditingController();

  String? savedId;
  String? nameRes;

  // @override
  // initState() {
  //   super.initState();
  //   removeName();
  // }

  // void removeName() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   savedId = prefs.getString('id');
  //   print(savedId);
  //   prefs.remove('id');
  //   print(prefs.getString('id'));
  // }

  void saveId(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('id', id);
    setState(() {
      savedId = prefs.getString('id');
    });
  }

  //what happens if the user clicks the submit button
  void buttonPressed() async {
    _btnController.start();
    sendInfo();
    _btnController.success();
    Future.delayed(const Duration(seconds: 1), () {
      _btnController.reset();
    });
  }

  //what happens if the user clicks the submit button but the text form fields are empty
  void emptyFields() async {
    _btnController.start();
    _btnController.error();
    Future.delayed(const Duration(seconds: 1), () {
      _btnController.reset();
    });
  }

  void sendInfo() async {
    // Get the form field values
    String name = _nameController.text;
    double latitude = position.latitude;
    double longitude = position.longitude;

    // Create the request body
    String requestBody =
        'name=${Uri.encodeComponent(name)}&latitude=${Uri.encodeComponent(latitude.toString())}&longitude=${Uri.encodeComponent(longitude.toString())}';

    // Send the POST request
    Uri apiUrl = Uri.parse('$ipAddress/evacApp/postInformations.php');
    var response = await http.post(apiUrl, body: requestBody, headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    });

    // print(response.body);

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      // print(responseData["id"]);
      // print(responseData["name"]);
      final id = responseData["id"];
      saveId(id);
      setState(() {
        nameRes = responseData["name"];
      });
      _nameController.clear();
      _btnController.reset();
    } else {
      _btnController.error();
    }
  }

  //pageviews
  List<PageViewModel> getPages() {
    return [
      PageViewModel(
        titleWidget: Title(
          color: Colors.black,
          child: const Text(
            "Welcome!!",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        image: Image.asset("assets/intro1.png"),
        body:
            'This application aims to aid you in navigating to evacuation centers',
      ),
      PageViewModel(
        title: "INTRODUCE YOURSELF",
        image: SizedBox(
          height: 170,
          child: Image.asset("assets/intro2.png"),
        ),
        bodyWidget: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Field Empty';
                  } else {
                    return null;
                  }
                },
                decoration: const InputDecoration(
                  labelText: "Input Name Here(Juan O. Dela Cruz Jr.)",
                ),
              ),
              LoadingButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    buttonPressed();
                  } else {
                    emptyFields();
                  }
                },
                controller: _btnController,
                child: const Text("Click to Submit"),
              ),
            ],
          ),
        ),
        decoration: const PageDecoration(
            // pageColor: Colors.blue.shade100,
            ),
      ),
      PageViewModel(
        titleWidget: Title(
            color: Colors.black,
            child: savedId == null
                ? const Text(
                    "You should Probably Tell Us your name first",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Text(
                    "Hi $nameRes",
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
        image: Image.asset("assets/intro3.png"),
        body: 'Feel Free to rate this App in Google Play',
        decoration: const PageDecoration(
            imageAlignment: Alignment.bottomCenter,
            bodyAlignment: Alignment.center),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      allowImplicitScrolling: true,
      globalHeader: const Align(
        alignment: Alignment.topRight,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 16, right: 16),
          ),
        ),
      ),
      pages: getPages(),
      onDone: () {
        nameRes == null
            ? null
            : Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MapScreen(
                          id: savedId!,
                        )),
              );
      },
      showSkipButton: false,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: true,
      //rtl: true, // Display as right-to-left
      back: const Icon(
        Icons.arrow_back,
        color: Colors.black,
      ),
      next: const Icon(
        Icons.arrow_forward,
        color: Colors.black,
      ),
      done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color.fromARGB(255, 26, 23, 23),
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        activeColor: Color.fromARGB(255, 26, 23, 23),
      ),
      dotsContainerDecorator: ShapeDecoration(
        color: Colors.grey.withAlpha(200),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    );
  }
}
