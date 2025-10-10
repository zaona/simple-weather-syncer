import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'wearable_service.dart';
import 'weather_page.dart';
import 'sdk_test_page.dart';
import 'update_service.dart';
import 'update_dialog.dart';

Future<void> main() async {
  // 加载环境变量
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // 使用系统动态配色（莫奈主题）
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // 降级方案：使用默认蓝色主题
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: '简明天气同步器',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const WearableCommunicationPage(),
        );
      },
    );
  }
}

class WearableCommunicationPage extends StatefulWidget {
  const WearableCommunicationPage({super.key});

  @override
  State<WearableCommunicationPage> createState() => _WearableCommunicationPageState();
}

class _WearableCommunicationPageState extends State<WearableCommunicationPage> {
  String _receivedMessage = '';
  bool _isConnecting = false;
  bool _isConnected = false;
  String _deviceId = '';
  String _deviceName = '';
  
  // 开发者模式相关
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  
  // 应用版本信息
  String _appVersion = 'v...'; // 默认显示加载中

  @override
  void initState() {
    super.initState();
    // 设置消息接收回调
    WearableService.setMessageCallback((message) {
      setState(() {
        _receivedMessage = message;
      });
    });
    
    // 获取应用版本信息
    _loadAppVersion();
    
    // 自动启动连接和监听
    _autoConnect();
    
    // 检查应用更新（显示网络错误提示，但不显示无更新提示）
    _checkForUpdate(showError: true);
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    final version = await UpdateService.getVersionName();
    if (mounted) {
      setState(() {
        _appVersion = 'v$version';
      });
    }
  }

  /// 统一的更新检查方法
  /// [showLoading] 是否显示加载提示
  /// [showError] 是否显示网络错误提示
  /// [showNoUpdate] 是否显示无更新提示
  Future<void> _checkForUpdate({
    bool showLoading = false,
    bool showError = false,
    bool showNoUpdate = false,
  }) async {
    if (!mounted) return;
    
    // 显示加载提示
    if (showLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('正在检查更新...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final result = await UpdateService.checkForUpdateManually();
    
    if (!mounted) return;
    
    // 清除加载提示
    if (showLoading) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    
    // 处理检查结果
    if (result.checkFailed) {
      // 检查失败 - 网络错误
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(result.errorMessage ?? '网络连接失败'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () => _checkForUpdate(
                showLoading: showLoading,
                showError: showError,
                showNoUpdate: showNoUpdate,
              ),
            ),
          ),
        );
      }
    } else if (result.hasUpdate && result.updateInfo != null) {
      // 有新版本，显示强制更新弹窗
      showForceUpdateDialog(context, result.updateInfo!);
    } else {
      // 已是最新版本
      if (showNoUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('已是最新版本'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 自动连接设备
  Future<void> _autoConnect() async {
    // 自动开始监听
    try {
      await WearableService.startListening();
    } catch (e) {
      // 监听失败不影响主流程
    }
    
    // 自动连接设备
    await _connectDevice();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 一键连接设备
  Future<void> _connectDevice() async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
    });

    try {
      final result = await WearableService.connectDevice();
      
      if (mounted) {
        if (result['success']) {
          // 连接成功，保存设备信息
          setState(() {
            _isConnected = true;
            _deviceId = result['deviceId'] ?? '';
            _deviceName = result['deviceName'] ?? '';
          });
          
          // 显示SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('设备连接成功'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // 连接失败，清除设备信息
          setState(() {
            _isConnected = false;
            _deviceId = '';
            _deviceName = '';
          });
          
          // 显示详细的错误对话框
          _showErrorDialog(result['step'], result['message']);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  /// 处理版本号点击 - 开发者模式入口
  void _onVersionTap() {
    final now = DateTime.now();
    
    // 如果距离上次点击超过2秒，重置计数
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _versionTapCount = 0;
    }
    
    setState(() {
      _versionTapCount++;
      _lastTapTime = now;
    });
    
    // 需要连续点击7次
    const requiredTaps = 7;
    final remaining = requiredTaps - _versionTapCount;
    
    if (_versionTapCount >= requiredTaps) {
      // 重置计数
      setState(() {
        _versionTapCount = 0;
        _lastTapTime = null;
      });
      
      // 显示成功提示并打开SDK测试页面
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔓 开发者模式已激活'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
      
      // 短暂延迟后打开页面
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SdkTestPage(),
            ),
          );
        }
      });
    } else if (_versionTapCount >= 3) {
      // 点击3次后开始显示提示
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('再点击 $remaining 次进入开发者模式'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(String failedStep, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 8),
              const Text('连接失败'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '失败步骤：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                failedStep,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 15),
              ),
              const SizedBox(height: 16),
              const Text(
                '失败原因：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _connectDevice();
              },
              child: const Text('重试'),
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
      backgroundColor: colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const WeatherPage()),
          );
        },
        icon: const Icon(Icons.cloud),
        label: const Text('查询天气'),
        tooltip: '查询天气',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '简明天气同步器',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            GestureDetector(
                              onTap: _onVersionTap,
                              child: Text(
                                _appVersion,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 手动检查更新按钮
                      IconButton(
                        onPressed: () => _checkForUpdate(
                          showLoading: true,
                          showError: true,
                          showNoUpdate: true,
                        ),
                        icon: const Icon(Icons.system_update),
                        tooltip: '检查更新',
                        iconSize: 26,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                
                // 主功能卡片
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 已连接设备信息
                        if (_isConnected && _deviceId.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.watch,
                                  color: colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '已连接设备',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _deviceName.isNotEmpty ? _deviceName : _deviceId,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      if (_deviceName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _deviceId,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isConnecting ? null : _connectDevice,
                                  icon: _isConnecting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : const Icon(Icons.refresh),
                                  tooltip: '刷新设备',
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // 未连接时显示连接按钮
                        if (!_isConnected) ...[
                          Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: FilledButton.icon(
                              onPressed: _isConnecting ? null : _connectDevice,
                              icon: _isConnecting 
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.link),
                              label: Text(_isConnecting ? '连接中...' : '连接设备'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // 收到的消息卡片
                if (_receivedMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.message_outlined,
                                color: colorScheme.tertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '收到消息',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _receivedMessage,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // 使用说明卡片
                Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: colorScheme.secondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '提示',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInfoItem('启动时自动连接设备', colorScheme),
                        const SizedBox(height: 4),
                        _buildInfoItem('使用天气查询功能可直接发送天气数据到手表', colorScheme),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
