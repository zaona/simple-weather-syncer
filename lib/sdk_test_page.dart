import 'dart:async';

import 'package:flutter/material.dart';
import 'wearable_service.dart';

class SdkTestController extends ChangeNotifier {
  bool _initialized = false;
  bool isLoading = false;
  bool isListening = false;
  bool serviceConnected = false;

  String statusMessage = '';
  String deviceInfo = '';

  final List<String> receivedMessages = [];

  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<WearableServiceStatus>? _serviceSubscription;
  List<String> _lastHints = const <String>[];
  String? _lastDetails;

  List<String> get lastHints => List.unmodifiable(_lastHints);
  String? get lastDetails => _lastDetails;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _messageSubscription = WearableService.messageStream.listen(_handleMessage);
    _serviceSubscription = WearableService.serviceStatusStream.listen(_handleServiceStatus);
  }

  Future<void> connectDevice() async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    statusMessage = '正在连接设备...';
    notifyListeners();

    try {
      final result = await WearableService.connectDevice();
      _updateHints(result.hints, details: result.details);
      if (result.success) {
        final node = result.node;
        deviceInfo = node == null ? '' : '${node.name} (${node.id})';
        statusMessage = '连接成功: ${result.message.isNotEmpty ? result.message : '设备已连接'}';
      } else {
        final message = result.message.isNotEmpty ? result.message : '请重试';
        statusMessage = '连接失败 [${result.step}]: $message';
      }
    } catch (error) {
      statusMessage = '连接异常: $error';
      _updateHints(const <String>[], details: null);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchConnectedNode() async {
    await _runOperation<WearableNodeInfo>(
      actionName: '获取已连接设备',
      operation: WearableService.getConnectedNodes,
      onSuccess: (node) {
        if (node != null) {
          deviceInfo = '${node.name} (${node.id})';
        }
      },
    );
  }

  Future<void> requestPermissions() async {
    await _runOperation<List<String>>(
      actionName: '申请权限',
      operation: WearableService.requestPermissions,
    );
  }

  Future<void> checkWearableApp() async {
    await _runOperation<bool>(
      actionName: '检查小米运动健康应用',
      operation: WearableService.checkWearableApp,
    );
  }

  Future<void> checkWearApp() async {
    await _runOperation<bool>(
      actionName: '检查穿戴设备端快应用',
      operation: WearableService.checkWearApp,
    );
  }

  Future<void> launchWearApp() async {
    await _runOperation<void>(
      actionName: '启动穿戴设备端快应用',
      operation: WearableService.launchWearApp,
    );
  }

  Future<void> toggleListening() async {
    if (isListening) {
      await _runOperation<WearListeningState>(
        actionName: '停止监听',
        operation: WearableService.stopListening,
        onSuccess: (state) {
          isListening = state?.listening ?? false;
        },
      );
    } else {
      await _runOperation<WearListeningState>(
        actionName: '开始监听',
        operation: WearableService.startListening,
        onSuccess: (state) {
          isListening = state?.listening ?? true;
        },
      );
    }
  }

  Future<void> sendMessage(String message) async {
    await _runOperation<void>(
      actionName: '发送消息',
      operation: () => WearableService.sendMessage(message),
    );
  }

  Future<void> sendNotification(String title, String message) async {
    await _runOperation<void>(
      actionName: '发送通知',
      operation: () => WearableService.sendNotification(title, message),
    );
  }

  void clearMessages() {
    receivedMessages.clear();
    notifyListeners();
  }

  void showValidationError(String message) {
    statusMessage = message;
    notifyListeners();
  }

  void _handleMessage(String message) {
    final time = DateTime.now().toString().substring(11, 19);
    receivedMessages.insert(0, '$time - $message');
    notifyListeners();
  }

  void _handleServiceStatus(WearableServiceStatus status) {
    serviceConnected = status.connected;
    notifyListeners();
  }

  void _updateHints(List<String> hints, {String? details}) {
    _lastHints = List<String>.from(hints);
    _lastDetails = details;
  }

  Future<void> _runOperation<T>({
    required String actionName,
    required Future<WearableOperationResult<T>> Function() operation,
    void Function(T? data)? onSuccess,
  }) async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    statusMessage = '执行中: $actionName...';
    notifyListeners();

    try {
      final result = await operation();
      _updateHints(result.hints, details: result.details);
      if (result.success) {
        onSuccess?.call(result.data);
        final detail = result.message.isNotEmpty ? result.message : '操作成功';
        statusMessage = '$actionName 成功: $detail';
      } else {
        final detail = result.message.isNotEmpty ? result.message : '操作失败';
        statusMessage = '$actionName 失败 [${result.code}]: $detail';
      }
    } catch (error) {
      statusMessage = '$actionName 异常: $error';
      _updateHints(const <String>[], details: null);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _serviceSubscription?.cancel();
    super.dispose();
  }
}

class SdkTestPage extends StatefulWidget {
  const SdkTestPage({super.key});

  @override
  State<SdkTestPage> createState() => _SdkTestPageState();
}

class _SdkTestPageState extends State<SdkTestPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _notifyTitleController = TextEditingController();
  final TextEditingController _notifyMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final SdkTestController _controller;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = SdkTestController()
      ..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageController.dispose();
    _notifyTitleController.dispose();
    _notifyMessageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onSendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _controller.showValidationError('请输入要发送的消息');
      return;
    }

    await _controller.sendMessage(message);
    _messageController.clear();
  }

  Future<void> _onSendNotification() async {
    final title = _notifyTitleController.text.trim();
    final message = _notifyMessageController.text.trim();

    if (title.isEmpty) {
      _controller.showValidationError('请输入通知标题');
      return;
    }

    if (message.isEmpty) {
      _controller.showValidationError('请输入通知内容');
      return;
    }

    await _controller.sendNotification(title, message);
    _notifyTitleController.clear();
    _notifyMessageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;
        final statusMessage = _controller.statusMessage;
        final deviceInfo = _controller.deviceInfo;
        final isListening = _controller.isListening;
        final hints = _controller.lastHints;
        final details = _controller.lastDetails;

        final hasDetails = details != null && details.isNotEmpty;
        final hasHints = hints.isNotEmpty;

        final messageCount = _controller.receivedMessages.length;
        if (messageCount > _lastMessageCount && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        _lastMessageCount = messageCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SDK 功能测试'),
            elevation: 0,
          ),
          body: Column(
            children: [
              if (statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (hasDetails)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '详情：$details',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            if (hasHints)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '建议：',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    ...hints.map(
                                      (hint) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '• $hint',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (deviceInfo.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.watch,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '已连接设备: $deviceInfo',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '设备连接',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: '一键连接设备',
                              icon: Icons.link,
                              onPressed: isLoading ? null : () => _controller.connectDevice(),
                              isPrimary: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '基础功能',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildOutlinedButton(
                              label: '获取已连接设备',
                              icon: Icons.devices,
                              onPressed: isLoading ? null : () => _controller.fetchConnectedNode(),
                            ),
                            const SizedBox(height: 8),
                            _buildOutlinedButton(
                              label: '申请权限',
                              icon: Icons.security,
                              onPressed: isLoading ? null : () => _controller.requestPermissions(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '应用检查',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildOutlinedButton(
                              label: '检查小米运动健康应用',
                              icon: Icons.phone_android,
                              onPressed: isLoading ? null : () => _controller.checkWearableApp(),
                            ),
                            const SizedBox(height: 8),
                            _buildOutlinedButton(
                              label: '检查穿戴设备端快应用',
                              icon: Icons.watch,
                              onPressed: isLoading ? null : () => _controller.checkWearApp(),
                            ),
                            const SizedBox(height: 8),
                            _buildOutlinedButton(
                              label: '启动穿戴设备端快应用',
                              icon: Icons.launch,
                              onPressed: isLoading ? null : () => _controller.launchWearApp(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '消息发送',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: '输入消息内容',
                                border: UnderlineInputBorder(),
                                prefixIcon: Icon(Icons.message),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: '发送消息',
                              icon: Icons.send,
                              onPressed: isLoading ? null : _onSendMessage,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '通知发送',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notifyTitleController,
                              decoration: const InputDecoration(
                                labelText: '通知标题',
                                border: UnderlineInputBorder(),
                                prefixIcon: Icon(Icons.title),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notifyMessageController,
                              decoration: const InputDecoration(
                                labelText: '通知内容',
                                border: UnderlineInputBorder(),
                                prefixIcon: Icon(Icons.notifications),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: '发送通知',
                              icon: Icons.notifications_active,
                              onPressed: isLoading ? null : _onSendNotification,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '消息监听',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isListening ? Colors.green : Colors.grey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isListening ? '监听中' : '未监听',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: isListening ? '停止监听' : '开始监听',
                              icon: isListening ? Icons.stop : Icons.play_arrow,
                              onPressed: isLoading ? null : () => _controller.toggleListening(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '接收到的消息 (${_controller.receivedMessages.length})',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (_controller.receivedMessages.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: isLoading ? null : _controller.clearMessages,
                                    icon: const Icon(Icons.clear_all, size: 16),
                                    label: const Text('清空'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _controller.receivedMessages.isEmpty
                                  ? Center(
                                      child: Text(
                                        '暂无接收到的消息',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _controller.receivedMessages.length,
                                      itemBuilder: (context, index) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _controller.receivedMessages[index],
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontFamily: 'monospace',
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  FilledButton _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: isPrimary ? null : Theme.of(context).colorScheme.secondary,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  OutlinedButton _buildOutlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

