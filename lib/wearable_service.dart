import 'package:flutter/services.dart';

class WearableService {
  static const MethodChannel _channel = MethodChannel('wearable_message_channel');

  /// 获取已连接的设备
  static Future<String> getConnectedNodes() async {
    try {
      final String result = await _channel.invokeMethod('getConnectedNodes');
      return result;
    } on PlatformException catch (e) {
      throw Exception('获取连接设备失败: ${e.message}');
    }
  }

  /// 申请权限
  static Future<String> requestPermissions() async {
    try {
      final String result = await _channel.invokeMethod('requestPermissions');
      return result;
    } on PlatformException catch (e) {
      throw Exception('权限申请失败: ${e.message}');
    }
  }

  /// 发送消息到快应用
  static Future<String> sendMessage(String message) async {
    try {
      final String result = await _channel.invokeMethod('sendMessage', {'message': message});
      return result;
    } on PlatformException catch (e) {
      throw Exception('消息发送失败: ${e.message}');
    }
  }

  /// 开始监听消息
  static Future<String> startListening() async {
    try {
      final String result = await _channel.invokeMethod('startListening');
      return result;
    } on PlatformException catch (e) {
      throw Exception('开始监听失败: ${e.message}');
    }
  }

  /// 停止监听消息
  static Future<String> stopListening() async {
    try {
      final String result = await _channel.invokeMethod('stopListening');
      return result;
    } on PlatformException catch (e) {
      throw Exception('停止监听失败: ${e.message}');
    }
  }

  /// 检查小米穿戴应用是否安装
  static Future<String> checkWearableApp() async {
    try {
      final String result = await _channel.invokeMethod('checkWearableApp');
      return result;
    } on PlatformException catch (e) {
      throw Exception('检查应用失败: ${e.message}');
    }
  }

  /// 检查穿戴设备端快应用是否安装
  static Future<String> checkWearApp() async {
    try {
      final String result = await _channel.invokeMethod('checkWearApp');
      return result;
    } on PlatformException catch (e) {
      throw Exception('检查穿戴设备端应用失败: ${e.message}');
    }
  }

  /// 设置消息接收回调
  static void setMessageCallback(Function(String) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageReceived') {
        callback(call.arguments as String);
      }
    });
  }
}
