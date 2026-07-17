<p align="center">
  <img src="Resources/EUNOIA.png" alt="Eunoia" width="200"/>
</p>

<h1 align="center">Eunoia</h1>

一款帮助用户通过视频学习多语言的应用，支持 **iOS** 和 **macOS 原生** 两个版本。

> **Eunoia** 源自希腊语 εὔνοια，意为「美好的心意」。在古典修辞学中，它指演讲者与听众之间的善意联结——这也是语言学习的本质：用真诚的表达，跨越文化，建立理解。

| 版本 | 分支 | 说明 |
|-----|------|------|
| **iOS 当前开发版** | `main` | 最新 iOS 开发代码 |
| **iOS 迭代备份 v1** | `v1` | iOS 早期稳定版本 |
| **iOS 迭代备份 v2** | `v2` | iOS 添加了视频下载等功能 |
| **macOS 原生** | `macos` | 适用于 Mac，采用 NavigationSplitView + 卡片式 UI，AVPlayerView 原生播放 |

---

## 功能特性

两个版本共享核心功能，UI 和交互针对各自平台做了适配：

### 视频下载
- 支持 **YouTube** 视频下载（自动解析直链）
- 支持 **Bilibili** 视频下载（原生 API + WBI 签名）
- 支持直接视频 URL 下载（MP4/MKV/MOV 等）
- URLSession 后台下载，支持暂停/恢复
- 下载完成后可选生成字幕（WhisperKit 转录 + 翻译）
- 画质/格式选择（多格式时）

### 视频学习
- 支持本地 MP4 视频播放
- 支持 SRT/ASS 格式外挂字幕
- 字幕与视频同步显示
- 点击字幕中的单词添加到生词本
- **播放速度控制**：0.5x ~ 2.0x 倍速播放
- **记忆播放位置**：自动跳转到上次观看进度
- **书签/笔记**：在任意时间点添加书签和备注
- **播放器内生成字幕**：无字幕视频可一键转录

> **平台差异**：
> - iOS：支持左右滑动手势调节进度、双击暂停/播放、全屏播放
> - macOS：使用原生 AVPlayerView（controlsStyle: .inline），支持 Escape 键返回

### 视频语音转录（多语言识别 → 字幕文件）
- 使用 WhisperKit 本地 AI 模型转录
- 支持三种字幕模式：原语言 / 中文字幕 / 双语字幕
- 设备端运行，无需网络
- 后台执行，关闭页面不影响
- 支持查看任务列表、取消、删除
- 转录完成后可导入到视频库

> **平台差异**：
> - iOS：转录完成后推送本地通知
> - macOS：通过任务列表查看进度

### 字幕翻译（多语言 → 中文）
- 支持两种字幕模式：中文字幕 / 双语字幕
- 选择 SRT/ASS 字幕文件翻译为中文
- 后台执行，关闭页面不影响
- 支持下载/分享翻译后的字幕文件

### 生词本
- 自动提取字幕中的单词
- 支持手动添加单词和例句
- SM-2 间隔重复算法安排复习

### 复习系统
- 基于 SM-2 间隔重复算法
- 科学安排复习时间
- 支持六档评分：完全忘记 / 困难 / 困难+ / 良好 / 简单 / 完美
- 复习完成后可再复习

---

## 项目结构

```
Eunoia/
├── App/                    # 应用入口
│   ├── EunoiaApp.swift
│   ├── ContentView.swift
│   └── macOS/              # macOS 专属（仅 macos 分支）
│       └── MenuBarCommands.swift
├── Core/
│   ├── Models/            # 数据模型
│   ├── Services/          # 核心服务
│   │   ├── DownloadService.swift
│   │   ├── YouTubeExtractor.swift
│   │   ├── BilibiliExtractor.swift
│   │   ├── TranscriptionService.swift      # WhisperKit 转录
│   │   ├── TranslationService.swift        # Microsoft Translator
│   │   ├── SubtitleParser/                # SRT/ASS 解析
│   │   ├── SM2Algorithm.swift              # 间隔重复算法
│   │   └── ...
│   └── Persistence/       # SQLite 数据持久化
├── Features/
│   ├── Home/              # 首页视频列表
│   ├── VideoPlayer/       # 视频播放
│   │   ├── PlatformVideoPlayer.swift       # macOS AVPlayerView（仅 macos 分支）
│   │   └── Subviews/
│   ├── Download/          # 视频下载
│   ├── Transcription/     # 转录任务
│   ├── Translation/       # 字幕翻译
│   ├── Vocabulary/        # 生词本
│   └── Settings/          # 设置与复习
├── Shared/                # 共享组件
└── Resources/
    ├── WhisperModels/     # WhisperKit 本地模型
    └── SampleVideos/      # 示例视频
```

---

## 技术栈

| 类别 | iOS 版本 | macOS 版本 |
|-----|---------|-----------|
| 平台 | iOS 16.0+ | macOS 13.0+ |
| UI 框架 | SwiftUI (TabView) | SwiftUI (NavigationSplitView) |
| 视频播放 | AVPlayer + AVKit | AVPlayerView (原生) |
| 语音识别 | WhisperKit (openai_whisper-tiny) | WhisperKit (openai_whisper-tiny) |
| 字幕翻译 | Microsoft Translator API | Microsoft Translator API |
| 数据持久化 | SQLite.swift | SQLite.swift |
| 项目生成 | XcodeGen | XcodeGen |

---

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/h2oc1an/Eunoia.git
cd Eunoia
```

### 2. 安装 XcodeGen

```bash
brew install xcodegen
```

---

### iOS 版本（main 分支）

```bash
# 确保在 main 分支
git checkout main

# 生成 Xcode 项目
xcodegen generate

# 构建运行
xcodebuild -project Eunoia.xcodeproj -scheme Eunoia -configuration Debug build

# 或在 Xcode 中打开
open Eunoia.xcodeproj
```

> **环境要求**：Xcode 15.0+，iOS 16.0+

---

### macOS 原生版本（macos 分支）

```bash
# 切换到 macos 分支
git checkout macos

# 生成 Xcode 项目
xcodegen generate

# 构建运行（关闭代码签名）
xcodebuild -project Eunoia.xcodeproj -scheme Eunoia-macOS -configuration Debug build CODE_SIGNING_ALLOWED=NO

# 或在 Xcode 中打开，选择 Eunoia-macOS scheme
open Eunoia.xcodeproj
```

> **环境要求**：Xcode 15.0+，macOS 13.0+  
> **注意**：运行时请选择 `Eunoia-macOS` scheme，不要选择 `My Mac (Designed for iPad)`。

---

## 使用说明

### 下载视频

1. 首页点击添加按钮 →「下载视频」
2. 粘贴视频链接（支持 YouTube、Bilibili、直链）
3. 点击「解析并下载」，多格式时可选择画质
4. 下载完成后点击「导入」将视频添加到首页
5. 导入后可点击「转录」生成字幕

### 转录视频

1. 进入「转录」页面
2. 选择本地 MP4 视频文件
3. 选择字幕模式：原语言 / 中文字幕 / 双语字幕
4. 点击「开始转录」
5. 页面显示任务列表和进度
6. 转录完成后可导入到视频库

### 翻译字幕

1. 进入「翻译」页面
2. 选择 SRT/ASS 字幕文件
3. 选择字幕模式：中文字幕 / 双语字幕
4. 点击「开始翻译」
5. 翻译完成后可下载/分享

### 观看视频学习

1. 在首页选择已上传的视频
2. 视频播放时字幕同步显示
3. 点击任意单词添加到生词本
4. 在生词本中查看释义和例句

### 复习记忆

1. 进入「设置」页面
2. 切换到「复习」标签（iOS）或直接进入复习（macOS）
3. 根据记忆情况选择评分
4. 系统使用 SM-2 算法安排下次复习时间

---

## 其他

1. **转录模型**：使用 openai_whisper-tiny，已预置在 `Resources/WhisperModels/` 目录，无需下载
2. **翻译 API**：使用 Microsoft Translator API，需要网络连接

## License

See [LICENSE](LICENSE) for details.
