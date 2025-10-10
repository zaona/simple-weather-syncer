import 'package:flutter/material.dart';
import 'wearable_service.dart';

class SdkTestPage extends StatefulWidget {
  const SdkTestPage({super.key});

  @override
  State<SdkTestPage> createState() => _SdkTestPageState();
}

class _SdkTestPageState extends State<SdkTestPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _receivedMessages = [];
  final ScrollController _scrollController = ScrollController();
  
  String _statusMessage = '';
  bool _isListening = false;
  bool _isLoading = false;
  String _deviceInfo = '';

  @override
  void initState() {
    super.initState();
    // 设置消息接收回调
    WearableService.setMessageCallback(_onMessageReceived);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageReceived(String message) {
    setState(() {
      _receivedMessages.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
    });
    // 自动滚动到顶部
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _executeAction(String actionName, Future<String> Function() action) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '执行中: $actionName...';
    });

    try {
      final result = await action();
      _setStatus('$actionName 成功: $result');
    } catch (e) {
      _setStatus('$actionName 失败: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectDevice() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在连接设备...';
    });

    try {
      final result = await WearableService.connectDevice();
      
      if (result['success']) {
        setState(() {
          _deviceInfo = '${result['deviceName']} (${result['deviceId']})';
        });
        _setStatus('连接成功: ${result['message']}');
      } else {
        _setStatus('连接失败 [${result['step']}]: ${result['message']}', isError: true);
      }
    } catch (e) {
      _setStatus('连接异常: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _executeAction('停止监听', WearableService.stopListening);
      setState(() {
        _isListening = false;
      });
    } else {
      await _executeAction('开始监听', WearableService.startListening);
      setState(() {
        _isListening = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _setStatus('请输入要发送的消息', isError: true);
      return;
    }

    await _executeAction('发送消息', () => WearableService.sendMessage(message));
    _messageController.clear();
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: isPrimary ? null : Theme.of(context).colorScheme.secondary,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK 功能测试'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 状态栏
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          
          // 设备信息
          if (_deviceInfo.isNotEmpty)
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
                      '已连接设备: $_deviceInfo',
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
                // 一键连接
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
                          onPressed: _connectDevice,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 基础功能
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
                          onPressed: () => _executeAction(
                            '获取已连接设备',
                            WearableService.getConnectedNodes,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildOutlinedButton(
                          label: '申请权限',
                          icon: Icons.security,
                          onPressed: () => _executeAction(
                            '申请权限',
                            WearableService.requestPermissions,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 应用检查
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
                          onPressed: () => _executeAction(
                            '检查小米运动健康应用',
                            WearableService.checkWearableApp,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildOutlinedButton(
                          label: '检查穿戴设备端快应用',
                          icon: Icons.watch,
                          onPressed: () => _executeAction(
                            '检查穿戴设备端快应用',
                            WearableService.checkWearApp,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildOutlinedButton(
                          label: '启动穿戴设备端快应用',
                          icon: Icons.launch,
                          onPressed: () => _executeAction(
                            '启动穿戴设备端快应用',
                            WearableService.launchWearApp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 消息发送
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
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 消息监听
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.green
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isListening ? '监听中' : '未监听',
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
                          label: _isListening ? '停止监听' : '开始监听',
                          icon: _isListening ? Icons.stop : Icons.play_arrow,
                          onPressed: _toggleListening,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '接收到的消息 (${_receivedMessages.length})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (_receivedMessages.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _receivedMessages.clear();
                                  });
                                },
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
                          child: _receivedMessages.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无接收到的消息',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _receivedMessages.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _receivedMessages[index],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
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
  }
}

