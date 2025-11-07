import 'package:shared_preferences/shared_preferences.dart';

/// FAB 按钮动作类型
enum FabActionType {
  sync,  // 同步到手表
  copy,  // 复制数据
}

/// 设置服务类，用于保存和读取用户设置
class SettingsService {
  // SharedPreferences 键
  static const String _fabActionTypeKey = 'fab_action_type';
  static const String _customApiKeyKey = 'custom_api_key';
  static const String _customApiHostKey = 'custom_api_host';
  static const String _useCustomApiKey = 'use_custom_api';
  static const String _compatibilityModeKey = 'compatibility_mode';
  
  /// 保存 FAB 按钮动作类型
  static Future<void> saveFabActionType(FabActionType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fabActionTypeKey, type.name);
  }
  
  /// 读取 FAB 按钮动作类型，默认为同步
  static Future<FabActionType> loadFabActionType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeString = prefs.getString(_fabActionTypeKey);
    
    if (typeString == null) {
      return FabActionType.sync; // 默认为同步
    }
    
    return FabActionType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => FabActionType.sync,
    );
  }
  
  /// 保存自定义 API 配置
  static Future<void> saveCustomApiConfig({
    required String apiKey,
    required String apiHost,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customApiKeyKey, apiKey);
    await prefs.setString(_customApiHostKey, apiHost);
    await prefs.setBool(_useCustomApiKey, true);
  }
  
  /// 读取自定义 API Key
  static Future<String?> loadCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customApiKeyKey);
  }
  
  /// 读取自定义 API Host
  static Future<String?> loadCustomApiHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customApiHostKey);
  }
  
  /// 检查是否使用自定义 API 配置
  static Future<bool> isUsingCustomApi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useCustomApiKey) ?? false;
  }
  
  /// 恢复默认 API 配置
  static Future<void> resetToDefaultApi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customApiKeyKey);
    await prefs.remove(_customApiHostKey);
    await prefs.remove(_useCustomApiKey);
  }
  
  /// 保存兼容模式设置
  static Future<void> saveCompatibilityMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compatibilityModeKey, enabled);
  }
  
  /// 读取兼容模式设置，默认为开启
  static Future<bool> loadCompatibilityMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_compatibilityModeKey) ?? true;
  }
}

