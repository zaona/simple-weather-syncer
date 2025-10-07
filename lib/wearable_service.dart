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

  /// 检查小米运动健康应用是否安装
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

  /// 启动穿戴设备端快应用
  static Future<String> launchWearApp() async {
    try {
      final String result = await _channel.invokeMethod('launchWearApp');
      return result;
    } on PlatformException catch (e) {
      throw Exception('启动快应用失败: ${e.message}');
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

  /// 一键连接结果
  static Map<String, dynamic>? _lastConnectionResult;
  
  static Map<String, dynamic>? get lastConnectionResult => _lastConnectionResult;

  /// 一键连接 - 整合所有连接步骤
  static Future<Map<String, dynamic>> connectDevice() async {
    String currentStep = '';
    String errorMessage = '';
    String deviceId = '';
    
    try {
      // 步骤1: 检查小米运动健康应用
      currentStep = '检查小米运动健康应用';
      await checkWearableApp();
      
      // 步骤2: 获取连接设备
      currentStep = '获取连接设备';
      final nodeResult = await getConnectedNodes();
      // 从返回信息中提取设备ID
      if (nodeResult.contains('ID=')) {
        deviceId = nodeResult.split('ID=')[1].trim();
      }
      
      // 步骤3: 申请权限
      currentStep = '申请权限';
      await requestPermissions();
      
      // 步骤4: 检查穿戴设备端快应用（可能失败，不影响流程）
      currentStep = '检查穿戴设备端快应用';
      try {
        await checkWearApp();
      } catch (e) {
        // 快应用检查失败不影响连接成功
      }
      
      _lastConnectionResult = {
        'success': true,
        'step': '连接完成',
        'message': '设备连接成功',
        'deviceId': deviceId,
      };
      return _lastConnectionResult!;
    } catch (e) {
      errorMessage = e.toString();
      // 移除 "Exception: " 前缀
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      _lastConnectionResult = {
        'success': false,
        'step': currentStep,
        'message': errorMessage,
        'deviceId': '',
      };
      return _lastConnectionResult!;
    }
  }
}
