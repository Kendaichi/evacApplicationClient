import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
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
  final position = LatLng(8.979671, 125.409217);
  // final position = LatLng(_latitude, _longitude);

  bool isVisible = false;

  String ipAddress = 'http://192.168.0.128'; //replace IPaddress of your server

  final LoadingButtonController _btnController = LoadingButtonController();
  final LoadingButtonController _buttonController2 = LoadingButtonController();
  bool isLoading = true;

  bool addPolygon = false;
  List<List<double>> polygonCoordinates = [];

  CrossFadeState _crossFadeState = CrossFadeState.showFirst;

  TransportationMode selectedTransportationMode = TransportationMode.driving;

  List<LatLng> points = [];
  List<Polyline> polylines = [];
  List<PointLatLng> polylineDecoded = [];

  List<ORSCoordinate> locations = [];

  OpenRouteService openrouteservice = OpenRouteService(
      apiKey: '5b3ce3597851110001cf6248ba5b43bc99fa48deac2dce8034ba9667');

  List<LatLng> evacuationCenters = [];
  List<Marker> markers = [];
  List<Marker> polygonMarker = [];
  List<Polygon> polygons = [];

  List<Map<String, double>> closestCoordinates = [];

  double durationRoute = 0.0;
  double distanceRoute = 0.0;

  // ignore: non_constant_identifier_names

  // ignore: prefer_typing_uninitialized_variables
  var user;

  @override
  void initState() {
    super.initState();

    // getCoordinates(8.974434, 125.409333);
    fetchCoordinates().then((value) {
      setState(() {
        evacuationCenters = value;
        // Initialize the markers list with fetched coordinates
        markers = [
          // Add the markers for the evacuation centers
          for (var i = 0; i < evacuationCenters.length; i++)
            Marker(
              point: evacuationCenters[i],
              builder: (context) => const Icon(
                Icons.local_hospital,
                size: 30,
                color: Colors.red,
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

    getAvoidPolygon();
    Future.delayed(const Duration(seconds: 5), () {
      getUserInfo(widget.id);
      sendLocation();
      fetchMatrixData();
    });
    startPeriodicTasks();
  }

  void fetchMatrixData() async {
    closestCoordinates = await getMatrix();
  }

  void startPeriodicTasks() {
    Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      sendLocation();
      getAvoidPolygon();
    });
  }

  void getAvoidPolygon() async {
    setState(() {
      polygons.clear();
    });
    final url = Uri.parse('$ipAddress/evacApp/getPolygons.php');
    final response = await http.get(url);

    // print(response.body);

    if (response.statusCode == 200) {
      if (response.body == "No data found.") {
        null;
      } else {
        List<dynamic> polygonsData = json.decode(response.body);

        // Create a list to store the polygons
        List<Polygon> polygons = [];

        // Iterate over each polygon data
        for (var polygonData in polygonsData) {
          // Extract the polygon string from the data
          String polygonString = polygonData['polygon_string'];

          // Remove the extra double quotes from the string
          polygonString = polygonString.replaceAll('"', '');

          // Parse the polygon coordinates from the string
          List<List<dynamic>> coordinates =
              json.decode(polygonString).cast<List<dynamic>>();

          // Create a list to store the LatLng points for the polygon
          List<LatLng> points = [];

          // Iterate over each coordinate pair and create LatLng points
          for (var coordinate in coordinates) {
            double latitude = coordinate[1].toDouble();
            double longitude = coordinate[0].toDouble();
            points.add(LatLng(latitude, longitude));
          }

          // Create the Polygon and add it to the list
          Polygon polygon = Polygon(
            points: points,
            color: Colors.blue.withOpacity(0.5),
            borderStrokeWidth: 2,
            borderColor: Colors.blue,
            isFilled: true,
          );
          polygons.add(polygon);
        }

        // Update the state with the polygons
        setState(() {
          this.polygons = polygons;
        });
      }
    } else {
      throw Exception('Erorr getting polygons: ${response.statusCode}');
    }
  }

  Future<void> addPolygonToDatabase(String polygon) async {
    final url = Uri.parse('$ipAddress/evacApp/getPolygons.php');
    final body = json.encode({'polygon': polygon});

    final response = await http.post(
      url,
      body: body,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      print('Polygon added successfully.');
    } else {
      print('Failed to add polygon: ${response.body}');
    }
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

  Future getMatrix() async {
    final TimeDistanceMatrix routeMatrix = await openrouteservice.matrixPost(
      locations: locations,
    );

    List<List<double>> durations = routeMatrix.durations;
    List<dynamic> destinations = routeMatrix.destinations;

    int sourceIndex = 0; // Index of locations[0]

    // Find the indices of the top 10 destinations with the shortest durations from locations[0] (excluding itself)
    List<double> durationsFromSource = durations[sourceIndex];
    durationsFromSource[sourceIndex] =
        double.infinity; // Exclude itself by setting its duration to infinity

    List<int> closestDestinationIndices = [];
    for (int i = 0; i < 10; i++) {
      int closestIndex =
          durationsFromSource.indexOf(durationsFromSource.reduce(min));
      closestDestinationIndices.add(closestIndex);
      durationsFromSource[closestIndex] = double
          .infinity; // Exclude the closest destination by setting its duration to infinity
    }

    // Get the coordinates of the closest destinations
    List<Map<String, double>> closestCoordinates = [];
    for (int index in closestDestinationIndices) {
      double closestDestinationLat = destinations[index].location.latitude;
      double closestDestinationLon = destinations[index].location.longitude;

      closestCoordinates.add({
        'latitude': closestDestinationLat,
        'longitude': closestDestinationLon,
      });
    }

    return closestCoordinates;
  }

  //function to consume the openRouteservice api
  getCoordinates() async {
    var profileOverride = '';

    switch (selectedTransportationMode) {
      case TransportationMode.walking:
        profileOverride = "foot-walking";
        break;
      case TransportationMode.driving:
        profileOverride = "driving-car";
        break;
      case TransportationMode.motorcycle:
        profileOverride = "cycling-electric";
        break;
    }

    final url = Uri.parse('$ipAddress/evacApp/getPolygons.php');
    final response = await http.get(url);
    List<List<List<List<double>>>> avoidPolygons = [];
    // print(response.body);

    if (response.statusCode == 200) {
      if (response.body == "No data found.") {
        null;
      } else {
        final List<dynamic> jsonResponse = json.decode(response.body);

        for (var item in jsonResponse) {
          final String polygonString = item['polygon_string'];
          final String formattedString = polygonString.replaceAll('"', '');
          final List<dynamic> coordinates = json.decode(formattedString);

          List<List<List<double>>> polygonCoordinates = [[]];

          for (var coord in coordinates) {
            final double latitude = coord[1];
            final double longitude = coord[0];
            polygonCoordinates[0].add(
                [longitude, latitude]); // Add coordinates to the nested list
          }

          avoidPolygons.add(polygonCoordinates);
        }

        // print(avoidPolygons);
      }
    } else {
      final snackBar = SnackBar(
        content: Text(response.toString()),
        duration: const Duration(seconds: 2),
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    String apiUrl =
        'https://api.openrouteservice.org/v2/directions/$profileOverride';

    final Map<String, String> headers = {
      'Accept':
          'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
      'Content-Type': 'application/json',
      'Authorization':
          '5b3ce3597851110001cf6248ba5b43bc99fa48deac2dce8034ba9667',
    };

    // Variables to store the closest coordinate and its corresponding distance or duration
    Map<String, dynamic>? closestResponseData;
    double? closestValue;

    for (var coordinate in closestCoordinates) {
      final Map<String, dynamic> requestBody = {
        "coordinates": [
          [position.longitude, position.latitude],
          [coordinate["longitude"], coordinate["latitude"]]
        ],
        "language": "de",
        "maneuvers": true,
        "options": {
          "avoid_polygons": {
            "type": "MultiPolygon",
            "coordinates": avoidPolygons,
          }
        }
      };

      final http.Response response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(requestBody));

      var responseData = json.decode(response.body);
      var summary = responseData['routes'][0]['summary'];
      var duration = summary["duration"];
      var distance = summary["distance"];

      // ignore: prefer_typing_uninitialized_variables
      var valueToCompare;
      if (profileOverride == "foot-walking") {
        valueToCompare = distance;
      } else {
        valueToCompare = duration;
      }

      if (closestValue == null || valueToCompare < closestValue) {
        closestValue = valueToCompare;
        closestResponseData = responseData;
      }
    }

    var encodedPol = closestResponseData!['routes'][0]['geometry'];
    var summary = closestResponseData['routes'][0]['summary'];
    var duration = summary["duration"];
    var distance = summary["distance"];
    // print(summary);

    setState(() {
      durationRoute = duration / 60;
      distanceRoute = distance / 1000;
    });

    polylineDecoded = PolylinePoints().decodePolyline(encodedPol);

    List<LatLng> newList = [];

    for (var object in polylineDecoded) {
      newList.add(LatLng(object.latitude, object.longitude));
    }
    // print(newList);

    setState(() {
      points = newList;
      if (polylines.isNotEmpty) {
        polylines[0] = Polyline(
          points: points,
          color: Colors.green.shade900,
          strokeWidth: 3,
        );
      } else {
        polylines.add(Polyline(
          points: points,
          color: Colors.green.shade900,
          strokeWidth: 3,
        ));
      }
    });

    //footWalking; drivingCar; cyclingElectric
  }

  void buttonPressed() async {
    _btnController.start();
    await getCoordinates();
    _btnController.success();
    Future.delayed(const Duration(seconds: 1), () {
      _btnController.reset();
    });
    setState(() {
      isVisible = true;
    });
  }

  void addPolygonFunction() async {
    _buttonController2.start();
    polygonCoordinates.add(polygonCoordinates.first);

    addPolygonToDatabase(polygonCoordinates.toString());
    getAvoidPolygon();

    polygonCoordinates.clear();
    _buttonController2.success();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              fetchCoordinates().then((value) {
                setState(() {
                  evacuationCenters = value;
                  // Initialize the markers list with fetched coordinates
                  markers = [
                    // Add the markers for the evacuation centers
                    for (var i = 0; i < evacuationCenters.length; i++)
                      Marker(
                        point: evacuationCenters[i],
                        builder: (context) => const Icon(
                          Icons.local_hospital,
                          size: 30,
                          color: Colors.red,
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
              getAvoidPolygon();
              sendLocation();
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.black,
            )),
        automaticallyImplyLeading: false,
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
          addPolygon
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      polygonCoordinates.clear();
                      polygonMarker.clear();
                      addPolygon = false;
                    });
                  },
                  icon: const Icon(
                    Icons.cancel,
                    color: Colors.black,
                  ))
              : Container(
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
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            center: position,
            zoom: 13.5,
            maxZoom: 18,
            minZoom: 3.0,
            interactiveFlags: InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.drag,
            onTap: (tapPosition, tappedLocation) {
              // print(tappedLocation.toString());
              List<double> coordinate = [
                tappedLocation.longitude,
                tappedLocation.latitude
              ];
              addPolygon
                  ? setState(() {
                      polygonCoordinates.add(coordinate);
                      polygonMarker.add(
                        Marker(
                            point: tappedLocation,
                            builder: (context) => const Icon(
                                  Icons.location_pin,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                            anchorPos: AnchorPos.align(AnchorAlign.top)),
                      );
                    })
                  : print(tappedLocation);
              // print(polygonCoordinates);
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
              // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // userAgentPackageName: 'dev.fleaflet.flutter_map.example',
            ),
            MarkerLayer(markers: [
              ...markers,
              if (polygonMarker.isNotEmpty) ...polygonMarker,
            ]),
            //to print the route
            PolylineLayer(
              polylines: polylines,
            ),
            PolygonLayer(
              polygonCulling: false,
              polygons: polygons,
            )
          ],
        ),
        Visibility(
          visible: isVisible,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10,
                sigmaY: 10,
              ),
              child: Container(
                  width: 150,
                  height: 50,
                  margin: const EdgeInsets.fromLTRB(20, 100, 0, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      Text(
                          "Duration: ${durationRoute.toStringAsFixed(2)} min."),
                      Text("Distance: ${distanceRoute.toStringAsFixed(2)} km."),
                    ],
                  )),
            ),
          ),
        )
      ]),
      floatingActionButton: addPolygon
          ? LoadingButton(
              onPressed: () {
                if (polygonMarker.length < 3) {
                  print("error");
                  _buttonController2.reset();
                } else {
                  setState(() {
                    addPolygonFunction();
                    polygonMarker.clear();
                    polygonCoordinates.clear();
                    addPolygon = false;
                  });
                }
              },
              controller: _buttonController2,
              child: const Text("Add Polygon"),
            )
          : Container(
              width: 50, // Adjust the size as needed
              height: 50, // Adjust the size as needed
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
              child: LoadingButton(
                controller: _btnController,
                onPressed: () {},
                child: SpeedDial(
                  animatedIcon: AnimatedIcons.search_ellipsis,
                  children: [
                    SpeedDialChild(
                      child: IconButton(
                        icon: const Icon(Icons.directions_car),
                        onPressed: () {
                          setState(() {
                            selectedTransportationMode =
                                TransportationMode.driving;
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
                            selectedTransportationMode =
                                TransportationMode.walking;
                          });
                          buttonPressed();
                        },
                      ),
                      label: 'Walking ',
                    ),
                    SpeedDialChild(
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                addPolygon = true;
                              });
                            },
                            icon: const Icon(Icons.shape_line)),
                        label: 'Add Polygon')
                  ],
                ),
              ),
            ),
    );
  }
}
