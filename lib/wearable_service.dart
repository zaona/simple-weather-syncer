import 'dart:async';

import 'package:flutter/services.dart';

class WearableService {
  WearableService._internal();

  static final WearableService _instance = WearableService._internal();

  static const String _channelName = 'wearable_message_channel';
  static const MethodChannel _channel = MethodChannel(_channelName);

  bool _initialized = false;

  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<WearableServiceStatus> _serviceStatusController =
      StreamController<WearableServiceStatus>.broadcast();

  StreamSubscription<String>? _singleCallbackSubscription;

  WearableNodeInfo? _currentNode;
  WearConnectionResult? _lastConnectionResult;

  // ---- public API (static facade) ----

  static WearableNodeInfo? get currentNode => _instance._currentNode;

  static WearConnectionResult? get lastConnectionResult => _instance._lastConnectionResult;

  static Stream<String> get messageStream => _instance._messageStream;

  static Stream<WearableServiceStatus> get serviceStatusStream => _instance._serviceStatusStream;

  static void setMessageCallback(Function(String) callback) => _instance._setMessageCallback(callback);

  static StreamSubscription<String> addMessageListener(void Function(String) listener) =>
      _instance._addMessageListener(listener);

  static Future<WearableOperationResult<WearableNodeInfo>> getConnectedNodes() =>
      _instance._getConnectedNodes();

  static Future<WearableOperationResult<List<String>>> requestPermissions() =>
      _instance._requestPermissions();

  static Future<WearableOperationResult<void>> sendMessage(String message) =>
      _instance._sendMessage(message);

  static Future<WearableOperationResult<void>> sendNotification(String title, String message) =>
      _instance._sendNotification(title, message);

  static Future<WearableOperationResult<WearListeningState>> startListening() =>
      _instance._startListening();

  static Future<WearableOperationResult<WearListeningState>> stopListening() =>
      _instance._stopListening();

  static Future<WearableOperationResult<bool>> checkWearableApp() => _instance._checkWearableApp();

  static Future<WearableOperationResult<bool>> checkWearApp() => _instance._checkWearApp();

  static Future<WearableOperationResult<void>> launchWearApp({String path = '/'}) =>
      _instance._launchWearApp(path: path);

  static Future<WearConnectionResult> connectDevice() => _instance._connectDevice();

  // ---- instance implementation ----

  Stream<String> get _messageStream {
    _ensureInitialized();
    return _messageController.stream;
  }

  Stream<WearableServiceStatus> get _serviceStatusStream {
    _ensureInitialized();
    return _serviceStatusController.stream;
  }

  void _setMessageCallback(Function(String) callback) {
    _ensureInitialized();
    _singleCallbackSubscription?.cancel();
    _singleCallbackSubscription = _messageController.stream.listen(callback);
  }

  StreamSubscription<String> _addMessageListener(void Function(String) listener) {
    _ensureInitialized();
    return _messageController.stream.listen(listener);
  }

  Future<WearableOperationResult<WearableNodeInfo>> _getConnectedNodes() async {
    final result = await _invoke<WearableNodeInfo>(
      'getConnectedNodes',
      parser: (raw) {
        if (raw == null) return null;
        return WearableNodeInfo.fromMap(Map<String, dynamic>.from(raw as Map));
      },
    );

    if (result.success && result.data != null) {
      _currentNode = result.data;
    }

    return result;
  }

  Future<WearableOperationResult<List<String>>> _requestPermissions() async {
    final result = await _invoke<List<String>>(
      'requestPermissions',
      parser: (raw) {
        if (raw == null) return <String>[];
        return List<String>.from(raw as List<dynamic>);
      },
    );

    return result.map((list) => list ?? <String>[]);
  }

  Future<WearableOperationResult<void>> _sendMessage(String message) {
    return _invoke<void>(
      'sendMessage',
      arguments: {'message': message},
    );
  }

  Future<WearableOperationResult<void>> _sendNotification(String title, String message) {
    return _invoke<void>(
      'sendNotification',
      arguments: {
        'title': title,
        'message': message,
      },
    );
  }

  Future<WearableOperationResult<WearListeningState>> _startListening() {
    return _invoke<WearListeningState>(
      'startListening',
      parser: _parseListeningState,
    );
  }

  Future<WearableOperationResult<WearListeningState>> _stopListening() {
    return _invoke<WearListeningState>(
      'stopListening',
      parser: _parseListeningState,
    );
  }

  Future<WearableOperationResult<bool>> _checkWearableApp() async {
    final result = await _invoke<bool>(
      'checkWearableApp',
      parser: (raw) {
        if (raw == null) return false;
        final map = Map<String, dynamic>.from(raw as Map);
        return map['installed'] == true;
      },
    );

    return result.map((installed) => installed ?? false);
  }

  Future<WearableOperationResult<bool>> _checkWearApp() async {
    final result = await _invoke<bool>(
      'checkWearApp',
      parser: (raw) {
        if (raw == null) return false;
        final map = Map<String, dynamic>.from(raw as Map);
        return map['installed'] == true;
      },
    );

    return result.map((installed) => installed ?? false);
  }

  Future<WearableOperationResult<void>> _launchWearApp({required String path}) {
    return _invoke<void>(
      'launchWearApp',
      arguments: {'path': path},
    );
  }

  Future<WearConnectionResult> _connectDevice() async {
    String currentStep = '';

    try {
      currentStep = '检查小米运动健康应用';
      final wearableApp = await _checkWearableApp();
      if (!wearableApp.success) {
        return _recordFailure(
          step: currentStep,
          code: wearableApp.code,
          message: wearableApp.message,
          hints: wearableApp.hints,
          details: wearableApp.details,
          retryable: wearableApp.retryable,
        );
      }

      currentStep = '获取连接设备';
      final nodeResult = await _getConnectedNodes();
      if (!nodeResult.success || nodeResult.data == null) {
        return _recordFailure(
          step: currentStep,
          code: nodeResult.code,
          message: nodeResult.message,
          hints: nodeResult.hints,
          details: nodeResult.details,
          retryable: nodeResult.retryable,
        );
      }

      final node = nodeResult.data!;
      _currentNode = node;

      currentStep = '申请权限';
      final permissionResult = await _requestPermissions();
      if (!permissionResult.success) {
        return _recordFailure(
          step: currentStep,
          code: permissionResult.code,
          message: permissionResult.message,
          hints: permissionResult.hints,
          details: permissionResult.details,
          retryable: permissionResult.retryable,
        );
      }

      currentStep = '检查穿戴设备端快应用';
      final wearAppResult = await _checkWearApp();
      if (!wearAppResult.success) {
        return _recordFailure(
          step: currentStep,
          code: wearAppResult.code,
          message: wearAppResult.message,
          hints: wearAppResult.hints,
          details: wearAppResult.details,
          retryable: wearAppResult.retryable,
        );
      }

      final success = WearConnectionResult.success(
        node: node,
        message: '设备连接成功',
      );
      _lastConnectionResult = success;
      return success;
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      return _recordFailure(
        step: currentStep.isEmpty ? '未知步骤' : currentStep,
        code: 'UNEXPECTED',
        message: message,
        hints: const ['请重试操作'],
        details: error.toString(),
        retryable: true,
      );
    }
  }

  WearConnectionResult _recordFailure({
    required String step,
    required String code,
    required String message,
    List<String> hints = const <String>[],
    String? details,
    bool retryable = true,
  }) {
    final failure = WearConnectionResult.failure(
      step: step,
      message: message,
      code: code,
      hints: hints,
      details: details,
      retryable: retryable,
    );
    _lastConnectionResult = failure;
    return failure;
  }

  void _ensureInitialized() {
    if (_initialized) {
      return;
    }

    _channel.setMethodCallHandler(_handleNativeCallback);
    _initialized = true;
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onMessageReceived':
        final message = call.arguments?.toString();
        if (message != null) {
          _messageController.add(message);
        }
        break;
      case 'onServiceStatusChanged':
        final payload = Map<String, dynamic>.from(call.arguments as Map);
        _serviceStatusController.add(WearableServiceStatus.fromMap(payload));
        break;
      default:
        break;
    }
  }

  WearListeningState? _parseListeningState(dynamic raw) {
    if (raw == null) {
      return null;
    }
    return WearListeningState.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<WearableOperationResult<T>> _invoke<T>(
    String method, {
    Map<String, dynamic>? arguments,
    T? Function(dynamic raw)? parser,
  }) async {
    _ensureInitialized();

    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>(method, arguments);

      if (raw is Map) {
        final response = Map<String, dynamic>.from(raw);
        return WearableOperationResult<T>.fromMap(response, parser: parser);
      }

      return WearableOperationResult<T>(
        success: false,
        code: 'INVALID_RESPONSE',
        message: '原生返回格式异常',
        data: null,
        hints: const ['请重试操作'],
        retryable: true,
      );
    } on PlatformException catch (e) {
      return WearableOperationResult<T>(
        success: false,
        code: e.code,
        message: e.message ?? '平台调用异常',
        data: null,
        hints: const ['请稍后重试'],
        details: e.details?.toString() ?? e.message,
        retryable: true,
      );
    }
  }
}

class WearConnectionResult {
  WearConnectionResult._({
    required this.success,
    required this.step,
    required this.message,
    required this.code,
    this.node,
    this.hints = const <String>[],
    this.details,
    this.retryable = false,
  });

  final bool success;
  final String step;
  final String message;
  final String code;
  final WearableNodeInfo? node;
  final List<String> hints;
  final String? details;
  final bool retryable;

  factory WearConnectionResult.success({
    required WearableNodeInfo node,
    String message = '',
    List<String> hints = const <String>[],
    String? details,
  }) {
    return WearConnectionResult._(
      success: true,
      step: '连接完成',
      message: message,
      code: 'OK',
      node: node,
      hints: hints,
      details: details,
      retryable: false,
    );
  }

  factory WearConnectionResult.failure({
    required String step,
    required String message,
    required String code,
    List<String> hints = const <String>[],
    String? details,
    bool retryable = true,
    WearableNodeInfo? node,
  }) {
    return WearConnectionResult._(
      success: false,
      step: step,
      message: message,
      code: code,
      node: node,
      hints: hints,
      details: details,
      retryable: retryable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'step': step,
      'message': message,
      'code': code,
      'deviceId': node?.id ?? '',
      'deviceName': node?.name ?? '',
      'hints': hints,
      'details': details,
      'retryable': retryable,
    };
  }
}

class WearableNodeInfo {
  const WearableNodeInfo({
    required this.id,
    required this.name,
    this.attributes = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final Map<String, dynamic> attributes;

  factory WearableNodeInfo.fromMap(Map<String, dynamic> map) {
    return WearableNodeInfo(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      attributes: Map<String, dynamic>.from(map['attributes'] as Map? ?? const {}),
    );
  }
}

class WearableServiceStatus {
  WearableServiceStatus({
    required this.connected,
    this.timestamp,
  });

  final bool connected;
  final DateTime? timestamp;

  factory WearableServiceStatus.fromMap(Map<String, dynamic> map) {
    return WearableServiceStatus(
      connected: map['connected'] == true,
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int, isUtc: true).toLocal()
          : DateTime.now(),
    );
  }
}

class WearListeningState {
  const WearListeningState({
    required this.listening,
    this.nodeId,
    this.nodeName,
  });

  final bool listening;
  final String? nodeId;
  final String? nodeName;

  factory WearListeningState.fromMap(Map<String, dynamic> map) {
    return WearListeningState(
      listening: map['listening'] == true,
      nodeId: map['nodeId']?.toString(),
      nodeName: map['nodeName']?.toString(),
    );
  }
}

class WearableOperationResult<T> {
  const WearableOperationResult({
    required this.success,
    required this.code,
    required this.message,
    this.data,
    this.hints = const <String>[],
    this.details,
    this.retryable = false,
  });

  final bool success;
  final String code;
  final String message;
  final T? data;
  final List<String> hints;
  final String? details;
  final bool retryable;

  WearableOperationResult<R> map<R>(R? Function(T? data) convert) {
    return WearableOperationResult<R>(
      success: success,
      code: code,
      message: message,
      data: convert(data),
      hints: hints,
      details: details,
      retryable: retryable,
    );
  }

  factory WearableOperationResult.fromMap(
    Map<String, dynamic> map, {
    T? Function(dynamic raw)? parser,
  }) {
    final success = map['success'] == true;
    final code = map['code']?.toString() ?? (success ? 'OK' : 'ERROR');
    final message = map['message']?.toString() ?? '';
    final rawData = map['data'];
    final hintsRaw = map['hints'];
    final detailsRaw = map['details'];
    final retryable = map['retryable'] == true;

    final parsedHints = hintsRaw is List
        ? hintsRaw.map((hint) => hint.toString()).toList()
        : const <String>[];

    return WearableOperationResult<T>(
      success: success,
      code: code,
      message: message,
      data: parser != null ? parser(rawData) : rawData as T?,
      hints: parsedHints,
      details: detailsRaw?.toString(),
      retryable: retryable,
    );
  }
}
