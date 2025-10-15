import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';
import 'update_service.dart';
import 'update_dialog.dart';
import 'weather_service.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  FabActionType _fabActionType = FabActionType.sync;
  bool _isCheckingUpdate = false;
  bool _isUsingCustomApi = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final fabType = await SettingsService.loadFabActionType();
    final useCustomApi = await SettingsService.isUsingCustomApi();
    setState(() {
      _fabActionType = fabType;
      _isUsingCustomApi = useCustomApi;
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

  /// 显示API配置底部弹窗
  Future<void> _showApiConfigDialog() async {
    final customApiKey = await SettingsService.loadCustomApiKey() ?? '';
    final customApiHost = await SettingsService.loadCustomApiHost() ?? '';
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _ApiConfigBottomSheet(
          initialApiKey: customApiKey,
          initialApiHost: customApiHost,
          isUsingCustomApi: _isUsingCustomApi,
          onSaved: () {
            _loadSettings();
          },
        );
      },
    );
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
          
          // API 配置
          ListTile(
            leading: Icon(
              Icons.api,
              color: colorScheme.primary,
            ),
            title: const Text('API 配置'),
            subtitle: Text(
              _isUsingCustomApi ? '当前：自定义配置' : '当前：默认配置',
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: _showApiConfigDialog,
          ),
          
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
        ],
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

/// API配置底部弹窗
class _ApiConfigBottomSheet extends StatefulWidget {
  final String initialApiKey;
  final String initialApiHost;
  final bool isUsingCustomApi;
  final VoidCallback onSaved;

  const _ApiConfigBottomSheet({
    required this.initialApiKey,
    required this.initialApiHost,
    required this.isUsingCustomApi,
    required this.onSaved,
  });

  @override
  State<_ApiConfigBottomSheet> createState() => _ApiConfigBottomSheetState();
}

class _ApiConfigBottomSheetState extends State<_ApiConfigBottomSheet> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiHostController;
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _apiHostController = TextEditingController(text: widget.initialApiHost);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiHostController.dispose();
    super.dispose();
  }

  /// 测试连通性
  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    final result = await WeatherService.testApiConnection(
      testApiKey: _apiKeyController.text.trim(),
      testApiHost: _apiHostController.text.trim(),
    );

    setState(() {
      _isTesting = false;
    });

    if (!mounted) return;

    _showTestResultDialog(
      success: result['success'] as bool,
      message: result['message'] as String,
    );
  }

  /// 显示测试结果对话框
  void _showTestResultDialog({
    required bool success,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: success ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(success ? '连接成功' : '连接失败'),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    final apiKey = _apiKeyController.text.trim();
    final apiHost = _apiHostController.text.trim();

    if (apiKey.isEmpty || apiHost.isEmpty) {
      _showErrorDialog('API Key 和 API Host 不能为空');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await SettingsService.saveCustomApiConfig(
        apiKey: apiKey,
        apiHost: apiHost,
      );
      
      // 清除缓存，强制重新加载配置
      WeatherService.clearCache();
      
      if (!mounted) return;
      
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('保存失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 恢复默认配置
  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认恢复'),
          content: const Text('确定要恢复到默认配置吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await SettingsService.resetToDefaultApi();
      
      // 清除缓存，强制重新加载配置
      WeatherService.clearCache();
      
      if (!mounted) return;
      
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('恢复失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('错误'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 打开API指南
  Future<void> _openApiGuide() async {
    final Uri url = Uri.parse('https://www.yuque.com/zaona/weather/api');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showErrorDialog('无法打开链接，请稍后重试');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('打开失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'API 配置',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isUsingCustomApi ? '当前为自定义配置' : '当前为默认配置',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 内容区域
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // API Key 输入框
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: '请输入和风天气 API Key',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // API Host 输入框
                  TextField(
                    controller: _apiHostController,
                    decoration: InputDecoration(
                      labelText: 'API Host',
                      hintText: '请输入和风天气 API Host',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.dns_rounded),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 测试连接按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isTesting || _isSaving ? null : _testConnection,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                      label: Text(_isTesting ? '测试中...' : '测试连接'),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isTesting || _isSaving ? null : _saveConfig,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? '保存中...' : '保存'),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 辅助功能按钮组
                  Row(
                    children: [
                      // 恢复默认
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _resetToDefault,
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: const Text('重置'),
                        ),
                      ),
                      
                      Container(
                        width: 1,
                        height: 20,
                        color: colorScheme.outlineVariant,
                      ),
                      
                      // 查看指南
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _openApiGuide,
                          icon: const Icon(Icons.help_outline_rounded, size: 18),
                          label: const Text('帮助'),
                        ),
                      ),
                    ],
                  ),
                  
                  // 底部安全区域
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

