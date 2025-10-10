import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'update_models.dart';

class UpdateService {
  // Gitee仓库的更新配置文件URL
  // 请替换为您实际的Gitee仓库地址
  static const String updateConfigUrl = 
      'https://gitee.com/zaona/simple-weather-update/raw/master/update.json';

  /// 检查应用更新（已废弃，请使用 checkForUpdateManually）
  /// 返回更新信息，如果没有更新则返回null
  /// 注意：此方法在网络错误时也返回null，无法区分"无更新"和"网络错误"
  @Deprecated('使用 checkForUpdateManually() 以获得更详细的错误信息')
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      // 获取本地应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);

      // 请求远程更新配置
      final response = await http.get(
        Uri.parse(updateConfigUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('获取更新信息失败: ${response.statusCode}');
      }

      // 解析JSON数据
      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      final updateInfo = AppUpdateInfo.fromJson(jsonData);

      // 比对版本号
      if (updateInfo.versionCode > currentVersionCode) {
        return updateInfo;
      }

      // 没有更新
      return null;
    } catch (e) {
      // 更新检查失败不影响应用正常使用，静默处理
      // 可选：使用logger记录错误，或完全忽略
      return null;
    }
  }

  /// 获取当前应用版本信息（版本名 + 构建号）
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }

  /// 获取当前应用版本名
  static Future<String> getVersionName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 获取当前应用版本号
  static Future<int> getCurrentVersionCode() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return int.parse(packageInfo.buildNumber);
  }

  /// 手动检查应用更新（带详细错误信息）
  /// 返回详细的检查结果，包括错误信息
  static Future<UpdateCheckResult> checkForUpdateManually() async {
    try {
      // 获取本地应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);

      // 请求远程更新配置（设置10秒超时）
      final response = await http.get(
        Uri.parse(updateConfigUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return UpdateCheckResult.failed('服务器返回错误: ${response.statusCode}');
      }

      // 解析JSON数据
      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      final updateInfo = AppUpdateInfo.fromJson(jsonData);

      // 比对版本号
      if (updateInfo.versionCode > currentVersionCode) {
        return UpdateCheckResult.hasUpdate(updateInfo);
      }

      // 没有更新
      return UpdateCheckResult.noUpdate();
    } on TimeoutException catch (_) {
      // 请求超时
      return UpdateCheckResult.failed('连接超时，请检查网络');
    } on SocketException catch (e) {
      // 网络连接错误（无网络、DNS失败、连接被拒绝等）
      String errorMsg = '网络连接失败，请检查网络';
      
      final message = e.message.toLowerCase();
      if (message.contains('failed host lookup') || 
          message.contains('nodename nor servname provided')) {
        errorMsg = '无法连接到服务器，请检查网络';
      } else if (message.contains('network is unreachable') || 
                 message.contains('no route to host')) {
        errorMsg = '网络不可用，请检查网络连接';
      } else if (message.contains('connection refused')) {
        errorMsg = '服务器拒绝连接';
      } else if (message.contains('connection reset') || 
                 message.contains('broken pipe')) {
        errorMsg = '网络连接已断开';
      }
      
      return UpdateCheckResult.failed(errorMsg);
    } on HttpException catch (e) {
      // HTTP错误
      return UpdateCheckResult.failed('网络请求失败: ${e.message}');
    } on FormatException catch (_) {
      // JSON解析错误
      return UpdateCheckResult.failed('数据格式错误');
    } on HandshakeException catch (_) {
      // SSL/TLS握手失败
      return UpdateCheckResult.failed('安全连接失败');
    } catch (e) {
      // 其他未知错误
      String errorMsg = '检查更新失败';
      
      // 尝试从错误信息中提取有用信息
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('socket')) {
        errorMsg = '网络连接失败，请检查网络';
      } else if (errorStr.contains('timeout')) {
        errorMsg = '连接超时，请检查网络';
      } else if (errorStr.contains('certificate') || errorStr.contains('ssl')) {
        errorMsg = '安全证书验证失败';
      }
      
      return UpdateCheckResult.failed(errorMsg);
    }
  }
}

