# video_player_mvp

Flutter 短视频播放器 MVP。

## Android 双应用对照包

项目支持同时构建两个 Android release APK，用于对比 feed preload 开关效果。

| 应用名 | 包名 | preload |
| --- | --- | --- |
| VideoPlayer Preload | `com.example.video_player_mvp.preload` | 开启 |
| VideoPlayer NoPreload | `com.example.video_player_mvp.nopreload` | 关闭 |

两个应用的 `applicationId` 不同，可以同时安装在同一台手机上。

### 构建 APK

在项目根目录执行：

```powershell
flutter build apk --release --flavor preload --dart-define=FEED_PRELOAD_ENABLED=true
flutter build apk --release --flavor noPreload --dart-define=FEED_PRELOAD_ENABLED=false
```

生成文件：

```text
build\app\outputs\flutter-apk\app-preload-release.apk
build\app\outputs\flutter-apk\app-nopreload-release.apk
```

### 安装到指定手机

先确认设备 id：

```powershell
flutter devices
```

示例设备：

```text
V2055A: <device-id>
```

安装两个 APK：

```powershell
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-preload-release.apk
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-nopreload-release.apk
```

如果 `adb` 不在 PATH，可以使用 Android SDK 下的完整路径：

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <device-id> install -r build\app\outputs\flutter-apk\app-preload-release.apk
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <device-id> install -r build\app\outputs\flutter-apk\app-nopreload-release.apk
```

### 验证安装

```powershell
adb -s <device-id> shell pm list packages com.example.video_player_mvp
```

预期至少包含：

```text
package:com.example.video_player_mvp.preload
package:com.example.video_player_mvp.nopreload
```

说明：本项目约定使用 `flutter` 和 `dart` 命令时需要提权运行。
