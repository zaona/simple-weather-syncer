import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'wearable_service.dart';
import 'pages/weather_page.dart';
import 'sdk_test_page.dart';
import 'services/update_service.dart';
import 'dialogs/update_dialog.dart';
import 'services/weather_service.dart';
import 'models/weather_models.dart';
import 'pages/settings_page.dart';
import 'services/settings_service.dart';
import 'pages/sponsorship_page.dart';

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

class _WearableCommunicationPageState extends State<WearableCommunicationPage> with WidgetsBindingObserver {
  bool _isConnecting = false;
  bool _isConnected = false;
  String _deviceId = '';
  String _deviceName = '';
  
  // 开发者模式相关
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  
  // 应用版本信息
  String _appVersion = 'v...'; // 默认显示加载中
  
  // 天气相关
  CityLocation? _selectedLocation;
  String _selectedForecastDays = '7d';
  bool _isFromLocation = false;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  bool _copied = false;
  
  // FAB 按钮设置
  FabActionType _fabActionType = FabActionType.sync;
  
  // 预检相关
  bool _isReadyReceived = false;
  
  // 兼容模式
  bool _compatibilityMode = false;

  @override
  void initState() {
    super.initState();
    
    // 添加生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    
    // 设置消息监听回调
    WearableService.setMessageCallback(_onMessageReceived);
    
    // 初始化各项功能
    _loadAppVersion();
    _autoConnect();
    _checkForUpdate(showError: true);
    _loadWeatherConfiguration();
    _loadFabActionType();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用恢复时，重新设置消息回调
    if (state == AppLifecycleState.resumed) {
      WearableService.setMessageCallback(_onMessageReceived);
    }
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

  /// 消息接收处理
  void _onMessageReceived(String message) {
    // 检查消息是否包含ready
    if (message.contains('ready')) {
      _isReadyReceived = true;
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
    
    final result = await UpdateService.checkForUpdateManually();
    
    if (!mounted) return;
    
    // 处理检查结果
    if (result.checkFailed) {
      // 检查失败 - 网络错误
      if (showError) {
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
                _checkForUpdate(
                  showLoading: showLoading,
                  showError: showError,
                  showNoUpdate: showNoUpdate,
                );
              },
              child: const Text('重试'),
            ),
          ],
        );
      }
    } else if (result.hasUpdate && result.updateInfo != null) {
      // 有新版本，显示强制更新弹窗
      showForceUpdateDialog(context, result.updateInfo!);
    } else {
      // 已是最新版本
      if (showNoUpdate) {
        _showInfoDialog(
          title: '已是最新版本',
          message: '当前已是最新版本，无需更新',
          icon: Icons.check_circle,
          iconColor: Colors.green,
        );
      }
    }
  }

  /// 自动连接设备
  Future<void> _autoConnect() async {
    // 自动连接设备
    await _connectDevice();
  }

  /// 加载天气配置（不自动获取天气数据）
  Future<void> _loadWeatherConfiguration() async {
    // 加载保存的位置配置
    final locationConfig = await WeatherService.loadSelectedLocation();
    final forecastDays = await WeatherService.loadForecastDays();
    
    if (locationConfig != null && mounted) {
      setState(() {
        _selectedLocation = locationConfig['location'];
        _isFromLocation = locationConfig['isFromLocation'];
        _selectedForecastDays = forecastDays;
      });
      
      // 不自动获取天气数据，等待用户主动点击按钮时再获取
    }
  }

  /// 获取天气数据
  Future<void> _fetchWeather() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherData = null;
    });

    try {
      final weatherData = await WeatherService.fetchWeather(
        _selectedLocation!.id,
        _selectedLocation!.name,
        _selectedForecastDays,
      );

      setState(() {
        _weatherData = weatherData;
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
      });
      
      // 显示错误弹窗
      if (mounted) {
        _showInfoDialog(
          title: '获取失败',
          message: e.toString().replaceFirst('Exception: ', ''),
          icon: Icons.cloud_off,
          iconColor: Theme.of(context).colorScheme.error,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _fetchWeather();
              },
              child: const Text('重试'),
            ),
          ],
        );
      }
    }
  }

  /// 发送天气数据到手表
  Future<void> _sendToWatch() async {
    // 先获取最新的天气数据
    await _fetchWeather();
    
    // 如果获取失败，_fetchWeather已经显示错误提示，直接返回
    if (_weatherData == null) return;

    // 兼容模式：直接发送数据
    if (_compatibilityMode) {
      await _sendWeatherDataDirectly();
      return;
    }

    // 标准模式：使用预检握手流程
    await _sendWeatherDataWithHandshake();
  }

  /// 兼容模式：直接发送数据
  Future<void> _sendWeatherDataDirectly() async {
    // 在发送前临时注册监听
    WearableService.setMessageCallback(_onMessageReceived);
    try {
      await WearableService.startListening();
    } catch (e) {
      // 忽略已在监听等错误
    }

    // 显示进度对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在发送数据...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 直接发送天气数据
      await WearableService.sendMessage(_weatherData!.toJsonString());
      
      // 关闭进度对话框
      if (mounted) Navigator.of(context).pop();
      
      // 显示成功提示
      if (mounted) {
        _showInfoDialog(
          title: '发送成功',
          message: '天气数据已发送',
          icon: Icons.check_circle,
          iconColor: Colors.green,
        );
      }
    } catch (e) {
      // 关闭进度对话框
      if (mounted) Navigator.of(context).pop();
      
      // 显示错误提示
      if (mounted) {
        _showInfoDialog(
          title: '发送失败',
          message: e.toString().replaceFirst('Exception: ', ''),
          icon: Icons.error_outline,
          iconColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      // 发送完成后注销监听
      try {
        await WearableService.stopListening();
      } catch (e) {
        // 忽略停止监听失败：可能监听未启动或已被系统回收
      }
    }
  }

  /// 标准模式：使用预检握手流程
  Future<void> _sendWeatherDataWithHandshake() async {
    // 显示进度对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在同步数据...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 重新设置消息监听回调（防止被其他页面覆盖）
      WearableService.setMessageCallback(_onMessageReceived);
      
      // 确保消息监听已启动（异步完成后即可用）
      try {
        await WearableService.startListening();
      } catch (e) {
        // 监听服务可能已经启动，忽略错误
      }
      
      // 重置ready标志并启动快应用
      _isReadyReceived = false;
      await WearableService.launchWearApp();
      
      // 预检握手流程（高频握手自动处理启动等待）
      const sendInterval = Duration(milliseconds: 600);
      const checkInterval = Duration(milliseconds: 50);
      const maxAttempts = 15;
      int attempts = 0;
      
      while (attempts < maxAttempts && !_isReadyReceived) {
        attempts++;
        
        try {
          await WearableService.sendMessage('start');
        } catch (e) {
          // 发送失败，继续尝试
        }
        
        // 频繁检查ready响应
        final checksPerSecond = sendInterval.inMilliseconds ~/ checkInterval.inMilliseconds;
        for (int i = 0; i < checksPerSecond && !_isReadyReceived; i++) {
          await Future.delayed(checkInterval);
          if (_isReadyReceived) break;
        }
        
        if (_isReadyReceived) break;
      }
      
      // 检查是否成功收到ready消息
      if (!_isReadyReceived) {
        throw Exception('手表应用未响应');
      }
      
      // 发送天气数据（收到ready后立即发送）
      await WearableService.sendMessage(_weatherData!.toJsonString());
      
      // 关闭进度对话框
      if (mounted) Navigator.of(context).pop();
      
      // 显示成功提示
      if (mounted) {
        _showInfoDialog(
          title: '发送成功',
          message: '天气数据已成功同步到手表',
          icon: Icons.check_circle,
          iconColor: Colors.green,
        );
      }
    } catch (e) {
      // 关闭进度对话框
      if (mounted) Navigator.of(context).pop();
      
      // 显示错误提示
      if (mounted) {
        _showInfoDialog(
          title: '发送失败',
          message: e.toString().replaceFirst('Exception: ', ''),
          icon: Icons.error_outline,
          iconColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      // 无论成功或失败，发送流程结束后注销监听
      try {
        await WearableService.stopListening();
      } catch (e) {
        // 忽略停止监听失败：可能监听未启动或已被系统回收
      }
    }
  }

  /// 复制天气数据
  Future<void> _copyWeatherData() async {
    // 先获取最新的天气数据
    await _fetchWeather();
    
    // 如果获取失败，_fetchWeather已经显示错误提示，直接返回
    if (_weatherData == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _weatherData!.toJsonString()));
      setState(() {
        _copied = true;
      });
      
      if (mounted) {
        _showInfoDialog(
          title: '复制成功',
          message: '天气数据已复制到剪贴板',
          icon: Icons.check_circle,
          iconColor: Colors.green,
        );
      }

      // 2秒后重置复制状态
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    } catch (e) {
      // 复制失败静默处理
    }
  }

  /// 打开配置页面
  Future<void> _openWeatherConfig() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WeatherPage()),
    );
    
    // 如果配置有更新，重新加载
    if (result == true && mounted) {
      await _loadWeatherConfiguration();
    }
  }

  /// 打开设置页面
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
    
    // 设置页面关闭后重新加载 FAB 设置
    if (mounted) {
      await _loadFabActionType();
    }
  }

  /// 打开赞助页面
  Future<void> _openSponsorship() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SponsorshipPage()),
    );
  }

  /// 加载 FAB 按钮设置和兼容模式
  Future<void> _loadFabActionType() async {
    final fabType = await SettingsService.loadFabActionType();
    final compatibilityMode = await SettingsService.loadCompatibilityMode();
    if (mounted) {
      setState(() {
        _fabActionType = fabType;
        _compatibilityMode = compatibilityMode;
      });
    }
  }

  @override
  void dispose() {
    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    // 停止消息监听，避免泄漏
    WearableService.stopListening();
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
      final hints = result.hints;
      final details = result.details;
      final retryable = result.retryable;
       
      if (mounted) {
        if (result.success) {
          final node = result.node;
          setState(() {
            _isConnected = true;
            _deviceId = node?.id ?? '';
            _deviceName = node?.name ?? '';
          });
          
          final baseMessage = result.message.isNotEmpty ? result.message : '设备已成功连接';
          final successMessage = hints.isEmpty
              ? baseMessage
              : '$baseMessage\n\n建议：\n${hints.map((hint) => '• $hint').join('\n')}';
          _showInfoDialog(
            title: '连接成功',
            message: successMessage,
            icon: Icons.check_circle,
            iconColor: Colors.green,
          );
        } else {
          setState(() {
            _isConnected = false;
            _deviceId = '';
            _deviceName = '';
          });
          
          final failedStep = result.step.isNotEmpty ? result.step : '未知步骤';
          final errorMessage = result.message.isNotEmpty ? result.message : '请稍后重试';
          _showErrorDialog(
            failedStep,
            errorMessage,
            hints: hints,
            details: details,
            retryable: retryable,
          );
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
    
    if (_versionTapCount >= requiredTaps) {
      // 重置计数
      setState(() {
        _versionTapCount = 0;
        _lastTapTime = null;
      });
      
      // 直接打开SDK测试页面
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SdkTestPage(),
          ),
        );
      }
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

  /// 显示错误对话框
  void _showErrorDialog(String failedStep, String errorMessage, {
    List<String> hints = const <String>[],
    String? details,
    bool retryable = true,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final hasDetails = details != null && details.isNotEmpty;
        final hasHints = hints.isNotEmpty;
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
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 15),
              ),
              if (hasDetails) ...[
                const SizedBox(height: 16),
                const Text(
                  '详细信息：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              if (hasHints) ...[
                const SizedBox(height: 16),
                const Text(
                  '建议：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                ...hints.map(
                  (hint) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $hint', style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
            if (retryable)
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
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16.0,
                    16.0,
                    16.0,
                    _weatherData != null ? 0 : 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, top: 8.0, left: 4.0),
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
                      // 赞助按钮
                      IconButton(
                        onPressed: _openSponsorship,
                        icon: const Icon(Icons.favorite),
                        tooltip: '赞助支持',
                        iconSize: 26,
                        color: colorScheme.primary,
                      ),
                      // 设置按钮
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings),
                        tooltip: '设置',
                        iconSize: 26,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // 设备连接卡片（重构版）
                _buildDeviceCard(colorScheme),
                
                // 天气卡片（统一：未配置/加载中/已配置）
                const SizedBox(height: 8),
                _buildWeatherDataCard(colorScheme),
                
                // 底部留白（当有 FAB 时）
                if (_selectedLocation != null && !_isLoadingWeather) const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // FloatingActionButton（仅在配置了位置且非加载时显示）
      floatingActionButton: (_selectedLocation != null && !_isLoadingWeather)
          ? _buildFab(colorScheme)
          : null,
    );
  }

  /// 设备连接卡片（统一设计）
  Widget _buildDeviceCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 图标或加载指示器
            if (_isConnecting)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.watch,
                size: 24,
                color: colorScheme.primary,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isConnected ? '已连接设备' : '未连接设备',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isConnected
                        ? (_deviceName.isNotEmpty ? _deviceName : _deviceId)
                        : '启动时自动连接',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 右侧刷新按钮（连接中时隐藏）
            if (!_isConnecting)
              IconButton(
                onPressed: _connectDevice,
                icon: const Icon(Icons.refresh),
                tooltip: '重新连接设备',
                iconSize: 22,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// 天气数据卡片（统一：未配置/加载中/已配置）
  Widget _buildWeatherDataCard(ColorScheme colorScheme) {
    // 判断当前状态
    final bool isNotConfigured = _selectedLocation == null && !_isLoadingWeather;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 图标：未配置/加载/已配置
            if (_isLoadingWeather)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              )
            else if (isNotConfigured)
              Icon(
                Icons.cloud_queue,
                size: 24,
                color: colorScheme.primary,
              )
            else
              Icon(
                _isFromLocation ? Icons.my_location : Icons.location_city,
                size: 24,
                color: colorScheme.primary,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoadingWeather 
                        ? '正在获取天气数据' 
                        : isNotConfigured
                            ? '未配置天气'
                            : _selectedLocation!.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingWeather 
                        ? '请稍候...'
                        : isNotConfigured
                            ? '点击右侧按钮配置位置和天数'
                            : '${_selectedLocation!.adm2}, ${_selectedLocation!.adm1} · ${_selectedForecastDays.replaceAll('d', '天')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 配置/修改按钮（仅在非加载状态显示）
            if (!_isLoadingWeather)
              IconButton(
                onPressed: _openWeatherConfig,
                icon: Icon(isNotConfigured ? Icons.add_circle_outline : Icons.edit_outlined),
                tooltip: isNotConfigured ? '配置天气' : '修改配置',
                iconSize: 22,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// FloatingActionButton（根据设置显示不同功能）
  Widget _buildFab(ColorScheme colorScheme) {
    final isSyncMode = _fabActionType == FabActionType.sync;
    
    return FloatingActionButton.extended(
      onPressed: isSyncMode ? _sendToWatch : _copyWeatherData,
      icon: Icon(
        isSyncMode 
            ? Icons.send 
            : (_copied ? Icons.check : Icons.content_copy),
        size: 20,
      ),
      label: Text(
        isSyncMode 
            ? '同步' 
            : (_copied ? '已复制' : '复制'),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevation: 4,
      backgroundColor: isSyncMode 
          ? colorScheme.primaryContainer 
          : (_copied ? colorScheme.tertiaryContainer : colorScheme.secondaryContainer),
      foregroundColor: isSyncMode 
          ? colorScheme.onPrimaryContainer 
          : (_copied ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer),
    );
  }

}
