import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:latlong2/latlong.dart';
import 'package:loading_icon_button/loading_icon_button.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final String id;

  const MapScreen({super.key, required this.id});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum TransportationMode {
  walking,
  driving,
  motorcycle,
}

class _MapScreenState extends State<MapScreen> {
  final position = LatLng(8.973950, 125.407456);
  String ipAddress =
      'http://192.168.249.174'; //replace IPaddress of your server

  final LoadingButtonController _btnController = LoadingButtonController();
  bool isLoading = true;

  CrossFadeState _crossFadeState = CrossFadeState.showFirst;

  TransportationMode selectedTransportationMode = TransportationMode.driving;

  List<LatLng> points = [];
  List<Polyline> polylines = [];

  List<ORSCoordinate> locations = [];

  OpenRouteService openrouteservice = OpenRouteService(
      apiKey: '5b3ce3597851110001cf6248ba5b43bc99fa48deac2dce8034ba9667');

  List<LatLng> evacuationCenters = [];
  List<Marker> markers = [];

  // ignore: prefer_typing_uninitialized_variables
  var user;

  @override
  void initState() {
    super.initState();
    fetchCoordinates().then((value) {
      setState(() {
        evacuationCenters = value;
        // Initialize the markers list with fetched coordinates
        markers = [
          // Add the markers for the evacuation centers
          for (var i = 0; i < evacuationCenters.length; i++)
            Marker(
              point: evacuationCenters[i],
              builder: (context) => GestureDetector(
                onTap: () {
                  getCoordinates(
                    evacuationCenters[i].latitude,
                    evacuationCenters[i].longitude,
                  );
                },
                child: const Icon(
                  Icons.local_hospital,
                  size: 30,
                  color: Colors.red,
                ),
              ),
            ),

          // Add the marker for the current location
          Marker(
              point: position,
              builder: (context) => IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.location_pin,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
              anchorPos: AnchorPos.align(AnchorAlign.top)),
        ];
      });
    }).catchError((e) {
      throw Exception('Failed to fetch coordinates: $e');
    });
    Future.delayed(const Duration(seconds: 2), () {
      getUserInfo(widget.id);
      sendLocation();
    });
  }

  void getUserInfo(String userId) async {
    // Send the GET request
    Uri apiUrl = Uri.parse('$ipAddress/evacApp/getByUser.php?id=$userId');
    var response = await http.get(apiUrl);

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        var responseData = json.decode(response.body);

        if (responseData["success"]) {
          setState(() {
            user = responseData["user"];
            if (user["safe"] == false) {
              _crossFadeState = CrossFadeState.showSecond;
            } else {
              _crossFadeState = CrossFadeState.showFirst;
            }
          });
          // print(user);
        } else {
          // User not found
          print("User not found.");
        }
      } else {
        // Empty response
        print("Empty response.");
      }
    } else {
      // Error occurred
      print("Error: ${response.statusCode}");
    }
  }

  void toggleSafe() async {
    // Send the POST request
    Uri apiUrl = Uri.parse('$ipAddress/evacApp/getByUser.php');
    var response = await http.post(apiUrl, body: {'id': widget.id});
    // print(response.body);

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      print(responseData);
      getUserInfo(widget.id);
    } else {
      // Error occurred
      print("Error: ${response.statusCode}");
    }
  }

  void sendLocation() async {
    // Send the POST request
    Uri apiUrl = Uri.parse('$ipAddress/evacApp/sendLocation.php');
    var response = await http.post(apiUrl, body: {
      'id': widget.id,
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString()
    });

    // print(response.body);

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      print(responseData);
      // getUserInfo(widget.id);
    } else {
      // Error occurred
      print("Error: ${response.statusCode}");
    }
  }

  Future<List<LatLng>> fetchCoordinates() async {
    final url = Uri.parse('$ipAddress/evacApp/getEvacuationCenters.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      final List<LatLng> evacuationpoints = jsonData.map((data) {
        double latitude = double.parse(data['latitude']);
        double longitude = double.parse(data['longitude']);
        return LatLng(latitude, longitude);
      }).toList();
      locations.add(ORSCoordinate(
          latitude: position.latitude, longitude: position.longitude));
      locations.addAll(evacuationpoints.map((LatLng coordinate) =>
          ORSCoordinate(
              latitude: coordinate.latitude, longitude: coordinate.longitude)));
      // print(locations);
      return evacuationpoints;
    } else {
      throw Exception('Failed to fetch coordinates: ${response.statusCode}');
    }
  }

  getMatrix() async {
    final TimeDistanceMatrix routeMatrix = await openrouteservice.matrixPost(
      locations: locations,
    );

    List<List<double>> durations = routeMatrix.durations;
    List<dynamic> destinations = routeMatrix.destinations;

    int sourceIndex = 0; // Index of locations[0]

    // Find the index of the destination with the shortest duration from locations[0] (excluding itself)
    List<double> durationsFromSource = durations[sourceIndex];
    durationsFromSource[sourceIndex] =
        double.infinity; // Exclude itself by setting its duration to infinity
    int closestDestinationIndex =
        durationsFromSource.indexOf(durationsFromSource.reduce(min));

    // Get the coordinates of the closest destination
    double closestDestinationLat =
        destinations[closestDestinationIndex].location.latitude;
    double closestDestinationLon =
        destinations[closestDestinationIndex].location.longitude;

    getCoordinates(closestDestinationLat, closestDestinationLon);
  }

  //function to consume the openRouteservice api
  getCoordinates(double lat, double lon) async {
    ORSProfile profileOverride;

    switch (selectedTransportationMode) {
      case TransportationMode.walking:
        profileOverride = ORSProfile.footWalking;
        break;
      case TransportationMode.driving:
        profileOverride = ORSProfile.drivingCar;
        break;
      case TransportationMode.motorcycle:
        profileOverride = ORSProfile.cyclingElectric;
        break;
    }

    final List<ORSCoordinate> routeCoordinates =
        await openrouteservice.directionsMultiRouteCoordsPost(
      coordinates: [
        ORSCoordinate(
            latitude: position.latitude, longitude: position.longitude),
        ORSCoordinate(
          latitude: lat,
          longitude: lon,
        ),
      ],
      profileOverride: profileOverride,
    );

    //footWalking; drivingCar; cyclingElectric

    List<LatLng> newPoints = [];

    for (var object in routeCoordinates) {
      newPoints.add(LatLng(object.latitude, object.longitude));
    }

    setState(() {
      points = newPoints;
      if (polylines.isNotEmpty) {
        polylines[0] = Polyline(
          points: points,
          color: Colors.red,
          strokeWidth: 3,
        );
      } else {
        polylines.add(Polyline(
          points: points,
          color: Colors.red,
          strokeWidth: 3,
        ));
      }
    });
  }

  void buttonPressed() async {
    _btnController.start();
    await getMatrix();
    _btnController.success();
    Future.delayed(const Duration(seconds: 1), () {
      _btnController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white.withAlpha(200),
        title: const Text(
          "Evacuation Map",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 3, 10, 0),
            child: AnimatedCrossFade(
              firstChild: IconButton(
                onPressed: () {
                  toggleSafe();
                },
                icon: const Icon(
                  Icons.toggle_off_outlined,
                  color: Colors.green,
                  size: 33,
                ),
              ),
              secondChild: IconButton(
                onPressed: () {
                  toggleSafe();
                },
                icon: const Icon(
                  Icons.toggle_on,
                  color: Colors.red,
                  size: 33,
                ),
              ),
              crossFadeState: _crossFadeState,
              duration: const Duration(milliseconds: 500),
            ),
          )
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          center: position,
          zoom: 13.5,
          maxZoom: 18,
          minZoom: 3.0,
          interactiveFlags: InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.drag,
          onTap: (tapPosition, tappedLocation) {
            print(tappedLocation.toString());
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/kendaichi/clho8v3vu00mh01rhgm4v34v2/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoia2VuZGFpY2hpIiwiYSI6ImNsaG84bG9kbzB2NWwzZXFybmlsMmNkbWsifQ.zwewd3N0NaAE_4vZ61N4dQ',
            additionalOptions: const {
              'accessToken':
                  'pk.eyJ1Ijoia2VuZGFpY2hpIiwiYSI6ImNsaG84bG9kbzB2NWwzZXFybmlsMmNkbWsifQ.zwewd3N0NaAE_4vZ61N4dQ',
              'id': ''
            },
          ),
          MarkerLayer(
            markers: markers,
          ),
          //to print the route
          PolylineLayer(
            polylines: polylines,
          ),
          // PolygonLayer(
          //   polygonCulling: false,
          //   polygons: [
          //     Polygon(
          //         points: [
          //           LatLng(8.916185, 125.586196),
          //           LatLng(8.915692, 125.586309),
          //           LatLng(8.916148, 125.585799),
          //         ],
          //         color: Colors.blue.withOpacity(0.5),
          //         borderStrokeWidth: 2,
          //         borderColor: Colors.blue,
          //         isFilled: true),
          //   ],
          // )
        ],
      ),
      floatingActionButton: Container(
        width: 70, // Adjust the size as needed
        height: 70, // Adjust the size as needed
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
        ),
        child: LoadingButton(
          controller: _btnController,
          onPressed: () => buttonPressed(),
          child: SpeedDial(
            animatedIcon: AnimatedIcons.search_ellipsis,
            children: [
              SpeedDialChild(
                child: IconButton(
                  icon: const Icon(Icons.directions_car),
                  onPressed: () {
                    setState(() {
                      selectedTransportationMode = TransportationMode.driving;
                    });
                    buttonPressed();
                  },
                ),
                label: 'Driving Car',
              ),
              SpeedDialChild(
                child: IconButton(
                  icon: const Icon(Icons.electric_bike),
                  onPressed: () {
                    setState(() {
                      selectedTransportationMode =
                          TransportationMode.motorcycle;
                    });
                    buttonPressed();
                  },
                ),
                label: 'Motorcycle',
              ),
              SpeedDialChild(
                child: IconButton(
                  icon: const Icon(Icons.nordic_walking),
                  onPressed: () {
                    setState(() {
                      selectedTransportationMode = TransportationMode.walking;
                    });
                    buttonPressed();
                  },
                ),
                label: 'Walking ',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
