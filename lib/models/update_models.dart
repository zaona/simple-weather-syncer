/// 应用更新信息模型
class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String updateDescription;
  final String downloadUrl;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.updateDescription,
    required this.downloadUrl,
    required this.forceUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      updateDescription: json['updateDescription'] as String,
      downloadUrl: json['downloadUrl'] as String,
      forceUpdate: json['forceUpdate'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'versionCode': versionCode,
      'versionName': versionName,
      'updateDescription': updateDescription,
      'downloadUrl': downloadUrl,
      'forceUpdate': forceUpdate,
    };
  }
}

/// 更新检查结果
class UpdateCheckResult {
  final bool checkFailed;
  final bool hasUpdate;
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;

  UpdateCheckResult({
    required this.checkFailed,
    required this.hasUpdate,
    this.updateInfo,
    this.errorMessage,
  });

  /// 检查成功，有更新
  factory UpdateCheckResult.hasUpdate(AppUpdateInfo updateInfo) {
    return UpdateCheckResult(
      checkFailed: false,
      hasUpdate: true,
      updateInfo: updateInfo,
    );
  }

  /// 检查成功，无更新
  factory UpdateCheckResult.noUpdate() {
    return UpdateCheckResult(
      checkFailed: false,
      hasUpdate: false,
    );
  }

  /// 检查失败
  factory UpdateCheckResult.failed(String errorMessage) {
    return UpdateCheckResult(
      checkFailed: true,
      hasUpdate: false,
      errorMessage: errorMessage,
    );
  }
}

