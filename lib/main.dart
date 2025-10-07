import 'package:flutter/material.dart';
import 'wearable_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简明天气同步器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WearableCommunicationPage(),
    );
  }
}

class WearableCommunicationPage extends StatefulWidget {
  const WearableCommunicationPage({super.key});

  @override
  State<WearableCommunicationPage> createState() => _WearableCommunicationPageState();
}

class _WearableCommunicationPageState extends State<WearableCommunicationPage> {
  final TextEditingController _messageController = TextEditingController();
  String _statusMessage = '准备就绪';
  String _receivedMessage = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // 设置消息接收回调
    WearableService.setMessageCallback((message) {
      setState(() {
        _receivedMessage = message;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _checkWearableApp() async {
    try {
      _updateStatus('正在检查小米穿戴/运动健康应用...');
      final result = await WearableService.checkWearableApp();
      _updateStatus(result);
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _checkWearApp() async {
    try {
      _updateStatus('正在检查穿戴设备端快应用...');
      final result = await WearableService.checkWearApp();
      _updateStatus(result);
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _getConnectedNodes() async {
    try {
      _updateStatus('正在获取连接设备...');
      final result = await WearableService.getConnectedNodes();
      _updateStatus(result);
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      _updateStatus('正在申请权限...');
      final result = await WearableService.requestPermissions();
      _updateStatus(result);
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      _updateStatus('请输入要发送的消息');
      return;
    }

    try {
      final result = await WearableService.sendMessage(_messageController.text);
      _updateStatus(result);
      _messageController.clear();
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _startListening() async {
    try {
      final result = await WearableService.startListening();
      _updateStatus(result);
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  Future<void> _stopListening() async {
    try {
      final result = await WearableService.stopListening();
      _updateStatus(result);
      setState(() {
        _isListening = false;
      });
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简明天气同步器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设备连接',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _checkWearableApp,
                      child: const Text('检查小米穿戴/运动健康'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getConnectedNodes,
                      child: const Text('获取连接设备'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _checkWearApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('检查穿戴设备端快应用 ⚠️'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      child: const Text('申请权限'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '发送消息到快应用',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: '输入要发送的消息',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: const Text('发送消息'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '消息监听',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isListening ? null : _startListening,
                          child: const Text('开始监听'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isListening ? _stopListening : null,
                          child: const Text('停止监听'),
                        ),
                      ],
                    ),
                    if (_receivedMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('收到的消息:'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_receivedMessage),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '状态信息',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusMessage),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '说明',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. 首先点击"检查小米穿戴/运动健康"确认应用已安装'),
                    Text('2. 点击"获取连接设备"检查是否有连接的穿戴设备'),
                    Text('3. 点击"申请权限"获取必要的通信权限'),
                    Text('4. ⚠️ 如果权限申请失败，点击"检查穿戴设备端快应用"'),
                    Text('   （需要先有权限才能检查）'),
                    Text('5. 输入消息内容并点击"发送消息"向快应用发送数据'),
                    Text('6. 点击"开始监听"接收来自穿戴设备的消息'),
                    Text('7. 目标快应用包名: com.application.zaona.weather'),
                  ],
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
