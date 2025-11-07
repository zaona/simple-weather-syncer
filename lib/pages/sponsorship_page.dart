import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sponsorship_models.dart';
import '../services/sponsorship_service.dart';

/// 赞助页面
class SponsorshipPage extends StatefulWidget {
  const SponsorshipPage({super.key});

  @override
  State<SponsorshipPage> createState() => _SponsorshipPageState();
}

class _SponsorshipPageState extends State<SponsorshipPage> {
  List<Sponsor> _sponsors = const [];
  bool _isLoadingSponsors = false;

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  /// 加载赞助者数据
  Future<void> _loadSponsors() async {
    setState(() => _isLoadingSponsors = true);

    final sponsors = await SponsorshipService.fetchSponsors();

    if (!mounted) return;

    setState(() {
      _sponsors = sponsors;
      _isLoadingSponsors = false;
    });
  }

  /// 打开赞助页面
  Future<void> _openDonationPage() async {
    final Uri url = Uri.parse('https://afdian.com/a/zaona');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showErrorDialog('无法打开赞助页面，请稍后重试');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('打开失败：$e');
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('赞助支持'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 主要内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 赞助卡片 - 使用MD3的Card组件
                    Card(
                      elevation: 0,
                      color: colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // 图标
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 32,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 标题
                            Text(
                              '支持项目发展',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // 副标题
                            Text(
                              '您的支持是我们持续改进的动力',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // 赞助按钮
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openDonationPage,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new, size: 20),
                                label: const Text('前往赞助'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 特别鸣谢部分
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '特别鸣谢',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 特别鸣谢列表
                          Column(
                            children: [
                              _buildSpecialThanksItem(
                                context,
                                'WaiJade',
                                '为快应用与同步器插件贡献代码',
                              ),
                              const SizedBox(height: 12),
                              _buildSpecialThanksItem(
                                context,
                                'xinghengCN',
                                '为作者提供了米环9和9pro测试设备',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 赞助者鸣谢部分
                    if (_isLoadingSponsors)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_sponsors.isNotEmpty)
                      Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerHighest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '赞助者鸣谢',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 赞助者列表
                            Wrap(
                              spacing: 10,
                              runSpacing: 0,
                              children: _sponsors
                                  .map(
                                    (sponsor) => Chip(
                                      label: Text(
                                        sponsor.name,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: Colors.transparent,
                                      labelStyle: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                        width: 1,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建特别鸣谢项目
  Widget _buildSpecialThanksItem(
    BuildContext context,
    String name,
    String description,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
