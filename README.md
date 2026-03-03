# Rosemary Updater

[English](#english) | [中文](#chinese)

A powerful Flutter package for managing application and resource updates, fully compatible with the [Rosemary](https://github.com/Rosemary-Project) backend management system. This library extracts the core update logic from the Zion project, providing a robust solution for checking updates, downloading resources, and applying patches via a custom script interpreter.

<a name="english"></a>
## English

### 🚀 Features

- **Rosemary Backend Compatibility**: Seamlessly integrates with Rosemary for version management and update distribution.
- **Dual Update System**: Supports both full App updates (APK/IPA) and incremental Resource updates (Hot updates).
- **Scriptable Patching**: Includes a built-in script interpreter (`ScriptRunner`) to execute complex file operations (unzip, move, delete, etc.) defined in update packages.
- **Progress Tracking**: Provides detailed callbacks for update checking, downloading, and installation progress.
- **UI Agnostic**: Pure Dart logic, allowing you to build your own update UI.

### 📦 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  rosemary_updater:
    path: ./rosemary_updater # Or your git/pub dependency
```

### 🛠 Usage

#### 1. Initialize Configuration

Create an `UpdaterConfig` instance with your app details and current version information.

```dart
import 'package:rosemary_updater/rosemary_updater.dart';

final config = UpdaterConfig(
  apiBaseUrl: 'https://your-rosemary-backend.com',
  appName: 'YourAppName',
  appPasswd: 'your_app_password', // App password configured in Rosemary
  betaPasswd: 'beta_password',    // Optional beta password
  appVersion: 100,                // Current App Version Code
  resVersion: 200,                // Current Resource Version Code
  downloadDir: '/path/to/download', // Optional: Custom download directory
);
```

#### 2. Check for Updates

Use `RosemaryUpdater` to check if a new version is available.

```dart
final updater = RosemaryUpdater(config);

try {
  final updateInfo = await updater.checkUpdate();
  
  if (updateInfo != null) {
    if (updateInfo.appUpgrade) {
      print('App Update Available: ${updateInfo.appUpgradeDescription}');
    }
    if (updateInfo.resUpgrade) {
      print('Resource Update Available: ${updateInfo.resUpgradeDescription}');
    }
  } else {
    print('No updates available.');
  }
} catch (e) {
  print('Failed to check updates: $e');
}
```

#### 3. Perform Update

Execute the update process with progress monitoring. The library handles downloading, verifying, and applying resource patches automatically.

```dart
if (updateInfo != null && (updateInfo.appUpgrade || updateInfo.resUpgrade)) {
  await updater.runUpdate(
    updateInfo: updateInfo,
    onStatusChanged: (status) {
      if (status.checking) {
        print('Checking...');
      } else if (status.downloading) {
        print('Downloading: ${status.progress}%');
      } else if (status.installing) {
        print('Installing: ${status.progress}% - ${status.message}');
      } else if (status.success) {
        print('Update Completed Successfully!');
        // Reload resources or restart app
      } else if (status.error != null) {
        print('Update Failed: ${status.error}');
      }
    },
  );
}
```

### 📜 Script Interpreter

The `ScriptRunner` supports a variety of commands for resource manipulation during updates:
- File Ops: `mv`, `cp`, `rm`, `mkdir`, `touch`, `unzip`
- Logic: `if`, `compare_num`, `is_arg_equal`
- Utils: `dl` (download), `say` (log)

---

<a name="chinese"></a>
## 中文

### 🚀 简介

Rosemary Updater 是一个强大的 Flutter 库，专为管理应用和资源更新而设计，完全兼容 [Rosemary](https://github.com/Rosemary-Project) 后端管理系统。该库提供了一套用于检查更新、下载资源以及通过自定义脚本解释器应用补丁的稳健解决方案。

### ✨ 特性

- **Rosemary 后端兼容**: 与 Rosemary 无缝集成，用于版本管理和更新分发。
- **双重更新系统**: 支持全量应用更新（APK）和增量资源更新（热更新）。
- **脚本化补丁**: 内置脚本解释器 (`ScriptRunner`)，可执行更新包中定义的复杂文件操作（解压、移动、删除等）。
- **进度追踪**: 提供详细的回调，用于监控更新检查、下载和安装进度。
- **UI 无关**: 纯 Dart 逻辑，允许您构建自己的更新 UI。

### 📦 安装

在您的 `pubspec.yaml` 中添加此包：

```yaml
dependencies:
  rosemary_updater:
    path: ./rosemary_updater # 或者使用 git/pub 依赖
```

### 🛠 使用方法

#### 1. 初始化配置

创建一个 `UpdaterConfig` 实例，填入您的应用详情和当前版本信息。

```dart
import 'package:rosemary_updater/rosemary_updater.dart';

final config = UpdaterConfig(
  apiBaseUrl: 'https://your-rosemary-backend.com', // Rosemary 后端地址
  appName: 'YourAppName',         // 应用名称
  appPasswd: 'your_app_password', // Rosemary 中配置的应用密码
  betaPasswd: 'beta_password',    // 可选的测试密码
  appVersion: 100,                // 当前 App 版本号 (Build Number)
  resVersion: 200,                // 当前资源版本号
  downloadDir: '/path/to/download', // 可选：自定义下载目录
);
```

#### 2. 检查更新

使用 `RosemaryUpdater` 检查是否有新版本可用。

```dart
final updater = RosemaryUpdater(config);

try {
  final updateInfo = await updater.checkUpdate();
  
  if (updateInfo != null) {
    if (updateInfo.appUpgrade) {
      print('发现应用更新: ${updateInfo.appUpgradeDescription}');
    }
    if (updateInfo.resUpgrade) {
      print('发现资源更新: ${updateInfo.resUpgradeDescription}');
    }
  } else {
    print('当前已是最新版本。');
  }
} catch (e) {
  print('检查更新失败: $e');
}
```

#### 3. 执行更新

执行更新流程并监听进度。库会自动处理资源的下载、校验和补丁应用。

```dart
if (updateInfo != null && (updateInfo.appUpgrade || updateInfo.resUpgrade)) {
  await updater.runUpdate(
    updateInfo: updateInfo,
    onStatusChanged: (status) {
      if (status.checking) {
        print('正在检查...');
      } else if (status.downloading) {
        print('正在下载: ${status.progress}%');
      } else if (status.installing) {
        print('正在安装: ${status.progress}% - ${status.message}');
      } else if (status.success) {
        print('更新成功完成！');
        //在此处重载资源或重启应用
      } else if (status.error != null) {
        print('更新失败: ${status.error}');
      }
    },
  );
}
```

### 📜 脚本解释器

`ScriptRunner` 支持在更新过程中执行多种资源操作指令：

- 文件操作: `mv` (移动), `cp` (复制), `rm` (删除), `mkdir` (创建目录), `touch` (创建文件), `unzip` (解压)
- 逻辑控制: `if`, `compare_num` (比较数字), `is_arg_equal` (参数相等判断)
- 工具: `dl` (下载), `say` (日志输出)

