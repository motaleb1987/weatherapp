import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _cityCtrl = TextEditingController(text: 'Dhaka');

  bool _loading = false;
  String? _error;
  String? _resolvedCity;

  // current
  double? _tempC;
  int? _wCode;
  double? _windKph;
  String? _country;

  // daily
  List<String> _dateForecust = [];
  List<double> _maxTemps = [];
  List<double> _minTemps = [];

  // hourly
  List<_Hourly> _hourlies = [];

  //------ Geo Coding API--------
  Future<({String city, String country, double lat, double lng})?> geoCoding(
    String city,
  ) async {
    final url = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=en&format=json",
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Geo Coding Error ${response.statusCode}");
    }

    final deCodedData = jsonDecode(response.body) as Map<String, dynamic>;
    final result = deCodedData["results"] as List<dynamic>?;

    if (result == null || result.isEmpty) {
      throw Exception("City Not found");
    }

    final m = result.first as Map<String, dynamic>;
    final rName = m['name'] as String;
    final rLat = (m['latitude'] as num).toDouble();
    final rLng = (m['longitude'] as num).toDouble();
    final rCountry = m['country'] as String;

    return (city: rName, country: rCountry, lat: rLat, lng: rLng);
  }

  //------ Forecast API --------
  Future<void> _fetch(String city) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final getGeo = await geoCoding(city);
      if (getGeo == null) throw Exception("City not resolved");

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${getGeo.lat}&longitude=${getGeo.lng}'
        '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset'
        '&hourly=temperature_2m,weather_code,wind_speed_10m'
        '&current=temperature_2m,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception("Forecast Error ${response.statusCode}");
      }

      final deCodedData = jsonDecode(response.body) as Map<String, dynamic>;

      // -------- current --------
      final current = (deCodedData['current'] as Map<String, dynamic>?) ?? {};
      final tempC = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
      final wCode = (current['weather_code'] as num?)?.toInt();
      final windKms = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;

      // -------- hourly --------
      final hourly = (deCodedData['hourly'] as Map<String, dynamic>?) ?? {};
      final hTime = List<String>.from((hourly['time'] as List?) ?? []);
      final hTemps = List<num>.from((hourly['temperature_2m'] as List?) ?? []);
      final hCode = List<num>.from((hourly['weather_code'] as List?) ?? []);

      final outHourly = <_Hourly>[];
      for (var i = 0; i < hTime.length; i++) {
        outHourly.add(
          _Hourly(
            time: DateTime.parse(hTime[i]),
            temp: (i < hTemps.length ? hTemps[i] : 0).toDouble(),
            code: (i < hCode.length ? hCode[i] : 0).toInt(),
          ),
        );
      }

      // -------- daily --------
      final daily = (deCodedData['daily'] as Map<String, dynamic>?) ?? {};

      // date labels
      final dTime = List<String>.from((daily['time'] as List?) ?? []);
      for (int i = 0; i < dTime.length; i++) {
        final date = DateTime.parse(dTime[i]);
        final now = DateTime.now();
        final isToday =
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        dTime[i] = isToday ? 'Today' : DateFormat('EEE').format(date);
      }

      // min/max temps
      final maxTemp = List<num>.from(
        (daily['temperature_2m_max'] as List?) ?? [],
      );
      final minTemp = List<num>.from(
        (daily['temperature_2m_min'] as List?) ?? [],
      );

      setState(() {
        _tempC = tempC;
        _wCode = wCode;
        _windKph = windKms;
        _resolvedCity = getGeo.city;
        _country = getGeo.country;

        _hourlies = outHourly;
        _dateForecust = dTime;
        _maxTemps = maxTemp.map((e) => e.toDouble()).toList();
        _minTemps = minTemp.map((e) => e.toDouble()).toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Code to Text convert (for weather code)
  String _codeToText(int? c) {
    if (c == null) return '__';
    if (c == 0) return 'Mostly Sunny';
    if ([1, 2, 3].contains(c)) return 'Partly Cloudy';
    if ([45, 48].contains(c)) return 'Fog';
    return "Cloud";
  }

  IconData _codeToIcon(int ? c){
    if(c == null) return Icons.sunny;
    if(c == 0) return Icons.sunny_snowing;
    if([1, 2, 3].contains(c)) return Icons.cloud;
    if([45,48].contains(c)) return Icons.foggy;
    return Icons.cloud_circle;

  }


  @override
  void initState() {
    super.initState();
    _fetch('Dhaka');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blueAccent,
              Colors.blue,
              Colors.lightBlueAccent,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Enter City (e.g: Dhaka)',
                        labelStyle: TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _fetch(_cityCtrl.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading) const LinearProgressIndicator(
                color: Colors.orange,
                minHeight: 4,
              ),
              const SizedBox(height: 10),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
              ],
              Column(
                children: [
                  Text(
                    _country == null ? "My Location" : _country!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _resolvedCity ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _tempC == null ? "--°C" : "${_tempC!.toStringAsFixed(0)}°C",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 100,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _codeToText(_wCode),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Wind ${_windKph?.toStringAsFixed(1) ?? "__"} kmps',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _hourlies.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final h = _hourlies[index];
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(h.time.hour.toString()),
                                Icon(_codeToIcon(h.code)),
                                Text('${h.temp.toStringAsFixed(0)}°C'),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '7-Day Forecast',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          itemCount: _dateForecust.length,
                          itemBuilder: (context, index) {

                            final label = _dateForecust[index];
                            final min = index < _minTemps.length
                                ? _minTemps[index]
                                : 0;
                            final max = index < _maxTemps.length
                                ? _maxTemps[index]
                                : 0;

                            //double progressValue =(_tempC! - min) / (max - min);
                            //progressValue = progressValue.clamp(0.0, 1.0);
                          double progressValue = max/100;



                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 90, child: Text(label)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.sunny_snowing),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: progressValue,
                                      color: Colors.grey[300],
                                      backgroundColor: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${min.toStringAsFixed(0)}° - ${max.toStringAsFixed(0)}°',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hourly {
  final DateTime time;
  final double temp;
  final int code;

  _Hourly({required this.time, required this.temp, required this.code});
}
