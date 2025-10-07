package com.application.zaona.weather;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "wearable_message_channel";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // 注册小米穿戴通信插件
        WearableMessageHandler wearableHandler = new WearableMessageHandler();
        flutterEngine.getPlugins().add(wearableHandler);
    }
}

