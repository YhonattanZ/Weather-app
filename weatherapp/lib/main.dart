import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:weatherapp/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().initNotification();

  runApp(const WeatherApp());
}

class WeatherApp extends StatefulWidget {
  const WeatherApp({Key? key}) : super(key: key);

  @override
  _WeatherAppState createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  var _latitude = "";
  var _longitude = "";
  String _currentAddress = "";

  Future<void> _updatePosition() async {
    Position pos = await _determinePosition();
    List<Placemark> placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
    Placemark place = placemarks[0];
    setState(() {
      _currentAddress =
          "${place.administrativeArea}, ${place.country}, ${place.locality}";
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  int temperature = 0;
  List<int> minTempForecast = List.filled(7, 0);
  List<int> maxTempForecast = List.filled(7, 0);
  List<String> abbreviationForecast = List.filled(7, '');

  final urlImage = 'https://www.metaweather.com/static/img/weather/png/';
  int woeid = 395269;
  String location = 'Capital District';
  String weather = 'clear';
  String abbreviation = '';

  String locationApiUrl = 'https://www.metaweather.com/api/location/';
  @override
  void initState() {
    super.initState();
    fetchLocation();
    fecthLocationDay();
    NotificationService().initNotification();
    WidgetsFlutterBinding.ensureInitialized();

    tz.initializeTimeZones();
  }

  String searchApiUrl =
      'https://www.metaweather.com/api/location/search/?query=';

  void locationSearch(String input) async {
    var searchResult = await http.get(Uri.parse(searchApiUrl + input));
    var result = json.decode(searchResult.body)[0];

    setState(() {
      location = result["title"];
      woeid = result["woeid"];
    });
  }

  void fetchSearch(String input) async {
    {
      var searchResult = await http.get(Uri.parse(searchApiUrl + input));
      var result = json.decode(searchResult.body);

      setState(() {
        location = result["title"];
        woeid = result["woeid"];
      });
    }
  }

  void fetchLocation() async {
    var locationResult =
        await http.get(Uri.parse(locationApiUrl + woeid.toString()));
    var result = json.decode(locationResult.body);
    var consolidated_weather = result["consolidated_weather"];
    var data = consolidated_weather[0];

    setState(() {
      temperature = data["the_temp"].round();
      weather = data["weather_state_name"].replaceAll(' ', '').toLowerCase();
      abbreviation = data["weather_state_abbr"];
    });
  }

  void fecthLocationDay() async {
    var today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      var locationDayResult = await http.get(Uri.parse(locationApiUrl +
          woeid.toString() +
          '/' +
          DateFormat('y/M/d')
              .format(today.add(Duration(days: i + 1)))
              .toString()));
      var result = json.decode(locationDayResult.body);
      var data = result[0];
      setState(() {
        minTempForecast[i] = data["min_temp"].round();
        maxTempForecast[i] = data["max_temp"].round();

        abbreviationForecast[i] = data["weather_state_abbr"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
              image: const AssetImage('assets/images/fondo.jpg'),
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.6), BlendMode.darken),
              fit: BoxFit.cover),
        ),
        child: temperature == 0
            ? const Center(
                child: CircularProgressIndicator.adaptive(
                    backgroundColor: Colors.white),
              )
            : Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: const Icon(Icons.menu, color: Colors.white),
                  title: const Center(
                    child: Text(
                      'Weather App',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                  actions: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          _updatePosition();
                          NotificationService().showNotification(
                              1,
                              '${temperature}°C' + "  Nice weather to run",
                              "Weather App",
                              5);
                        },
                        child: const Icon(Icons.location_city,
                            color: Colors.white),
                      ),
                    )
                  ],
                ),
                resizeToAvoidBottomInset: false,
                backgroundColor: Colors.transparent,
                body: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Column(children: <Widget>[
                      Center(
                          child: Image.network(
                        'https://www.metaweather.com/static/img/weather/png/'
                        '${abbreviation}'
                        '.png',
                        width: 100,
                      )),
                      Center(
                        child: Text(
                          temperature.toString() + '°C',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 50),
                        ),
                      ),
                      Center(
                        child: Text(
                          _currentAddress,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ]),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (var i = 0; i < 7; i++)
                            forecastElement(i + 1, abbreviationForecast[i],
                                maxTempForecast[i], minTempForecast[i])
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget forecastElement(
    daysFromNow, abbreviation, maxTempForecast, minTempForecast) {
  var now = DateTime.now();
  var oneDayFromNow = now.add(new Duration(days: daysFromNow));
  return Padding(
    padding: const EdgeInsets.only(left: 8.0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          child: Column(
            children: <Widget>[
              Text(
                DateFormat.E().format(oneDayFromNow),
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                DateFormat.MMMd().format(oneDayFromNow),
                style: const TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              Image.network(
                'https://www.metaweather.com/static/img/weather/png/'
                '${abbreviation}'
                '.png',
                width: 50,
              ),
              SizedBox(height: 10),
              Text(
                'High: ' + maxTempForecast.toString() + ' °C',
                style: const TextStyle(color: Colors.white, fontSize: 20.0),
              ),
              Text(
                'Low: ' + minTempForecast.toString() + ' °C',
                style: const TextStyle(color: Colors.white, fontSize: 20.0),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
