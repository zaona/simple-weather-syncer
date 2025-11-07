package com.application.zaona.weather;

import android.content.Context;
import android.content.pm.PackageManager;
import android.text.TextUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 统一管理穿戴设备相关的错误消息、提示和元数据
 */
public class WearableErrorManager {
    
    // 错误码常量
    public static final String CODE_OK = "OK";
    public static final String CODE_SDK_ERROR = "SDK_ERROR";
    public static final String CODE_NO_DEVICE = "NO_DEVICE";
    public static final String CODE_CONNECTION_ERROR = "CONNECTION_ERROR";
    public static final String CODE_PERMISSION_ERROR = "PERMISSION_ERROR";
    public static final String CODE_PERMISSION_REQUIRED = "PERMISSION_REQUIRED";
    public static final String CODE_PERMISSION_CHECK_FAILED = "PERMISSION_CHECK_FAILED";
    public static final String CODE_MESSAGE_ERROR = "MESSAGE_ERROR";
    public static final String CODE_NOTIFY_ERROR = "NOTIFY_ERROR";
    public static final String CODE_LISTEN_ERROR = "LISTEN_ERROR";
    public static final String CODE_STOP_LISTEN_ERROR = "STOP_LISTEN_ERROR";
    public static final String CODE_APP_NOT_INSTALLED = "APP_NOT_INSTALLED";
    public static final String CODE_WEAR_APP_NOT_INSTALLED = "WEAR_APP_NOT_INSTALLED";
    public static final String CODE_CHECK_FAILED = "CHECK_FAILED";
    public static final String CODE_LAUNCH_FAILED = "LAUNCH_FAILED";
    public static final String CODE_INVALID_PARAMS = "INVALID_PARAMS";
    
    /**
     * 错误信息定义
     */
    public static class ErrorInfo {
        public final String code;
        public final String message;
        public final List<String> hints;
        public final boolean retryable;
        
        public ErrorInfo(String code, String message, List<String> hints, boolean retryable) {
            this.code = code;
            this.message = message;
            this.hints = hints != null ? hints : Collections.emptyList();
            this.retryable = retryable;
        }
        
        public ErrorInfo(String code, String message, String... hints) {
            this(code, message, Arrays.asList(hints), true);
        }
        
        public ErrorInfo(String code, String message, boolean retryable, String... hints) {
            this(code, message, Arrays.asList(hints), retryable);
        }
    }
    
    private static final Map<String, ErrorInfo> ERROR_MAP = new HashMap<>();
    
    static {
        // SDK 初始化错误
        ERROR_MAP.put(CODE_SDK_ERROR, new ErrorInfo(
            CODE_SDK_ERROR,
            "SDK 未初始化",
            "请检查小米穿戴 SDK 初始化状态"
        ));
        
        // 设备连接错误
        ERROR_MAP.put(CODE_NO_DEVICE, new ErrorInfo(
            CODE_NO_DEVICE,
            "未检测到穿戴设备",
            true,
            "确认穿戴设备已与手机配对",
            "确认穿戴设备与手机保持连接",
            "确认已安装小米运动健康"
        ));
        
        ERROR_MAP.put(CODE_CONNECTION_ERROR, new ErrorInfo(
            CODE_CONNECTION_ERROR,
            "获取连接设备失败",
            true,
            "确认小米运动健康保持运行",
            "确认设备已配对并在线"
        ));
        
        // 权限相关错误
        ERROR_MAP.put(CODE_PERMISSION_ERROR, new ErrorInfo(
            CODE_PERMISSION_ERROR,
            "权限申请失败",
            true,
            "确认小米运动健康保持运行",
            "确认设备已配对并在线",
            "确认简明天气快应用已安装"
        ));
        
        ERROR_MAP.put(CODE_PERMISSION_REQUIRED, new ErrorInfo(
            CODE_PERMISSION_REQUIRED,
            "需要先申请设备管理权限",
            false,
            "请先调用权限申请接口",
            "在穿戴设备上确认授权提示"
        ));
        
        ERROR_MAP.put(CODE_PERMISSION_CHECK_FAILED, new ErrorInfo(
            CODE_PERMISSION_CHECK_FAILED,
            "检查权限失败",
            true,
            "稍后重试，必要时重新连接设备"
        ));
        
        // 消息相关错误
        ERROR_MAP.put(CODE_MESSAGE_ERROR, new ErrorInfo(
            CODE_MESSAGE_ERROR,
            "消息发送失败",
            true,
            "确认设备已连接并在线",
            "确认已授权消息发送权限"
        ));
        
        // 通知相关错误
        ERROR_MAP.put(CODE_NOTIFY_ERROR, new ErrorInfo(
            CODE_NOTIFY_ERROR,
            "通知发送失败",
            true,
            "确认设备已连接并在线",
            "确认已授权通知发送"
        ));
        
        // 监听相关错误
        ERROR_MAP.put(CODE_LISTEN_ERROR, new ErrorInfo(
            CODE_LISTEN_ERROR,
            "开始监听失败",
            true,
            "确认设备保持连接",
            "稍后重新尝试开始监听"
        ));
        
        ERROR_MAP.put(CODE_STOP_LISTEN_ERROR, new ErrorInfo(
            CODE_STOP_LISTEN_ERROR,
            "停止监听失败",
            true,
            "确认设备保持连接",
            "稍后重新尝试停止监听"
        ));
        
        // 应用检查错误
        ERROR_MAP.put(CODE_APP_NOT_INSTALLED, new ErrorInfo(
            CODE_APP_NOT_INSTALLED,
            "未检测到小米运动健康",
            false,
            "从应用商店安装小米运动健康"
        ));
        
        ERROR_MAP.put(CODE_WEAR_APP_NOT_INSTALLED, new ErrorInfo(
            CODE_WEAR_APP_NOT_INSTALLED,
            "未检测到快应用",
            false,
            "在穿戴端安装简明天气快应用"
        ));
        
        ERROR_MAP.put(CODE_CHECK_FAILED, new ErrorInfo(
            CODE_CHECK_FAILED,
            "检查失败",
            true,
            "稍后重试，必要时重新连接设备"
        ));
        
        // 启动错误
        ERROR_MAP.put(CODE_LAUNCH_FAILED, new ErrorInfo(
            CODE_LAUNCH_FAILED,
            "启动快应用失败",
            true,
            "确认穿戴端已安装简明天气快应用",
            "确认穿戴端简明天气快应用为最新版本"
        ));
        
        // 参数错误
        ERROR_MAP.put(CODE_INVALID_PARAMS, new ErrorInfo(
            CODE_INVALID_PARAMS,
            "参数无效",
            false
        ));
    }
    
    /**
     * 获取错误信息
     */
    public static ErrorInfo getErrorInfo(String code) {
        return ERROR_MAP.getOrDefault(code, new ErrorInfo(
            code,
            "未知错误",
            Collections.singletonList("请稍后重试"),
            true
        ));
    }
    
    /**
     * 创建成功响应
     */
    public static Map<String, Object> createSuccess(String message, Object data) {
        return createResponse(true, CODE_OK, message, data, Collections.emptyList(), null, false);
    }
    
    /**
     * 创建错误响应
     */
    public static Map<String, Object> createError(
            String code,
            Exception exception,
            Object data,
            String customMessage,
            List<String> customHints,
            Boolean customRetryable
    ) {
        ErrorInfo errorInfo = getErrorInfo(code);
        
        String message = !TextUtils.isEmpty(customMessage) ? customMessage : errorInfo.message;
        List<String> hints = (customHints != null && !customHints.isEmpty()) 
            ? customHints 
            : errorInfo.hints;
        boolean retryable = customRetryable != null ? customRetryable : errorInfo.retryable;
        String details = extractExceptionDetails(exception);
        
        return createResponse(false, code, message, data, hints, details, retryable);
    }
    
    /**
     * 创建错误响应（使用默认错误信息）
     */
    public static Map<String, Object> createError(String code, Exception exception, Object data) {
        return createError(code, exception, data, null, null, null);
    }
    
    /**
     * 创建错误响应（仅错误码）
     */
    public static Map<String, Object> createError(String code, Object data) {
        return createError(code, null, data);
    }
    
    /**
     * 创建参数错误响应
     */
    public static Map<String, Object> createParamError(String paramName) {
        return createError(
            CODE_INVALID_PARAMS,
            null,
            null,
            paramName + "不能为空",
            Collections.singletonList("请输入" + paramName),
            false
        );
    }
    
    /**
     * 创建基础响应结构
     */
    private static Map<String, Object> createResponse(
            boolean success,
            String code,
            String message,
            Object data,
            List<String> hints,
            String details,
            boolean retryable
    ) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        response.put("code", code);
        response.put("message", message);
        response.put("data", data);
        
        if (hints != null && !hints.isEmpty()) {
            response.put("hints", hints);
        }
        if (!TextUtils.isEmpty(details)) {
            response.put("details", details);
        }
        if (retryable) {
            response.put("retryable", true);
        }
        
        return response;
    }
    
    /**
     * 提取异常详情
     */
    private static String extractExceptionDetails(Exception exception) {
        if (exception == null || TextUtils.isEmpty(exception.getMessage())) {
            return null;
        }
        return exception.getMessage();
    }
}

