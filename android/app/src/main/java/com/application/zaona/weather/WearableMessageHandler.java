package com.application.zaona.weather;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.xiaomi.xms.wearable.Status;
import com.xiaomi.xms.wearable.Wearable;
import com.xiaomi.xms.wearable.auth.AuthApi;
import com.xiaomi.xms.wearable.auth.Permission;
import com.xiaomi.xms.wearable.message.MessageApi;
import com.xiaomi.xms.wearable.message.OnMessageReceivedListener;
import com.xiaomi.xms.wearable.node.Node;
import com.xiaomi.xms.wearable.node.NodeApi;
import com.xiaomi.xms.wearable.notify.NotifyApi;
import com.xiaomi.xms.wearable.service.OnServiceConnectionListener;
import com.xiaomi.xms.wearable.service.ServiceApi;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class WearableMessageHandler implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL = "wearable_message_channel";

    private Context applicationContext;
    private MethodChannel channel;
    private Handler mainHandler;
    private WearableSdkManager sdkManager;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        mainHandler = new Handler(Looper.getMainLooper());
        sdkManager = new WearableSdkManager(applicationContext, channel, mainHandler);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getConnectedNodes":
                sdkManager.getConnectedNode(result);
                break;
            case "requestPermissions":
                sdkManager.requestPermissions(result);
                break;
            case "sendMessage":
                sdkManager.sendMessage(call.argument("message"), result);
                break;
            case "sendNotification":
                sdkManager.sendNotification(call.argument("title"), call.argument("message"), result);
                break;
            case "startListening":
                sdkManager.startListening(result);
                break;
            case "stopListening":
                sdkManager.stopListening(result);
                break;
            case "checkWearableApp":
                sdkManager.checkWearableApp(result);
                break;
            case "checkWearApp":
                sdkManager.checkWearApp(result);
                break;
            case "launchWearApp":
                sdkManager.launchWearApp(call.argument("path"), result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        if (sdkManager != null) {
            sdkManager.dispose();
            sdkManager = null;
        }
    }


    private static final class WearableSdkManager {
        private final Context context;
        private final MethodChannel channel;
        private final Handler mainHandler;

        private final NodeApi nodeApi;
        private final MessageApi messageApi;
        private final AuthApi authApi;
        private final NotifyApi notifyApi;
        private final ServiceApi serviceApi;

        private Node currentNode;
        private boolean listening;

        private final OnMessageReceivedListener messageListener;

        private final OnServiceConnectionListener serviceConnectionListener;

        WearableSdkManager(Context context, MethodChannel channel, Handler handler) {
            this.context = context.getApplicationContext();
            this.channel = channel;
            this.mainHandler = handler;
            nodeApi = Wearable.getNodeApi(this.context);
            messageApi = Wearable.getMessageApi(this.context);
            authApi = Wearable.getAuthApi(this.context);
            notifyApi = Wearable.getNotifyApi(this.context);
            serviceApi = Wearable.getServiceApi(this.context);

            messageListener = (nodeId, bytes) -> {
                final String message = new String(bytes, StandardCharsets.UTF_8);
                mainHandler.post(() -> channel.invokeMethod("onMessageReceived", message));
            };

            serviceConnectionListener = new OnServiceConnectionListener() {
                @Override
                public void onServiceConnected() {
                    emitServiceStatus(true);
                }

                @Override
                public void onServiceDisconnected() {
                    emitServiceStatus(false);
                }
            };

            if (serviceApi != null) {
                serviceApi.registerServiceConnectionListener(serviceConnectionListener);
            }
        }

        void dispose() {
            if (serviceApi != null) {
                serviceApi.unregisterServiceConnectionListener(serviceConnectionListener);
            }
            if (messageApi != null && currentNode != null && listening) {
                messageApi.removeListener(currentNode.id);
            }
        }
        
        void getConnectedNode(Result result) {
            if (nodeApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }

            nodeApi.getConnectedNodes()
                    .addOnSuccessListener(nodes -> {
                        if (nodes == null || nodes.isEmpty()) {
                            result.success(WearableErrorManager.createError(
                                    WearableErrorManager.CODE_NO_DEVICE,
                                    null,
                                    null
                            ));
                            return;
                        }

                        currentNode = nodes.get(0);
                        Map<String, Object> nodeMap = buildNodeMap(currentNode);
                        result.success(WearableErrorManager.createSuccess("设备连接成功", nodeMap));
                    })
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_CONNECTION_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void requestPermissions(Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (authApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }

            Permission[] permissions = new Permission[]{Permission.DEVICE_MANAGER, Permission.NOTIFY};
            authApi.requestPermission(currentNode.id, permissions)
                    .addOnSuccessListener(granted -> {
                        List<String> grantedNames = new ArrayList<>();
                        if (granted != null) {
                            for (Permission permission : granted) {
                                grantedNames.add(permission.toString());
                            }
                        }
                        result.success(WearableErrorManager.createSuccess("权限申请成功", grantedNames));
                    })
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_PERMISSION_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void sendMessage(String message, Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (messageApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }
            if (TextUtils.isEmpty(message)) {
                result.success(WearableErrorManager.createParamError("消息内容"));
                return;
            }

            messageApi.sendMessage(currentNode.id, message.getBytes(StandardCharsets.UTF_8))
                    .addOnSuccessListener(unused -> result.success(WearableErrorManager.createSuccess("消息发送成功", null)))
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_MESSAGE_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void sendNotification(String title, String message, Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (notifyApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }
            if (TextUtils.isEmpty(title)) {
                result.success(WearableErrorManager.createParamError("通知标题"));
                return;
            }
            if (TextUtils.isEmpty(message)) {
                result.success(WearableErrorManager.createParamError("通知内容"));
                return;
            }

            notifyApi.sendNotify(currentNode.id, title, message)
                    .addOnSuccessListener(status ->
                            result.success(WearableErrorManager.createSuccess("通知发送成功", Collections.singletonMap("status", status.toString()))))
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_NOTIFY_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void startListening(Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (messageApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }
            if (listening) {
                result.success(WearableErrorManager.createSuccess("已在监听消息", buildListeningData(true)));
                return;
            }

            messageApi.addListener(currentNode.id, messageListener)
                    .addOnSuccessListener(unused -> {
                        listening = true;
                        result.success(WearableErrorManager.createSuccess("开始监听消息", buildListeningData(true)));
                    })
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_LISTEN_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void stopListening(Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (messageApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }
            if (!listening) {
                result.success(WearableErrorManager.createSuccess("监听已停止", buildListeningData(false)));
                return;
            }

            messageApi.removeListener(currentNode.id)
                    .addOnSuccessListener(unused -> {
                        listening = false;
                        result.success(WearableErrorManager.createSuccess("停止监听消息", buildListeningData(false)));
                    })
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_STOP_LISTEN_ERROR,
                                e,
                                null
                        ));
                    });
        }

        void checkWearableApp(Result result) {
            PackageManager packageManager = context.getPackageManager();
            try {
                packageManager.getPackageInfo("com.mi.health", 0);
                result.success(WearableErrorManager.createSuccess(
                        "小米运动健康已安装",
                        Collections.singletonMap("installed", true)
                ));
            } catch (PackageManager.NameNotFoundException e) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_APP_NOT_INSTALLED,
                        Collections.singletonMap("installed", false)
                ));
            } catch (Exception e) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_CHECK_FAILED,
                        e,
                        null
                ));
            }
        }

        void checkWearApp(Result result) {
            if (!ensureNode(result)) {
                return;
            }
            if (authApi == null) {
                result.success(WearableErrorManager.createError(
                        WearableErrorManager.CODE_SDK_ERROR,
                        null,
                        null
                ));
                return;
            }

            Permission[] permissions = new Permission[]{Permission.DEVICE_MANAGER};
            authApi.checkPermissions(currentNode.id, permissions)
                    .addOnSuccessListener(results -> {
                        boolean granted = results != null && results.length > 0 && results[0];
                        if (!granted) {
                            result.success(WearableErrorManager.createError(
                                    WearableErrorManager.CODE_PERMISSION_REQUIRED,
                                    null,
                                    null
                            ));
                            return;
                        }
                        nodeApi.isWearAppInstalled(currentNode.id)
                                .addOnSuccessListener(installed -> {
                                    if (installed) {
                                        result.success(WearableErrorManager.createSuccess(
                                                "快应用已安装",
                                                Collections.singletonMap("installed", true)
                                        ));
                                    } else {
                                        result.success(WearableErrorManager.createError(
                                                WearableErrorManager.CODE_WEAR_APP_NOT_INSTALLED,
                                                Collections.singletonMap("installed", false)
                                        ));
                                    }
                                })
                                .addOnFailureListener(e -> {
                                    result.success(WearableErrorManager.createError(
                                            WearableErrorManager.CODE_CHECK_FAILED,
                                            e,
                                            null
                                    ));
                                });
                    })
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_PERMISSION_CHECK_FAILED,
                                e,
                                null
                        ));
                    });
        }

        void launchWearApp(String path, Result result) {
            if (!ensureNode(result)) {
                return;
            }
            String launchPath = TextUtils.isEmpty(path) ? "/" : path;
            nodeApi.launchWearApp(currentNode.id, launchPath)
                    .addOnSuccessListener(unused ->
                            result.success(WearableErrorManager.createSuccess("快应用启动成功", Collections.singletonMap("path", launchPath))))
                    .addOnFailureListener(e -> {
                        result.success(WearableErrorManager.createError(
                                WearableErrorManager.CODE_LAUNCH_FAILED,
                                e,
                                null
                        ));
                    });
        }

        private boolean ensureNode(Result result) {
            if (currentNode != null) {
                return true;
            }
            result.success(WearableErrorManager.createError(
                    WearableErrorManager.CODE_NO_DEVICE,
                    null,
                    null
            ));
            return false;
        }

        private void emitServiceStatus(boolean connected) {
            Map<String, Object> payload = new HashMap<>();
            payload.put("connected", connected);
            payload.put("timestamp", System.currentTimeMillis());
            mainHandler.post(() -> channel.invokeMethod("onServiceStatusChanged", payload));
        }

        private static Map<String, Object> buildNodeMap(Node node) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", node.id);
            map.put("name", node.name);
            map.put("attributes", new HashMap<>());
            return map;
        }

        private Map<String, Object> buildListeningData(boolean listening) {
            Map<String, Object> map = new HashMap<>();
            map.put("listening", listening);
            if (currentNode != null) {
                map.put("nodeId", currentNode.id);
                map.put("nodeName", currentNode.name);
            }
            return map;
        }
    }
}

