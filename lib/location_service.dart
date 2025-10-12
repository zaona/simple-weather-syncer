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

      // 使用中等精度定位（避免触发Google位置信息精确度服务提示）
      Position? position;
      
      try {
        // 首先尝试获取最后已知位置（快速且不触发提示）
        position = await Geolocator.getLastKnownPosition();
        
        // 如果没有缓存位置，使用中等精度定位（不会触发Google服务提示）
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,  // 使用中等精度，避免触发提示
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('定位超时'),
        );
      } catch (e) {
        // 如果中等精度也失败，尝试低精度定位（兜底方案）
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('定位超时'),
          );
        } catch (e2) {
          throw Exception('定位超时，请确保已开启位置服务');
        }
      }

      // 格式化为 "经度,纬度"（保留两位小数）
      final longitude = position.longitude.toStringAsFixed(2);
      final latitude = position.latitude.toStringAsFixed(2);
      
      return '$longitude,$latitude';
    } on TimeoutException {
      throw Exception('定位超时，请确保已开启位置服务');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取位置失败: ${e.toString()}');
    }
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

