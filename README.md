# ShellBox (Flutter rewrite)

现代、简洁的 SSH 客户端 —— Android 端 Jetpack Compose + SSHJ 原版 `ShellBox-master` 的
Flutter 重写，目标平台：**Android**（触屏）与 **Windows**（桌面）。

## 架构

```
lib/
├─ core/                    100% 平台无关（纯 Dart 逻辑）
│  ├─ models/               Server / PortForwardRule / KnownHost / QuickConnect / SftpFileEntry
│  ├─ data/                 AppDatabase (sqflite), ServerRepository(透明加解密), KnownHostRepository, CryptoService(AES-256-GCM)
│  ├─ ssh/                  SshManager, KnownHostsVerifier(TOFU), PortForwardManager, SftpRepository, KeyLoader, TerminalBridge
│  ├─ services/             平台抽象接口：SecretStorage / BackgroundKeepAlive / FilePickerService / AppServices / MasterKey
│  ├─ state/                Riverpod providers（home / terminal / sftp / settings / providers）
│  └─ utils/                TerminalFont, TerminalSettingsStore, VKeyLayoutStore
├─ platform/                平台实现：flutter_secure_storage(Keystore/DPAPI), background service(Android), file_picker
├─ ui/
│  ├─ common/               theme(ShellBox 蓝), 表单组件
│  ├─ layouts/              ResponsiveShell(<600dp mobile) + MobileLayout + DesktopLayout
│  └─ (features 内部复用)    TerminalView 包装、xterm
└─ features/
   ├─ home/                 HomeScreen(列表/网格) + ServerCard + QuickConnectDialog
   ├─ add_server/           AddServerScreen + PortForwardSection
   ├─ terminal/             TerminalScreen(多Tab + 虚拟键盘 + 设置)
   ├─ sftp/                 SftpScreen(面包屑 + 上传/下载)
   └─ settings/             Settings + FontSettings + KeySettings + KnownHosts + SettingsSheet
```

## 首次构建（重要）

本仓库**手工**写好了平台目录，但没有 flutter 引擎胶水文件（`windows/flutter/`、
`android/gradle/wrapper/gradle-wrapper.jar`、`.metadata` 等）。拿到本仓库后先执行：

```bash
cd ShellBox-flutter
flutter create . --platforms=android,windows
```

- 已存在的文件不会被覆盖（`flutter create` 只补缺失的脚手架）。
- 之后再执行 `flutter pub get` 安装依赖（版本锁定在 `pubspec.yaml`）。
- 若 `gradle-wrapper.jar` 仍缺失，在 `android/` 下执行 `gradle wrapper` 生成。

## 运行

```bash
flutter run -d windows     # Windows 桌面
flutter run -d <device>    # Android 真机/模拟器
flutter build windows
flutter build apk
```

## 与原版的差异（移植时做的取舍）

- **主机密钥校验**：使用 dartssh2 `onVerifyHostKey` 直接提供的 OpenSSH 风格
  `SHA256:...` 指纹做 TOFU（不自己重算字节）。
- **私钥文件来源**：Android 上 `file_picker` 会把选中文件复制到应用缓存，
  因此 `PrivateKeySource.file` 存的路径两端都能用 `dart:io` 读取。
- **保活**：Android 用 `flutter_background_service`（前台服务 + 常驻通知，
  需在系统设置/首次运行授予通知权限）；Windows 端为 no-op。
- **加密**：与 SSH 无关的落库加密用 `cryptography` 纯 Dart AES-256-GCM，
  主密钥存 Keystore/DPAPI；密文格式与原版一致 `base64(IV):base64(ct+tag)`。
- **虚拟键盘**：两排可拖拽排序的自定义按键（CTRL/ALT/SHIFT 锁定、方向键、翻页、
  Tab/Esc/回车/退格、软键盘、发送文本）。

## 已知待办

- `flutter analyze` / `flutter build` 前需要在装有 Flutter SDK 的机器上跑通首轮编译。
- 主机密钥变更（`SshHostKeyChanged`）时需先在「已知主机」里删除旧记录再重连
  （TOFU 语义与 sshj 原版一致）。
- SFTP 下载目标目录当前为应用文档目录（`getApplicationDocumentsDirectory`）。
- 从终端页返回时只释放了 xterm 桥接，未关闭该页的 SSH 会话/Tab（资源在 app 退出或
  最后一个连接关闭时统一回收）；正式版可改为返回即关闭本页所有会话。
- Android 13+ 首次使用保活服务需授予通知权限（README 已在首次构建提示）。
