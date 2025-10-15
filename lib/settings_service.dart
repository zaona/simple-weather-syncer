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
}

