<!-- markdownlint-disable MD033 -->
# arabic_learning | Ar 学

<p align="center">
    <img src="https://github.com/OctagonalStar/arabic_learning/actions/workflows/FlutterBuild.yml/badge.svg" alt="Flutter Build">
    <img src="https://img.shields.io/badge/License-AGPL_3.0-blue.svg" alt="License: AGPL-3.0">
</p>

一个跨平台的阿拉伯语 ~~背单词~~ 单词学习软件，支持 **Android / Windows / Linux / macOS / Web**。

## 功能

### 学习

- 选择课程进行单词学习
- 多种题型可自由配置与排序：单词卡片、中译阿选择题、阿译中选择题、拼写题、听力题
- 题型内/题型间/全局三级乱序
- 偏好易混词或同课词

### 规律复习（FSRS）

> [!TIP]
> 你需要手动启用复习功能才会生效

- 基于 [FSRS](https://github.com/open-spaced-repetition/fsrs4anki) 算法的间隔重复复习
- 可自由配置期望提取率、评分限时（优秀/良好）
- 自我评级模式
- 每日单词推送，学习即加入复习计划
- 强化记忆循环：同一到期卡片在队列中交错出现多次

### 测试

- **自主听写**：配置播放速度/次数/间隔，听写期间不熄屏
- **局域网联机对战**：通过 WebRTC 实现，支持扫码/口令连接，双方实时 PK

### 词库管理

- 从Github[此仓库](https://github.com/JYinherit/Arabiclearning)线上下载词库
- 本地 JSON 文件导入
- 词汇总览：按词库-课程分级展示，支持网格列数自定义
- 词汇查找：阿语/中文双向搜索，支持 BK 树模糊匹配及编辑距离容错

### 数据同步

- **WebDAV** 远程备份与恢复
- 本地数据导出/导入（JSON 文件）

### 音频与 TTS

- 系统 TTS / 在线 TTS/ 神经网络语音合成（sherpa-onnx / VITS）
- 播放速度可调（0.5x – 1.5x）
- 自动播放发音（学习中进入阿译中选择题时自动朗读）

### 个性化

- 多种主题色
- Material UI
- 深色模式
- 备用字体（阿语 Vazirmatn / 中文 NotoSansSC）

### 统计

- 连胜天数
- 已学词汇
- 待复习数量
- 词库单词总数

## 平台

| 平台 | 支持 |
| ------ | ------ |
| Android | ✅ |
| Windows | ✅ |
| Linux | ✅ (请自行构建) |
| macOS | ✅ |
| iOS | 已在v0.1.12终止支持 |
| Web | ✅ [在线体验](https://octagonalstar.github.io/arabic_learning/) |

> 网页版为最新构建版，相对于软件版本可能有更多功能和更多 bug。

## 技术栈

- **框架**：Flutter/Dart
- **状态管理**：Provider
- **复习算法**：FSRS
- **音频**：flutter_tts / just_audio / sherpa_onnx
- **联机**：flutter_webrtc
- **同步**：webdav_client
- **搜索**：BK 树
- **存储**：shared_preferences / idb_shim（Web IndexedDB）

## 构建

```bash
flutter pub get
flutter run
```

各平台构建产物参见 GitHub Releases 和 Github Action。

## 许可证

[AGPL-3.0](LICENSE)

Copyright (C) 2025 OctagonalStar
