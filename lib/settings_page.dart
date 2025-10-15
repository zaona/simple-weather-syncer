import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';
import 'update_service.dart';
import 'update_dialog.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  FabActionType _fabActionType = FabActionType.sync;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final fabType = await SettingsService.loadFabActionType();
    setState(() {
      _fabActionType = fabType;
    });
  }

  /// 保存 FAB 按钮类型设置
  Future<void> _saveFabActionType(FabActionType type) async {
    await SettingsService.saveFabActionType(type);
    setState(() {
      _fabActionType = type;
    });
  }

  /// 手动检查更新
  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    final result = await UpdateService.checkForUpdateManually();

    setState(() {
      _isCheckingUpdate = false;
    });

    if (!mounted) return;

    // 处理检查结果
    if (result.checkFailed) {
      // 检查失败 - 网络错误
      _showInfoDialog(
        title: '检查更新失败',
        message: result.errorMessage ?? '网络连接失败，请检查网络后重试',
        icon: Icons.wifi_off,
        iconColor: Colors.orange,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkForUpdate();
            },
            child: const Text('重试'),
          ),
        ],
      );
    } else if (result.hasUpdate && result.updateInfo != null) {
      // 有新版本，显示强制更新弹窗
      showForceUpdateDialog(context, result.updateInfo!);
    } else {
      // 已是最新版本
      _showInfoDialog(
        title: '已是最新版本',
        message: '当前已是最新版本，无需更新',
        icon: Icons.check_circle,
        iconColor: Colors.green,
      );
    }
  }

  /// 打开捐赠页面
  Future<void> _openDonationPage() async {
    final Uri url = Uri.parse('https://afdian.com/a/zaona');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showInfoDialog(
          title: '无法打开链接',
          message: '无法打开捐赠页面，请稍后重试',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showInfoDialog(
        title: '打开失败',
        message: '打开捐赠页面时出现错误：$e',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  /// 统一的提示对话框
  void _showInfoDialog({
    required String title,
    required String message,
    IconData? icon,
    Color? iconColor,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: actions ?? [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: colorScheme.surface,
      ),
      backgroundColor: colorScheme.surface,
      body: ListView(
        children: [
          // 常规设置分组
          _buildSectionHeader('常规', colorScheme),
          
          // FAB 按钮功能选择
          ListTile(
            leading: Icon(
              Icons.touch_app,
              color: colorScheme.primary,
            ),
            title: const Text('主页浮动按钮功能'),
            subtitle: Text(
              _fabActionType == FabActionType.sync
                  ? '当前：同步到手表'
                  : '当前：复制数据',
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showFabActionTypeDialog(),
          ),
          
          const Divider(height: 1, indent: 72),
          
          // 应用更新分组
          _buildSectionHeader('应用', colorScheme),
          
          // 检查更新
          ListTile(
            leading: Icon(
              Icons.system_update,
              color: colorScheme.primary,
            ),
            title: const Text('检查更新'),
            subtitle: const Text('检查是否有新版本可用'),
            trailing: _isCheckingUpdate
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
            onTap: _isCheckingUpdate ? null : _checkForUpdate,
          ),
          
          const Divider(height: 1, indent: 72),
          
          // 捐赠
          ListTile(
            leading: Icon(
              Icons.favorite,
              color: colorScheme.primary,
            ),
            title: const Text('捐赠'),
            subtitle: const Text('支持开发者持续更新'),
            trailing: Icon(
              Icons.open_in_new,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: _openDonationPage,
          ),
          
          const Divider(height: 1, indent: 72),
        ],
      ),
    );
  }

  /// 分组标题
  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 显示 FAB 按钮功能选择对话框
  void _showFabActionTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择浮动按钮功能'),
              contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              content: RadioGroup<FabActionType>(
                groupValue: _fabActionType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _fabActionType = value;
                    });
                    _saveFabActionType(value);
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<FabActionType>(
                      value: FabActionType.sync,
                      title: const Text('同步到手表'),
                      subtitle: const Text('点击按钮后将天气数据发送到手表'),
                      secondary: const Icon(Icons.watch),
                    ),
                    RadioListTile<FabActionType>(
                      value: FabActionType.copy,
                      title: const Text('复制数据'),
                      subtitle: const Text('点击按钮后将天气数据复制到剪贴板'),
                      secondary: const Icon(Icons.content_copy),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

