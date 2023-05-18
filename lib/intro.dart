import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:introduction_screen/introduction_screen.dart';
import 'package:loading_icon_button/loading_icon_button.dart';

import 'map.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  //ipAdd
  String ipAddress =
      'http://192.168.1.13'; //replace with the ipaddress of your server

//formkey which will be used for validation
  final _formKey = GlobalKey<FormState>();

  //loadingbuttonController

  final LoadingButtonController _btnController = LoadingButtonController();

  //texteditingcontrollers. used to store the inputted datas on the TextFormFields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

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
    String address = _addressController.text;

    // Create the request body
    String requestBody =
        'name=${Uri.encodeComponent(name)}&address=${Uri.encodeComponent(address)}';

    // Send the POST request
    Uri apiUrl = Uri.parse('$ipAddress/evacApp/postInformations.php');
    var response = await http.post(apiUrl, body: requestBody, headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    });

    if (response.statusCode == 200) {
      _nameController.clear();
      _addressController.clear();
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
              TextFormField(
                controller: _addressController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Field Empty';
                  } else {
                    return null;
                  }
                },
                decoration: const InputDecoration(
                  labelText: "Address",
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
          child: const Text(
            "Thank You So Much",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
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
