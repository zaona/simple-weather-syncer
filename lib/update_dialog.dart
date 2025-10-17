import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_models.dart';

/// 强制更新弹窗
/// 此弹窗无法通过返回键关闭，用户必须点击更新按钮
class ForceUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const ForceUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  /// 打开下载链接（网盘）
  Future<void> _openDownloadUrl(BuildContext context) async {
    final url = Uri.parse(updateInfo.downloadUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法打开下载链接'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开链接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      // 禁止通过返回键关闭弹窗
      canPop: false,
      child: AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 标题和版本号
              Text(
                '发现新版本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                updateInfo.versionName,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 更新说明
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                ),
                child: Text(
                  updateInfo.updateDescription,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 更新按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openDownloadUrl(context),
                  icon: const Icon(Icons.download),
                  label: const Text('立即更新'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 显示强制更新弹窗
void showForceUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
  showDialog(
    context: context,
    barrierDismissible: false, // 禁止点击外部关闭
    builder: (context) => ForceUpdateDialog(updateInfo: updateInfo),
  );
}

