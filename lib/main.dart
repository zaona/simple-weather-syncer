import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'wearable_service.dart';
import 'weather_page.dart';
import 'sdk_test_page.dart';
import 'update_service.dart';
import 'update_dialog.dart';
import 'weather_service.dart';
import 'weather_models.dart';

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
  String _weatherError = '';
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    
    // 获取应用版本信息
    _loadAppVersion();
    
    // 自动启动连接和监听
    _autoConnect();
    
    // 检查应用更新（显示网络错误提示，但不显示无更新提示）
    _checkForUpdate(showError: true);
    
    // 加载天气配置并获取天气数据
    _loadWeatherConfiguration();
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

  /// 加载天气配置并获取天气数据
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
      
      // 自动获取天气数据
      await _fetchWeather();
    }
  }

  /// 获取天气数据
  Future<void> _fetchWeather() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherError = '';
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
        _weatherError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingWeather = false;
      });
    }
  }

  /// 发送天气数据到手表
  Future<void> _sendToWatch() async {
    if (_weatherData == null) return;

    try {
      // 先启动快应用
      await WearableService.launchWearApp();
      
      // 等待一小段时间确保快应用已启动
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 再发送消息
      await WearableService.sendMessage(_weatherData!.toJsonString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('天气数据已发送到手表'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 复制天气数据
  Future<void> _copyWeatherData() async {
    if (_weatherData == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _weatherData!.toJsonString()));
      setState(() {
        _copied = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已复制到剪贴板'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
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
                
                // 设备连接卡片（重构版）
                _buildDeviceCard(colorScheme),
                
                // 天气卡片（统一：未配置/加载中/已配置）
                const SizedBox(height: 12),
                _buildWeatherDataCard(colorScheme),
                
                // 天气错误信息
                if (_weatherError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildWeatherErrorCard(colorScheme),
                ],
                
                // 底部留白（当有底部按钮时）
                if (_weatherData != null && !_isLoadingWeather) const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 底部操作按钮（仅在有天气数据且非加载时显示）
          if (_weatherData != null && !_isLoadingWeather) _buildWeatherActions(colorScheme),
        ],
      ),
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
            // 右侧刷新按钮（仅未连接时显示）
            if (!_isConnecting && !_isConnected)
              IconButton(
                onPressed: _connectDevice,
                icon: const Icon(Icons.refresh),
                tooltip: '连接设备',
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

  /// 天气操作按钮（底部固定）
  Widget _buildWeatherActions(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _sendToWatch,
                icon: const Icon(Icons.send, size: 20),
                label: const Text('发送到手表'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _copyWeatherData,
                icon: Icon(
                  _copied ? Icons.check : Icons.content_copy,
                  size: 18,
                ),
                label: Text(_copied ? '已复制' : '复制'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: _copied ? colorScheme.primary : colorScheme.outline,
                    width: _copied ? 2 : 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 天气错误卡片（统一设计）
  Widget _buildWeatherErrorCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.error.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: 24,
              color: colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '获取失败',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _weatherError,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 重试按钮
            IconButton(
              onPressed: _fetchWeather,
              icon: const Icon(Icons.refresh),
              tooltip: '重试',
              iconSize: 22,
              color: colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

}
