import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'weather_service.dart';
import 'weather_models.dart';
import 'wearable_service.dart';
import 'location_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLocating = false;
  String _errorMessage = '';
  
  List<CityLocation> _locations = [];
  List<CityLocation> _recentSearches = [];
  
  CityLocation? _selectedLocation;
  String _selectedForecastDays = '7d';
  
  WeatherData? _weatherData;
  bool _copied = false;
  
  // 标记是否通过定位获得的位置（用于UI显示）
  bool _isFromLocation = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载历史搜索
  Future<void> _loadRecentSearches() async {
    final searches = await WeatherService.loadRecentSearches();
    setState(() {
      _recentSearches = searches;
    });
  }

  /// 搜索城市
  Future<void> _searchLocation() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入城市名称';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _locations = [];
      _selectedLocation = null;
      _weatherData = null;
      _isFromLocation = false; // 清除定位标志
    });

    try {
      final locations = await WeatherService.searchLocation(_searchController.text);
      
      setState(() {
        _locations = locations;
        _isLoading = false;
      });

      // 如果只有一个结果，自动选择
      if (locations.length == 1) {
        _selectLocation(locations[0]);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// 选择城市
  Future<void> _selectLocation(CityLocation location) async {
    setState(() {
      _selectedLocation = location;
    });

    // 添加到历史搜索
    final updatedSearches = await WeatherService.addToRecentSearches(
      location,
      List.from(_recentSearches),
    );
    
    setState(() {
      _recentSearches = updatedSearches;
    });

    // 获取天气数据
    await _fetchWeather();
  }

  /// 选择历史城市
  Future<void> _selectRecentCity(CityLocation city) async {
    setState(() {
      _selectedLocation = city;
      _locations = [city];
    });
    await _fetchWeather();
  }

  /// 获取天气数据（统一使用城市ID查询）
  Future<void> _fetchWeather() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _weatherData = null;
      _copied = false;
    });

    try {
      // 统一使用城市LocationID查询天气
      final weatherData = await WeatherService.fetchWeather(
        _selectedLocation!.id,
        _selectedLocation!.name,
        _selectedForecastDays,
      );

      setState(() {
        _weatherData = weatherData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// 使用定位获取天气（整合方案：定位→反向地理编码→获取LocationID→查询天气）
  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = '';
      _weatherData = null;
      _selectedLocation = null;
      _locations = [];
      _isFromLocation = false;
    });

    // 显示定位提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
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
              Text('正在定位并查询城市信息...'),
            ],
          ),
          duration: const Duration(seconds: 20),
        ),
      );
    }

    try {
      // 步骤1：获取GPS定位（经纬度）
      final coordinates = await LocationService.getCurrentLocation();
      
      // 步骤2：通过反向地理编码获取城市信息（包含LocationID）
      final cityInfo = await WeatherService.getCityByCoordinates(coordinates);
      
      if (cityInfo == null) {
        throw Exception('无法获取该位置的城市信息，请尝试搜索城市名称');
      }

      // 步骤3：保存城市信息到_selectedLocation（统一数据模型）
      setState(() {
        _selectedLocation = cityInfo;
        _isFromLocation = true; // 标记为定位获得
        _isLocating = false;
      });

      // 步骤4：自动获取天气数据（统一使用LocationID）
      await _fetchWeather();
      
      if (mounted) {
        // 清除定位中的提示
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // 显示定位成功信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('定位成功: ${cityInfo.name} (${cityInfo.adm2}, ${cityInfo.adm1})'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 清除定位中的提示
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLocating = false;
      });
      
      // 如果是权限问题，显示更友好的提示
      if (e.toString().contains('永久拒绝')) {
        _showPermissionDeniedDialog();
      }
    }
  }

  /// 显示权限被永久拒绝对话框
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_off, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 8),
              const Text('需要位置权限'),
            ],
          ),
          content: const Text(
            '位置权限被永久拒绝，需要在系统设置中手动开启。\n\n'
            '请在设置中找到本应用，开启位置权限后重试。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await LocationService.openAppSettings();
              },
              child: const Text('打开设置'),
            ),
          ],
        );
      },
    );
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
      if (mounted) {
        _showCopyErrorDialog();
      }
    }
  }

  /// 直接发送到手表
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

  /// 显示复制错误对话框
  void _showCopyErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('复制失败'),
        content: const Text(
          '无法将天气数据复制到剪贴板。这可能是由于以下原因：\n\n'
          '1. 浏览器不支持剪贴板API\n'
          '2. 天气数据过长\n'
          '3. 浏览器安全限制\n\n'
          '请尝试更换浏览器或手动选择文本复制。'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('天气查询'),
        backgroundColor: colorScheme.surface,
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 提示信息
                _buildInfoCard(colorScheme),
                
                const SizedBox(height: 16),

                // 搜索卡片
                _buildSearchCard(colorScheme),

                // 历史搜索
                if (_recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRecentSearches(colorScheme),
                ],

                // 地区选择
                if (_locations.length > 1) ...[
                  const SizedBox(height: 16),
                  _buildLocationSelector(colorScheme),
                ],

                // 预报天数选择
                if (_selectedLocation != null) ...[
                  const SizedBox(height: 16),
                  _buildForecastDaysSelector(colorScheme),
                ],

                // 天气数据展示
                if (_weatherData != null) ...[
                  const SizedBox(height: 16),
                  _buildWeatherDataCard(colorScheme),
                ],

                // 错误信息
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(colorScheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 提示信息卡片
  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.secondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '使用说明',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoItem('可以使用当前位置自动定位', colorScheme),
            const SizedBox(height: 4),
            _buildInfoItem('也可以输入城市名称查询天气信息', colorScheme),
            const SizedBox(height: 4),
            _buildInfoItem('可以直接发送到已连接的手表', colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 6, color: colorScheme.secondary),
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

  /// 搜索卡片
  Widget _buildSearchCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '天气查询',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            
            // 定位按钮
            FilledButton.tonalIcon(
              onPressed: (_isLoading || _isLocating) ? null : _useCurrentLocation,
              icon: _isLocating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLocating ? '定位中...' : '使用当前位置'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 分隔线
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '或',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outline)),
              ],
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '请输入城市名称，例如：北京',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _searchLocation(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_isLoading || _isLocating) ? null : _searchLocation,
              icon: _isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isLoading ? '查询中...' : '查询'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 历史搜索
  Widget _buildRecentSearches(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '历史搜索',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((city) {
            return OutlinedButton(
              onPressed: () => _selectRecentCity(city),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                '${city.name} (${city.adm1} - ${city.adm2})',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 地区选择器
  Widget _buildLocationSelector(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择具体地区',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
                color: colorScheme.surfaceContainerLow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<CityLocation>(
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('请选择地区'),
                value: _selectedLocation,
                items: _locations.map((location) {
                  return DropdownMenuItem<CityLocation>(
                    value: location,
                    child: Text('${location.name} (${location.adm1} - ${location.adm2})'),
                  );
                }).toList(),
                onChanged: (location) {
                  if (location != null) {
                    _selectLocation(location);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 预报天数选择器
  Widget _buildForecastDaysSelector(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择预报天数',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
                color: colorScheme.surfaceContainerLow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                isExpanded: true,
                underline: const SizedBox(),
                value: _selectedForecastDays,
                items: const [
                  DropdownMenuItem(value: '3d', child: Text('3天预报')),
                  DropdownMenuItem(value: '7d', child: Text('7天预报')),
                  DropdownMenuItem(value: '10d', child: Text('10天预报')),
                  DropdownMenuItem(value: '15d', child: Text('15天预报')),
                  DropdownMenuItem(value: '30d', child: Text('30天预报')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedForecastDays = value;
                    });
                    // 如果已选择城市（包括定位获得的），则重新获取天气
                    if (_selectedLocation != null) {
                      _fetchWeather();
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 天气数据卡片
  Widget _buildWeatherDataCard(ColorScheme colorScheme) {
    if (_selectedLocation == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 如果是定位获得的，显示定位图标
                          if (_isFromLocation) ...[
                            Icon(
                              Icons.my_location,
                              size: 18,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              '${_selectedLocation!.name} 天气信息',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedLocation!.adm2}, ${_selectedLocation!.adm1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sendToWatch,
              icon: const Icon(Icons.send),
              label: const Text('发送到手表'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyWeatherData,
              icon: Icon(_copied ? Icons.check : Icons.copy),
              label: Text(_copied ? '已复制' : '复制数据'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _weatherData!.toJsonString(),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误信息卡片
  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  '错误信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _isLoading ? null : _searchLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: const Text('重试'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = '';
                    });
                  },
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

