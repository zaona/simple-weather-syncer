import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'weather_models.dart';

/// 天气服务类
class WeatherService {
  // 从环境变量读取 API Key
  static String get apiKey => dotenv.env['QWEATHER_API_KEY'] ?? '';
  
  // 从环境变量读取 API Host
  static String get apiHost => dotenv.env['QWEATHER_API_HOST'] ?? 'devapi.qweather.com';
  
  // 从环境变量读取 Android 包名
  static String get androidPackageName => dotenv.env['ANDROID_PACKAGE_NAME'] ?? '';
  
  // 从环境变量读取 Android 证书 SHA-1 指纹
  static String get androidCertSha1 => dotenv.env['ANDROID_CERT_SHA1'] ?? '';
  
  // API 地址
  static String get geoApiUrl => 'https://$apiHost/geo/v2/city/lookup';
  static String get weatherApiBaseUrl => 'https://$apiHost/v7/weather';
  
  static const String recentSearchesKey = 'weather_recent_searches';
  static const String recentLocationsKey = 'weather_recent_locations';
  static const int maxRecentSearches = 10;
  static const int maxRecentLocations = 5;

  /// 搜索城市
  static Future<List<CityLocation>> searchLocation(String cityName) async {
    if (cityName.trim().isEmpty) {
      throw Exception('请输入城市名称');
    }

    try {
      final uri = Uri.parse('$geoApiUrl?location=${Uri.encodeComponent(cityName)}');
      
      final response = await http.get(
        uri,
        headers: {
          'X-QW-Api-Key': apiKey,
          'Content-Type': 'application/json',
          'X-Android-Package-Name': androidPackageName,
          'X-Android-Cert': androidCertSha1,
        },
      );

      if (response.statusCode == 401) {
        throw Exception('API密钥无效或已过期');
      } else if (response.statusCode == 429) {
        throw Exception('请求过于频繁，请稍后再试');
      } else if (response.statusCode != 200) {
        throw Exception('请求失败，状态码: ${response.statusCode}，响应: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['code'] == '200' && data['location'] != null && (data['location'] as List).isNotEmpty) {
        return (data['location'] as List)
            .map((loc) => CityLocation.fromJson(loc))
            .toList();
      } else if (data['code'] == '404') {
        throw Exception('未找到"$cityName"相关的地区，请检查城市名称是否正确');
      } else if (data['code'] == '204') {
        throw Exception('未找到相关地区，请尝试使用其他城市名称');
      } else {
        throw Exception('未找到相关地区，请检查输入的城市名称。返回码: ${data['code']}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查您的网络连接或稍后重试');
    }
  }

  /// 获取天气数据
  /// [location] 可以是 LocationID 或 经纬度（格式：经度,纬度）
  static Future<WeatherData> fetchWeather(String location, String locationName, String days) async {
    if (location.isEmpty) {
      throw Exception('位置信息不能为空');
    }

    try {
      final uri = Uri.parse('$weatherApiBaseUrl/$days?location=$location');
      
      final response = await http.get(
        uri,
        headers: {
          'X-QW-Api-Key': apiKey,
          'Content-Type': 'application/json',
          'X-Android-Package-Name': androidPackageName,
          'X-Android-Cert': androidCertSha1,
        },
      );

      if (response.statusCode == 401) {
        throw Exception('API密钥无效或已过期');
      } else if (response.statusCode == 429) {
        throw Exception('请求过于频繁，请稍后再试');
      } else if (response.statusCode == 404) {
        throw Exception('该地区天气信息不可用');
      } else if (response.statusCode != 200) {
        throw Exception('请求失败，状态码: ${response.statusCode}，响应: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['code'] == '200') {
        return WeatherData.fromJson(data, locationName);
      } else if (data['code'] == '404') {
        throw Exception('该地区天气信息不可用');
      } else {
        throw Exception('获取天气数据失败。返回码: ${data['code']}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查您的网络连接或稍后重试');
    }
  }

  /// 通过经纬度获取城市信息
  /// [coordinates] 格式：经度,纬度（例如：116.41,39.92）
  static Future<CityLocation?> getCityByCoordinates(String coordinates) async {
    if (coordinates.isEmpty) {
      throw Exception('经纬度信息不能为空');
    }

    try {
      final uri = Uri.parse('$geoApiUrl?location=$coordinates');
      
      final response = await http.get(
        uri,
        headers: {
          'X-QW-Api-Key': apiKey,
          'Content-Type': 'application/json',
          'X-Android-Package-Name': androidPackageName,
          'X-Android-Cert': androidCertSha1,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == '200' && data['location'] != null && (data['location'] as List).isNotEmpty) {
          // 返回第一个匹配的城市
          return CityLocation.fromJson(data['location'][0]);
        }
      }
      
      // 如果查询失败，返回null，调用方可以使用默认名称
      return null;
    } catch (e) {
      // 反向地理编码失败不影响主流程，返回null
      return null;
    }
  }

  /// 使用经纬度获取天气数据
  /// [coordinates] 格式：经度,纬度（例如：116.41,39.92）
  /// [cityName] 可选的城市名称，如果提供则使用，否则使用默认名称
  static Future<WeatherData> fetchWeatherByCoordinates(
    String coordinates, 
    String days, 
    {String? cityName}
  ) async {
    if (coordinates.isEmpty) {
      throw Exception('经纬度信息不能为空');
    }

    // 验证经纬度格式
    final parts = coordinates.split(',');
    if (parts.length != 2) {
      throw Exception('经纬度格式错误');
    }

    // 确定位置名称
    String locationName;
    if (cityName != null && cityName.isNotEmpty) {
      locationName = cityName;
    } else {
      locationName = '当前位置 ($coordinates)';
    }
    
    return fetchWeather(coordinates, locationName, days);
  }

  /// 加载历史搜索
  static Future<List<CityLocation>> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString(recentSearchesKey);
      
      if (savedData != null && savedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(savedData);
        return jsonList.map((item) => CityLocation.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 保存搜索历史
  static Future<void> saveRecentSearches(List<CityLocation> searches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = searches.map((loc) => loc.toJson()).toList();
      await prefs.setString(recentSearchesKey, json.encode(jsonList));
    } catch (e) {
      // 保存失败不影响主流程
    }
  }

  /// 添加到搜索历史
  static Future<List<CityLocation>> addToRecentSearches(
    CityLocation location,
    List<CityLocation> currentSearches,
  ) async {
    // 检查是否已存在
    final existingIndex = currentSearches.indexWhere((item) => item.id == location.id);
    
    if (existingIndex != -1) {
      // 如果已存在，移到最前面
      currentSearches.removeAt(existingIndex);
    }

    // 添加到最前面
    currentSearches.insert(0, location);

    // 限制最多保存10个城市
    if (currentSearches.length > maxRecentSearches) {
      currentSearches = currentSearches.sublist(0, maxRecentSearches);
    }

    // 保存到本地
    await saveRecentSearches(currentSearches);

    return currentSearches;
  }

  /// 加载最近定位的位置
  static Future<List<CityLocation>> loadRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString(recentLocationsKey);
      
      if (savedData != null && savedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(savedData);
        return jsonList.map((item) => CityLocation.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 保存最近定位的位置
  static Future<void> saveRecentLocations(List<CityLocation> locations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = locations.map((loc) => loc.toJson()).toList();
      await prefs.setString(recentLocationsKey, json.encode(jsonList));
    } catch (e) {
      // 保存失败不影响主流程
    }
  }

  /// 添加到定位历史
  static Future<List<CityLocation>> addToRecentLocations(
    CityLocation location,
    List<CityLocation> currentLocations,
  ) async {
    // 检查是否已存在
    final existingIndex = currentLocations.indexWhere((item) => item.id == location.id);
    
    if (existingIndex != -1) {
      // 如果已存在，移到最前面
      currentLocations.removeAt(existingIndex);
    }

    // 添加到最前面
    currentLocations.insert(0, location);

    // 限制最多保存5个位置
    if (currentLocations.length > maxRecentLocations) {
      currentLocations = currentLocations.sublist(0, maxRecentLocations);
    }

    // 保存到本地
    await saveRecentLocations(currentLocations);

    return currentLocations;
  }
}

