package com.application.zaona.weather;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.xiaomi.xms.wearable.Wearable;
import com.xiaomi.xms.wearable.auth.AuthApi;
import com.xiaomi.xms.wearable.auth.Permission;
import com.xiaomi.xms.wearable.message.MessageApi;
import com.xiaomi.xms.wearable.message.OnMessageReceivedListener;
import com.xiaomi.xms.wearable.node.Node;
import com.xiaomi.xms.wearable.node.NodeApi;
import com.xiaomi.xms.wearable.tasks.OnSuccessListener;
import com.xiaomi.xms.wearable.tasks.OnFailureListener;

import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class WearableMessageHandler implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL = "wearable_message_channel";
    private static final String TAG = "WearableMessageHandler";
    
    private Context context;
    private MethodChannel channel;
    private NodeApi nodeApi;
    private MessageApi messageApi;
    private AuthApi authApi;
    private Node currentNode;
    private OnMessageReceivedListener messageListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        
        // 初始化小米穿戴SDK API
        nodeApi = Wearable.getNodeApi(context);
        messageApi = Wearable.getMessageApi(context);
        authApi = Wearable.getAuthApi(context);
        
        // 初始化消息监听器
        messageListener = new OnMessageReceivedListener() {
            @Override
            public void onMessageReceived(@NonNull String nodeId, @NonNull byte[] message) {
                String messageStr = new String(message);
                Log.d(TAG, "收到来自设备的消息: " + messageStr);
                // 将消息发送到Flutter端
                channel.invokeMethod("onMessageReceived", messageStr);
            }
        };
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getConnectedNodes":
                getConnectedNodes(result);
                break;
            case "requestPermissions":
                requestPermissions(result);
                break;
            case "sendMessage":
                String message = call.argument("message");
                sendMessage(message, result);
                break;
            case "startListening":
                startListening(result);
                break;
            case "stopListening":
                stopListening(result);
                break;
            case "checkWearableApp":
                checkWearableApp(result);
                break;
            case "checkWearApp":
                checkWearApp(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void getConnectedNodes(Result result) {
        if (nodeApi == null) {
            result.error("SDK_ERROR", "NodeApi未初始化", null);
            return;
        }
        
        Log.d(TAG, "开始获取连接的设备...");
        nodeApi.getConnectedNodes()
                .addOnSuccessListener(new OnSuccessListener<List<Node>>() {
                    @Override
                    public void onSuccess(List<Node> nodes) {
                        Log.d(TAG, "获取设备列表成功，设备数量: " + nodes.size());
                        if (nodes.size() > 0) {
                            currentNode = nodes.get(0);
                            Log.d(TAG, "找到连接的设备: ID=" + currentNode.id);
                            result.success("设备连接成功: ID=" + currentNode.id);
                        } else {
                            Log.w(TAG, "没有找到连接的设备");
                            result.error("NO_DEVICE", "没有找到连接的穿戴设备。请确保：\n1. 穿戴设备已与手机配对\n2. 小米穿戴应用已安装\n3. 设备处于连接状态", null);
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "获取连接设备失败: " + e.getMessage());
                        result.error("CONNECTION_ERROR", "获取连接设备失败: " + e.getMessage() + "\n\n请检查：\n1. 小米穿戴应用是否已安装\n2. 设备是否已配对连接", null);
                    }
                });
    }

    private void requestPermissions(Result result) {
        if (authApi == null) {
            result.error("SDK_ERROR", "AuthApi未初始化", null);
            return;
        }
        
        if (currentNode == null) {
            result.error("NO_DEVICE", "没有连接的设备。请先点击'获取连接设备'按钮", null);
            return;
        }
        
        Log.d(TAG, "开始申请权限，设备ID: " + currentNode.id);
        Permission[] permissions = {Permission.DEVICE_MANAGER, Permission.NOTIFY};
        authApi.requestPermission(currentNode.id, permissions)
                .addOnSuccessListener(new OnSuccessListener<Permission[]>() {
                    @Override
                    public void onSuccess(Permission[] grantedPermissions) {
                        Log.d(TAG, "权限申请成功，获得权限数量: " + grantedPermissions.length);
                        String permissionNames = "";
                        for (Permission p : grantedPermissions) {
                            permissionNames += p.toString() + " ";
                        }
                        result.success("权限申请成功，获得权限: " + permissionNames.trim());
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "权限申请失败: " + e.getMessage());
                        String errorMsg = "权限申请失败: " + e.getMessage();
                        
                        // 根据错误类型提供更具体的提示
                        if (e.getMessage() != null && e.getMessage().contains("not installed")) {
                            errorMsg += "\n\n可能的原因：\n1. 小米穿戴应用未安装\n2. 穿戴设备未正确连接\n3. 设备上的配套应用未安装";
                        } else if (e.getMessage() != null && e.getMessage().contains("permission")) {
                            errorMsg += "\n\n权限相关错误，请检查设备连接状态";
                        }
                        
                        result.error("PERMISSION_ERROR", errorMsg, null);
                    }
                });
    }

    private void sendMessage(String message, Result result) {
        if (messageApi == null || currentNode == null) {
            result.error("SDK_ERROR", "MessageApi或设备未初始化", null);
            return;
        }
        
        // 直接发送输入框的消息内容
        Log.d(TAG, "发送消息: " + message);
        messageApi.sendMessage(currentNode.id, message.getBytes())
                .addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        Log.d(TAG, "消息发送成功");
                        result.success("消息发送成功");
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "消息发送失败: " + e.getMessage());
                        result.error("MESSAGE_ERROR", "消息发送失败: " + e.getMessage(), null);
                    }
                });
    }

    private void startListening(Result result) {
        if (messageApi == null || currentNode == null) {
            result.error("SDK_ERROR", "MessageApi或设备未初始化", null);
            return;
        }
        
        messageApi.addListener(currentNode.id, messageListener)
                .addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        Log.d(TAG, "开始监听消息");
                        result.success("开始监听消息");
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "开始监听失败: " + e.getMessage());
                        result.error("LISTEN_ERROR", "开始监听失败: " + e.getMessage(), null);
                    }
                });
    }

    private void stopListening(Result result) {
        if (messageApi == null || currentNode == null) {
            result.error("SDK_ERROR", "MessageApi或设备未初始化", null);
            return;
        }
        
        messageApi.removeListener(currentNode.id)
                .addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        Log.d(TAG, "停止监听消息");
                        result.success("停止监听消息");
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "停止监听失败: " + e.getMessage());
                        result.error("STOP_LISTEN_ERROR", "停止监听失败: " + e.getMessage(), null);
                    }
                });
    }

    private void checkWearableApp(Result result) {
        if (nodeApi == null) {
            result.error("SDK_ERROR", "NodeApi未初始化", null);
            return;
        }
        
        try {
            // 检查小米穿戴应用（旧版）
            boolean isWearableInstalled = false;
            try {
                context.getPackageManager().getPackageInfo("com.xiaomi.wearable", 0);
                isWearableInstalled = true;
            } catch (Exception ignored) {}
            
            // 检查小米运动健康（新版）
            boolean isHealthInstalled = false;
            try {
                context.getPackageManager().getPackageInfo("com.mi.health", 0);
                isHealthInstalled = true;
            } catch (Exception ignored) {}
            
            if (isWearableInstalled || isHealthInstalled) {
                String installedApps = "";
                if (isWearableInstalled) installedApps += "小米穿戴 ";
                if (isHealthInstalled) installedApps += "小米运动健康 ";
                result.success("✓ 已安装: " + installedApps.trim());
            } else {
                result.error("APP_NOT_INSTALLED", 
                    "未检测到小米穿戴相关应用！\n\n" +
                    "请安装以下任一应用：\n" +
                    "1. 小米穿戴 (com.xiaomi.wearable)\n" +
                    "2. 小米运动健康 (com.mi.health)\n\n" +
                    "从应用商店下载安装后重试。", 
                    null);
            }
        } catch (Exception e) {
            Log.e(TAG, "检查小米穿戴应用失败: " + e.getMessage());
            result.error("CHECK_FAILED", "检查小米穿戴应用失败: " + e.getMessage(), null);
        }
    }

    private void checkWearApp(Result result) {
        if (nodeApi == null || currentNode == null) {
            result.error("SDK_ERROR", "NodeApi或设备未初始化。请先获取连接设备", null);
            return;
        }
        
        if (authApi == null) {
            result.error("SDK_ERROR", "AuthApi未初始化", null);
            return;
        }
        
        // 先检查是否有DEVICE_MANAGER权限
        Log.d(TAG, "检查DEVICE_MANAGER权限，设备ID: " + currentNode.id);
        authApi.checkPermission(currentNode.id, Permission.DEVICE_MANAGER)
                .addOnSuccessListener(new OnSuccessListener<Boolean>() {
                    @Override
                    public void onSuccess(Boolean hasPermission) {
                        if (hasPermission) {
                            // 有权限，继续检查穿戴设备端应用
                            Log.d(TAG, "有权限，检查穿戴设备端应用是否安装");
                            nodeApi.isWearAppInstalled(currentNode.id)
                                    .addOnSuccessListener(new OnSuccessListener<Boolean>() {
                                        @Override
                                        public void onSuccess(Boolean isInstalled) {
                                            Log.d(TAG, "穿戴设备端应用检查结果: " + isInstalled);
                                            if (isInstalled) {
                                                result.success("✓ 穿戴设备端快应用已安装\n\n可以继续申请权限了！");
                                            } else {
                                                result.error("WEAR_APP_NOT_INSTALLED", 
                                                    "❌ 穿戴设备端快应用未安装！\n\n" +
                                                    "这是权限申请失败的主要原因。\n\n" +
                                                    "请确保：\n" +
                                                    "1. 在穿戴设备上安装了包名为 com.application.zaona.weather 的快应用\n" +
                                                    "2. 快应用和本应用使用相同的签名\n" +
                                                    "3. 快应用已正确配置 interconnect 功能", 
                                                    null);
                                            }
                                        }
                                    })
                                    .addOnFailureListener(new OnFailureListener() {
                                        @Override
                                        public void onFailure(@NonNull Exception e) {
                                            Log.e(TAG, "检查穿戴设备端应用失败: " + e.getMessage());
                                            result.error("CHECK_FAILED", 
                                                "检查穿戴设备端应用失败\n\n" + e.getMessage(), 
                                                null);
                                        }
                                    });
                        } else {
                            // 没有权限，提示用户先申请权限
                            Log.w(TAG, "没有DEVICE_MANAGER权限，无法检查穿戴设备端应用");
                            result.error("PERMISSION_REQUIRED", 
                                "⚠️ 需要先申请权限\n\n" +
                                "检查穿戴设备端应用需要DEVICE_MANAGER权限。\n\n" +
                                "建议操作顺序：\n" +
                                "1. 先点击【申请权限】\n" +
                                "2. 再点击【检查穿戴设备端快应用】\n\n" +
                                "注意：如果申请权限失败，很可能就是因为穿戴设备端快应用未安装。", 
                                null);
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e(TAG, "检查权限失败: " + e.getMessage());
                        result.error("PERMISSION_CHECK_FAILED", 
                            "检查权限失败\n\n" + e.getMessage(), 
                            null);
                    }
                });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        if (messageApi != null && currentNode != null) {
            messageApi.removeListener(currentNode.id);
        }
    }
}

