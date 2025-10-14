import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 定位服务类
class LocationService {
  /// 检查定位权限状态
  static Future<bool> checkPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// 申请定位权限
  static Future<bool> requestPermission() async {
    // 先检查定位服务是否开启
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置服务未开启，请在设置中开启位置服务');
    }

    // 检查权限
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('位置权限被拒绝');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('位置权限被永久拒绝，请在设置中手动开启');
    }

    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// 获取当前位置的经纬度
  /// 返回格式：经度,纬度（保留两位小数）
  static Future<String> getCurrentLocation() async {
    try {
      // 先检查并申请权限
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        throw Exception('未获取到位置权限');
      }

      // 三级降级定位策略
      Position? position;
      
      // 1️⃣ 优先：获取缓存位置（最快，不消耗电量）
      position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        // 格式化为 "经度,纬度"（保留两位小数）
        final longitude = position.longitude.toStringAsFixed(2);
        final latitude = position.latitude.toStringAsFixed(2);
        return '$longitude,$latitude';
      }
      
      // 2️⃣ 次选：低精度定位（实机更快更稳定，30秒超时）
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: _getLocationSettings(LocationAccuracy.low),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('定位超时'),
        );
        
        // 格式化为 "经度,纬度"（保留两位小数）
        final longitude = position.longitude.toStringAsFixed(2);
        final latitude = position.latitude.toStringAsFixed(2);
        return '$longitude,$latitude';
      } catch (e) {
        // 如果低精度失败，继续尝试最低精度
      }
      
      // 3️⃣ 兜底：最低精度定位（20秒超时，最后的保障）
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: _getLocationSettings(LocationAccuracy.lowest),
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('定位超时'),
        );
        
        // 格式化为 "经度,纬度"（保留两位小数）
        final longitude = position.longitude.toStringAsFixed(2);
        final latitude = position.latitude.toStringAsFixed(2);
        return '$longitude,$latitude';
      } catch (e2) {
        throw Exception('定位超时，请确保已开启位置服务');
      }
    } on TimeoutException {
      throw Exception('定位超时，请确保已开启位置服务');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取位置失败: ${e.toString()}');
    }
  }

  /// 获取 Android 平台的定位设置
  /// 
  /// 使用原生定位管理器，不依赖 Google Play Services
  static AndroidSettings _getLocationSettings(LocationAccuracy accuracy) {
    return AndroidSettings(
      accuracy: accuracy,
      distanceFilter: 100,  // 距离过滤器：移动100米才更新
      forceLocationManager: true,  // 强制使用 Android 原生定位管理器，不依赖 Google Play Services
      intervalDuration: const Duration(seconds: 5),  // 定位更新间隔
      timeLimit: const Duration(seconds: 30),  // 定位超时限制
    );
  }

  /// 获取详细的位置信息（包含更多数据）
  static Future<Position> getDetailedPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('未获取到位置权限');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// 打开应用的位置权限设置页面
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// 打开应用设置页面
  static Future<void> openAppSettings() async {
    await Permission.location.request();
  }
}

