/// 城市地理位置信息
class CityLocation {
  final String id;
  final String name;
  final String adm1; // 省份
  final String adm2; // 城市

  CityLocation({
    required this.id,
    required this.name,
    required this.adm1,
    required this.adm2,
  });

  factory CityLocation.fromJson(Map<String, dynamic> json) {
    return CityLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      adm1: json['adm1'] ?? '',
      adm2: json['adm2'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'adm1': adm1,
      'adm2': adm2,
    };
  }

  @override
  String toString() => '$name ($adm1 - $adm2)';
}

/// 天气数据
class WeatherData {
  final Map<String, dynamic> rawData; // 保存原始 API 响应数据
  final String location; // 城市名称

  WeatherData({
    required this.rawData,
    required this.location,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, String locationName) {
    return WeatherData(
      rawData: json,
      location: locationName,
    );
  }

  /// 转换为 JSON 字符串（用于发送到手表）
  /// 与 Vue 代码逻辑一致：将原始数据展开，然后添加 location 字段
  String toJsonString() {
    // 将地名作为 location 字段添加到数据中
    final enhancedData = {
      ...rawData,
      'location': location,
    };
    return jsonToString(enhancedData);
  }

  static String jsonToString(dynamic data) {
    if (data is Map) {
      final entries = data.entries.map((e) {
        return '"${e.key}": ${jsonToString(e.value)}';
      }).join(', ');
      return '{$entries}';
    } else if (data is List) {
      final items = data.map((item) => jsonToString(item)).join(', ');
      return '[$items]';
    } else if (data is String) {
      return '"$data"';
    } else {
      return data.toString();
    }
  }

  // 便捷访问常用字段
  String get code => rawData['code'] ?? '';
  String get updateTime => rawData['updateTime'] ?? '';
  String get fxLink => rawData['fxLink'] ?? '';
  List<dynamic> get daily => rawData['daily'] ?? [];
}

/// 每日天气信息
class DailyWeather {
  final String fxDate;
  final String tempMax;
  final String tempMin;
  final String textDay;
  final String textNight;

  DailyWeather({
    required this.fxDate,
    required this.tempMax,
    required this.tempMin,
    required this.textDay,
    required this.textNight,
  });

  factory DailyWeather.fromJson(Map<String, dynamic> json) {
    return DailyWeather(
      fxDate: json['fxDate'] ?? '',
      tempMax: json['tempMax'] ?? '',
      tempMin: json['tempMin'] ?? '',
      textDay: json['textDay'] ?? '',
      textNight: json['textNight'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fxDate': fxDate,
      'tempMax': tempMax,
      'tempMin': tempMin,
      'textDay': textDay,
      'textNight': textNight,
    };
  }
}

