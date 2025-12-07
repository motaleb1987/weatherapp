import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {

  final _cityCtrl = TextEditingController(text: 'Dhaka');
  bool _loading =false;
  String ? _error;
  String ? _resolvedCity;

  // current tem

  double ? _tempC;
  int ? _wCode;
  double ? _windKph;
  String ? _country;
  String ? _wText;

  // home work

  double ? _highT, _lowT;
  List<String> _dateForecust =[];

   List<_Hourly> _hourlies =[];

  //------ Geo Coding API--------
  Future<({String city, String country, double lat, double lng})?> geoCoding(String city) async {
    final url = Uri.parse("https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=en&format=json");
    final response = await http.get(url);
    //print(response.body);

    if(response.statusCode !=200) throw Exception("Geo Coding Error ${response.statusCode}");
    final deCodedData = jsonDecode(response.body) as Map<String, dynamic>;
    final result = deCodedData["results"] as List<dynamic>;
    if(result == null || result.isEmpty) throw Exception("City Not found");

    final m = result.first as Map<String, dynamic>;
    final rName = m['name'] as String;
   // final rName = (m['name'] ?? '' ) as String;
    final rLat = m['latitude'] as double;
    final rLng = m['longitude'] as double;
    final rCountry = m['country'] as String;

   // print('$rName, $rLat, $rLng, $rCountry');
    return (city: rName, country: rCountry, lat: rLat, lng: rLng);

  }

  //------ Geo Coding API--------
  Future<void> _fetch(String city) async{
    setState(() {
      _loading = true;
      _error = null;
    });
    try{
      final getGeo =await geoCoding(city);
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast'
          '?latitude=${getGeo!.lat}&longitude=${getGeo.lng}'
          '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset'
          '&hourly=temperature_2m,weather_code,wind_speed_10m'
          '&current=temperature_2m,weather_code,wind_speed_10m'
          '&timezone=auto');


      final response = await http.get(url);
     // print(response.body);
      if(response.statusCode !=200) throw Exception("Forecast Error ${response.statusCode}");
      final deCodedData = jsonDecode(response.body) as Map<String, dynamic>;

      // current key er  data
      final current = (deCodedData['current'] as Map ?) ?? {};
      final tempC = ((current['temperature_2m'] ?? 0) as num).toDouble();
      final wCode = (current['weather_code'] as num ?)?.toInt();
      final windKms = ((current['wind_speed_10m'] ?? 0 ) as num).toDouble();



      // hourly key er data

      final hourly = (deCodedData['hourly']) as Map<String, dynamic>;
      final hTime = List<String>.from(hourly['time'] as List);
      final hTemps = List<num>.from(hourly['temperature_2m'] as List);
      final hCode = List<num>.from(hourly['weather_code'] as List);

      final outHourly = <_Hourly>[];
      for(var i = 0; i<hTime.length; i++){
        outHourly.add(_Hourly(
            time: DateTime.parse(hTime[i]),
            temp: (hTemps[i]).toDouble(),
            code: (hCode[i]).toInt()
          )
        );
      }

      final dDate = await ((deCodedData['daily']) as Map<String, dynamic> ? ) ??  {};
      final dTime = List<String>.from(dDate['time'] as List);
      final maxTemp= (dDate['temperature_2m_max']);
      final minTemp= dDate['temperature_2m_min'];
      //print(maxTemp);
     // print(minTemp);



      setState(() {
        _tempC = tempC;
        _wCode = wCode;
        _windKph = windKms;
        _resolvedCity = getGeo!.city;
        _country = getGeo.country;
        _hourlies = outHourly;
        _dateForecust = dTime;
        _highT = maxTemp;
        _lowT = minTemp;
      });



    }catch(e){
      _error = e.toString();
    }finally{
      setState(() {
        _loading = false;
      });
    }
  }


  // Code to Text convert (for weather code)

  String _codeToText(int ? c){
    if(c == null) return '__';
    if(c == 0) return 'Mostly Sunny';
    if([1, 2, 3].contains(c)) return 'Partly Cloudy';
    if([45,48].contains(c)) return 'Fog';
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
    // TODO: implement initState
  //geoCoding('Dhaka');
  _fetch('Dhaka');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
              Colors.blueAccent,
              Colors.blue,
              //Colors.lightBlue,
              Colors.lightBlueAccent,
              Colors.white
            ])
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
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
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
                            )
                        ),
                      ),
                    ),
                    SizedBox(width: 8,),
                    FilledButton(onPressed: _loading ? null : () => _fetch(_cityCtrl.text), child: Text('Search'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white, 
                          foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)
                        )
                      ),
                    )
                  ],
                ),
                _loading ? const LinearProgressIndicator() : SizedBox(),
                SizedBox(height: 10,),
                Column(
                  children: [
                    Text(_country == null ? "My Location": " $_country", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18, color: Colors.white),),
                    Text(_resolvedCity.toString(), style: TextStyle(fontWeight: FontWeight.bold,fontSize: 20, color: Colors.white),),
                    Text("${_tempC?.toStringAsFixed(0).toString()}°C", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 100, color: Colors.white),),
                    Text(_codeToText(_wCode), style: TextStyle(fontWeight: FontWeight.bold,fontSize: 20, color: Colors.white),),
                  ],
                ),
                const SizedBox(height: 20,),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Wind ${_windKph.toString()} kmps'),
                  ),
                ),
                const SizedBox(height: 16,),
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
                              separatorBuilder: (_, __ ) => const SizedBox(width: 12,),
                             itemBuilder: (context, index){
                                final h =_hourlies[index];
                                return Column(
                                  children: [
                                    Text(h.time.hour.toString()),
                                    Icon(_codeToIcon(h.code)),
                                    Text('${h.temp.toStringAsFixed(0)}°C')
                                  ],
                                );
                             },


                         ),
                       )
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
                        Text('7-Day Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

                        SizedBox(
                          height: 250,
                          child: ListView.builder(
                            itemCount: _dateForecust.length,
                              itemBuilder: (context, index) {
                             // final t = _highT ?? _highT[index] : 0;
                            return  Row(
                              children: [
                                Text(_dateForecust[index]),
                                SizedBox(width: 10,),
                                Icon(Icons.sunny_snowing,),
                                SizedBox(width: 10,),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: 0.6,
                                    color: Colors.grey[300],
                                    backgroundColor: Colors.orange,
                                  ),
                                ),
                                SizedBox(width: 10,),
                                Text('17° - 27° '),
                              ],
                            );
                          }),
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

class _Hourly{
  final DateTime time;
  final double temp;
  final int code;

  _Hourly({required this.time, required this.temp, required this.code});
}
