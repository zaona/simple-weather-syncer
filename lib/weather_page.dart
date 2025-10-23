import 'package:flutter/material.dart';
import 'weather_service.dart';
import 'weather_models.dart';
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
  
  List<CityLocation> _recentSearches = [];
  List<CityLocation> _recentLocations = []; // 最近定位的位置
  
  CityLocation? _selectedLocation;
  String _selectedForecastDays = '7d';
  
  // 标记是否通过定位获得的位置（用于UI显示）
  bool _isFromLocation = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadRecentLocations();
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

  /// 加载最近定位的位置
  Future<void> _loadRecentLocations() async {
    final locations = await WeatherService.loadRecentLocations();
    setState(() {
      _recentLocations = locations;
    });
  }

  /// 搜索城市
  Future<void> _searchLocation() async {
    if (_searchController.text.trim().isEmpty) {
      _showInfoDialog(
        title: '提示',
        message: '请输入城市名称',
        icon: Icons.info_outline,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedLocation = null;
      _isFromLocation = false; // 清除定位标志
    });

    try {
      final locations = await WeatherService.searchLocation(_searchController.text);
      
      setState(() {
        _isLoading = false;
      });

      // 如果只有一个结果，自动选择
      if (locations.length == 1) {
        _selectLocation(locations[0]);
      } else if (locations.length > 1) {
        // 多个结果时显示选择对话框
        _showLocationPickerDialog(locations);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // 显示错误弹窗
      if (mounted) {
        _showInfoDialog(
          title: '搜索失败',
          message: e.toString().replaceFirst('Exception: ', ''),
          icon: Icons.error_outline,
          iconColor: Theme.of(context).colorScheme.error,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _searchLocation();
              },
              child: const Text('重试'),
            ),
          ],
        );
      }
    }
  }

  /// 显示地区选择对话框
  void _showLocationPickerDialog(List<CityLocation> locations) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '请选择具体地区',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${location.adm2}, ${location.adm1}',
                    style: TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectLocation(location);
                  },
                );
              },
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
  }

  /// 选择城市
  Future<void> _selectLocation(CityLocation location) async {
    setState(() {
      _selectedLocation = location;
      _isFromLocation = false; // 通过搜索选择的城市
    });

    // 添加到历史搜索
    final updatedSearches = await WeatherService.addToRecentSearches(
      location,
      List.from(_recentSearches),
    );
    
    setState(() {
      _recentSearches = updatedSearches;
    });

    // 不立即保存，让用户选择预报天数
  }


  /// 保存配置并返回首页
  Future<void> _saveConfiguration() async {
    if (_selectedLocation == null) return;

    // 保存位置和预报天数配置
    await WeatherService.saveSelectedLocation(_selectedLocation!, _isFromLocation);
    await WeatherService.saveForecastDays(_selectedForecastDays);

    if (mounted) {
      // 直接返回首页
      Navigator.of(context).pop(true); // 返回true表示配置已更新
    }
  }

  /// 使用定位获取天气（整合方案：定位→反向地理编码→获取LocationID→查询天气）
  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _selectedLocation = null;
      _isFromLocation = false;
    });

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

      // 步骤4：添加到定位历史
      final updatedLocations = await WeatherService.addToRecentLocations(
        cityInfo,
        List.from(_recentLocations),
      );
      
      setState(() {
        _recentLocations = updatedLocations;
      });

      if (mounted) {
        // 显示定位成功弹窗
        _showInfoDialog(
          title: '定位成功',
          message: '${cityInfo.name} (${cityInfo.adm2}, ${cityInfo.adm1})',
          icon: Icons.location_on,
          iconColor: Colors.green,
        );
      }
      
      // 不立即保存，让用户选择预报天数
    } catch (e) {
      setState(() {
        _isLocating = false;
      });
      
      // 如果是权限问题，显示权限对话框，否则显示通用错误
      if (mounted) {
        if (e.toString().contains('永久拒绝')) {
          _showPermissionDeniedDialog();
        } else {
          _showInfoDialog(
            title: '定位失败',
            message: e.toString().replaceFirst('Exception: ', ''),
            icon: Icons.error_outline,
            iconColor: Theme.of(context).colorScheme.error,
          );
        }
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


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('配置天气'),
        backgroundColor: colorScheme.surface,
      ),
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20.0,
                20.0,
                20.0,
                _selectedLocation != null ? 88.0 : 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 定位按钮
                  FilledButton.tonalIcon(
                    onPressed: (_isLoading || _isLocating) ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 24),
                    label: Text(_isLocating ? '定位中...' : '使用当前位置'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 搜索框
                  _buildSearchBox(colorScheme),
                  
                  // 历史记录（合并定位和搜索）
                  if (_recentLocations.isNotEmpty || _recentSearches.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildRecentHistory(colorScheme),
                  ],
                  
                  // 预报天数选择
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 24),
                    _buildForecastDaysSelector(colorScheme),
                  ],
                ],
              ),
            ),
          ),
          // 底部保存按钮
          if (_selectedLocation != null) _buildSaveButton(colorScheme),
        ],
      ),
    );
  }

  /// 搜索框（Material 3 标准组件）
  Widget _buildSearchBox(ColorScheme colorScheme) {
    return SearchBar(
      controller: _searchController,
      hintText: '或搜索城市，如：北京',
      leading: Icon(
        Icons.search,
        color: colorScheme.onSurfaceVariant,
      ),
      trailing: [
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
          )
        else if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
            },
            tooltip: '清除',
          ),
      ],
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: _searchController.text.isNotEmpty
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 15,
          color: colorScheme.onSurface,
        ),
      ),
      hintStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 15,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      onSubmitted: (_) => _searchLocation(),
      onChanged: (value) => setState(() {}),
    );
  }


  /// 历史记录（合并定位和搜索）
  Widget _buildRecentHistory(ColorScheme colorScheme) {
    // 合并历史记录并去重
    final allHistory = <CityLocation>[];
    final seenIds = <String>{};
    
    // 先添加最近定位（优先级高）
    for (var location in _recentLocations) {
      if (!seenIds.contains(location.id)) {
        allHistory.add(location);
        seenIds.add(location.id);
      }
    }
    
    // 再添加最近搜索
    for (var search in _recentSearches) {
      if (!seenIds.contains(search.id)) {
        allHistory.add(search);
        seenIds.add(search.id);
      }
    }
    
    // 限制最多显示8个
    final displayHistory = allHistory.take(8).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '历史记录',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 1,
          children: displayHistory.map((city) {
            // 判断是定位还是搜索
            final isFromLocation = _recentLocations.any((loc) => loc.id == city.id);
            
            return ActionChip(
              avatar: Icon(
                isFromLocation ? Icons.my_location : Icons.location_city,
                size: 18,
                color: colorScheme.primary,
              ),
              label: Text(
                city.name,
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () {
                setState(() {
                  _selectedLocation = city;
                  _isFromLocation = isFromLocation;
                });
              },
              backgroundColor: colorScheme.surfaceContainerHighest,
            );
          }).toList(),
        ),
      ],
    );
  }


  /// 预报天数选择器（优化：使用SegmentedButton）
  Widget _buildForecastDaysSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '预报天数',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '3d', label: Text('3天')),
              ButtonSegment(value: '7d', label: Text('7天')),
              ButtonSegment(value: '10d', label: Text('10天')),
              ButtonSegment(value: '15d', label: Text('15天')),
              ButtonSegment(value: '30d', label: Text('30天')),
            ],
            selected: {_selectedForecastDays},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedForecastDays = newSelection.first;
              });
              // 只更新状态，不保存
            },
          ),
        ),
      ],
    );
  }

  /// 底部保存按钮
  Widget _buildSaveButton(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20.0),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saveConfiguration,
            icon: const Icon(Icons.check, size: 22),
            label: Text('保存并返回 - ${_selectedLocation!.name} (${_selectedForecastDays.replaceAll('d', '天')})'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

