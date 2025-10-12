# 简明天气 同步器

> 🧩 simple-weather-syncer

---

## 项目简介

简明天气是适用于Vela的长期天气存储快应用

## 应用包名
com.application.zaona.weather

## 注意事项

连续点击版本号 7 次可进入开发者模式，用于SDK调试

## 快速开始

### 1. 配置环境变量

复制 `.env.example` 文件并重命名为 `.env` 放在项目根目录

在 `.env` 文件中填写你自己的配置：

```env
# 和风天气 API Key
QWEATHER_API_KEY=your_api_key_here
   
# 和风天气 API Host (个人 API Host)
QWEATHER_API_HOST=your_api_host_here
   
# Android 应用包名
ANDROID_PACKAGE_NAME=com.application.zaona.weather
   
# Android 应用签名证书 SHA-1 指纹
ANDROID_CERT_SHA1=your_sha1_fingerprint_here
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 签名配置

在 `/android/app` 目录下放置 `key.kts`（签名文件）

在 `/android` 目录下放置 `key.properties` 文件，格式如下：

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../app/your-keystore.jks
```

### 4. 构建应用

```bash
# 调试版本
flutter run

# 发布版本
flutter build apk --release
```
