import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/slide_model.dart';
import '../core/theme/palette.dart'; // Palette is needed for consistent styling if used, or just good practice.

// Simple in-memory cache to avoid rate limits
// V2: Includes humidity, wind, feels_like
class WeatherData {
  final double tempC;
  final int weatherCode;
  final double humidity;
  final double windSpeedKm;
  final double feelsLikeC;
  final DateTime captured;

  WeatherData({
    required this.tempC,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeedKm,
    required this.feelsLikeC,
  }) : captured = DateTime.now();

  bool get isStale => DateTime.now().difference(captured).inMinutes > 30;
}

// Global cache (renamed to force invalidation of V1 cache)
Map<String, WeatherData> _weatherCacheV2 = {};

class WeatherLayerWidget extends StatefulWidget {
  final SlideLayer layer;
  final double scale;

  const WeatherLayerWidget({Key? key, required this.layer, this.scale = 1.0})
    : super(key: key);

  @override
  State<WeatherLayerWidget> createState() => _WeatherLayerWidgetState();
}

class _WeatherLayerWidgetState extends State<WeatherLayerWidget> {
  double? _tempC;
  int? _weatherCode;
  double? _humidity;
  double? _windSpeedKm;
  double? _feelsLikeC;

  bool _loading = false;
  Timer? _refreshTimer;

  String get _city => widget.layer.weatherCity ?? 'New York';
  bool get _isCelsius => widget.layer.weatherCelsius ?? false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _loadWeather(),
    );
  }

  @override
  void didUpdateWidget(covariant WeatherLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.weatherCity != widget.layer.weatherCity) {
      _loadWeather();
    }
    // Also reload if force refreshed (not applicable here typically, but good to know)
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final city = _city;
    if (_weatherCacheV2.containsKey(city)) {
      final cached = _weatherCacheV2[city]!;
      if (!cached.isStale) {
        if (mounted) _applyData(cached);
        return;
      }
    }

    if (mounted) setState(() => _loading = true);

    try {
      debugPrint('Weather: Fetching for $city...');
      // 1. Geocoding
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=en&format=json',
      );
      final geoResp = await http.get(geoUrl);
      if (geoResp.statusCode != 200) throw Exception('Geo failed');

      final geoData = jsonDecode(geoResp.body);
      if (geoData['results'] == null || (geoData['results'] as List).isEmpty) {
        throw Exception('City not found');
      }

      final lat = geoData['results'][0]['latitude'];
      final lng = geoData['results'][0]['longitude'];

      // 2. Weather
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&wind_speed_unit=kmh',
      );
      final wResp = await http.get(weatherUrl);
      if (wResp.statusCode != 200) throw Exception('Weather failed');

      final wData = jsonDecode(wResp.body);
      final current = wData['current'];

      final newData = WeatherData(
        tempC: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        humidity: (current['relative_humidity_2m'] as num).toDouble(),
        windSpeedKm: (current['wind_speed_10m'] as num).toDouble(),
        feelsLikeC: (current['apparent_temperature'] as num).toDouble(),
      );

      _weatherCacheV2[city] = newData;

      if (mounted) {
        _applyData(newData);
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Weather Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyData(WeatherData data) {
    setState(() {
      _tempC = data.tempC;
      _weatherCode = data.weatherCode;
      _humidity = data.humidity;
      _windSpeedKm = data.windSpeedKm;
      _feelsLikeC = data.feelsLikeC;
    });
  }

  IconData _getIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.water_drop;
    if (code <= 77) return Icons.ac_unit;
    if (code <= 82) return Icons.umbrella;
    return Icons.thunderstorm;
  }

  String _getConditionText(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
        return 'Fog';
      case 48:
        return 'Depositing Rime Fog';
      case 51:
        return 'Light Drizzle';
      case 53:
        return 'Moderate Drizzle';
      case 55:
        return 'Dense Drizzle';
      case 61:
        return 'Slight Rain';
      case 63:
        return 'Moderate Rain';
      case 65:
        return 'Heavy Rain';
      case 71:
        return 'Slight Snow';
      case 73:
        return 'Moderate Snow';
      case 75:
        return 'Heavy Snow';
      case 95:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = (widget.layer.boxPadding ?? 0.0) * widget.scale;
    const double kBaseFontSize = 200.0;
    const double kDetailFontSize = 60.0;

    final textColor = widget.layer.textColor ?? Colors.white;
    final iconData = _weatherCode != null
        ? _getIcon(_weatherCode!)
        : Icons.cloud_off;

    // Values
    String tempStr = '--';
    String feelsLikeStr = '--';
    String windStr = '--';

    if (_tempC != null) {
      // Temp
      double val = _tempC!;
      if (!_isCelsius) val = (val * 9 / 5) + 32;
      tempStr = '${val.round()}°';

      // Feels Like
      double fl = _feelsLikeC ?? _tempC!;
      if (!_isCelsius) fl = (fl * 9 / 5) + 32;
      feelsLikeStr = '${fl.round()}°';

      // Wind (km/h -> mph)
      double wind = _windSpeedKm ?? 0;
      if (!_isCelsius) {
        wind = wind * 0.621371;
        windStr = '${wind.round()} mph';
      } else {
        windStr = '${wind.round()} km/h';
      }
    }

    final List<Widget> details = [];

    // 1. Condition Text
    if (widget.layer.weatherShowCondition == true && _weatherCode != null) {
      details.add(
        Text(
          _getConditionText(_weatherCode!),
          style: TextStyle(fontSize: kDetailFontSize, color: textColor),
        ),
      );
    }

    // 2. Humidity
    if (widget.layer.weatherShowHumidity == true && _humidity != null) {
      details.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: kDetailFontSize,
              color: textColor,
            ),
            SizedBox(width: 10),
            Text(
              '${_humidity!.round()}%',
              style: TextStyle(fontSize: kDetailFontSize, color: textColor),
            ),
          ],
        ),
      );
    }

    // 3. Wind
    if (widget.layer.weatherShowWind == true && _windSpeedKm != null) {
      details.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.air, size: kDetailFontSize, color: textColor),
            SizedBox(width: 10),
            Text(
              windStr,
              style: TextStyle(fontSize: kDetailFontSize, color: textColor),
            ),
          ],
        ),
      );
    }

    // 4. Feels Like
    if (widget.layer.weatherShowFeelsLike == true && _feelsLikeC != null) {
      details.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thermostat, size: kDetailFontSize, color: textColor),
            SizedBox(width: 10),
            Text(
              'Feels $feelsLikeStr',
              style: TextStyle(fontSize: kDetailFontSize, color: textColor),
            ),
          ],
        ),
      );
    }

    final List<Widget> detailRowChildren = [];
    for (int i = 0; i < details.length; i++) {
      detailRowChildren.add(details[i]);
      if (i < details.length - 1) {
        detailRowChildren.add(const SizedBox(width: 40));
      }
    }

    return Container(
      padding: EdgeInsets.all(padding),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main Row: Icon + Temp
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_loading && _tempC == null)
                  SizedBox(
                    width: kBaseFontSize,
                    height: kBaseFontSize,
                    child: CircularProgressIndicator(color: textColor),
                  )
                else ...[
                  Icon(
                    iconData,
                    size: kBaseFontSize,
                    color: textColor,
                    shadows: const [
                      Shadow(
                        offset: Offset(4, 4),
                        blurRadius: 8,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  Text(
                    tempStr,
                    style: TextStyle(
                      fontFamily: widget.layer.fontFamily,
                      fontSize: kBaseFontSize,
                      color: textColor,
                      fontWeight: (widget.layer.isBold == true)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: (widget.layer.isItalic == true)
                          ? FontStyle.italic
                          : FontStyle.normal,
                      shadows: const [
                        Shadow(
                          offset: Offset(4, 4),
                          blurRadius: 8,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Details Row
            if (detailRowChildren.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: detailRowChildren,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
