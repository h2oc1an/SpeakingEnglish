# SpeakingEnglish/讲英格力士

一款帮助用户通过视频学习英语的 iOS 应用，支持本地视频播放、语音转录、字幕翻译、字幕生词本等功能。

## 功能特性

### 视频学习
- 支持本地 MP4 视频播放
- 支持 SRT/ASS 格式外挂字幕
- 字幕与视频同步显示
- 点击字幕中的单词添加到生词本

### 语音转录（后台任务）
- 使用 WhisperKit 本地 AI 模型转录
- 支持 iOS 设备端运行，无需网络
- 后台执行，关闭页面不影响
- 转录完成后推送通知
- 支持查看任务列表、取消、删除
- 转录完成的视频和字幕支持导入到视频库

### 字幕翻译（后台任务）
- 选择 SRT/ASS 字幕文件翻译为中文
- 后台执行，关闭页面不影响
- 翻译完成后推送通知
- 支持下载/分享翻译后的字幕文件

### 生词本
- 自动提取字幕中的单词
- 支持手动添加单词和例句
- SM-2 间隔重复算法安排复习

### 复习系统
- 基于 SM-2 间隔重复算法
- 科学安排复习时间
- 支持六档评分：完全忘记/困难/困难+/良好/简单/完美
- 复习完成后可再复习

### 设置与复习
整合在同一个页面：
- **设置**：学习统计、关于应用、使用帮助、重置数据
- **复习**：单词复习卡片流程

## 项目结构

```
SpeakingEnglish/
├── App/                    # 应用入口
│   ├── SpeakingEnglishApp.swift
│   └── ContentView.swift
├── Core/
│   ├── Models/            # 数据模型
│   │   ├── Video.swift
│   │   ├── SubtitleEntry.swift
│   │   ├── VocabularyEntry.swift
│   │   └── ReviewRecord.swift
│   ├── Services/          # 核心服务
│   │   ├── TranscriptionService.swift    # WhisperKit 转录
│   │   ├── TranscriptionTaskManager.swift # 转录任务管理
│   │   ├── TranslationService.swift      # Bing 翻译
│   │   ├── TranslationTaskManager.swift  # 翻译任务管理
│   │   ├── SubtitleParser/              # 字幕解析
│   │   ├── SM2Algorithm.swift            # 间隔重复算法
│   │   ├── VocabularyService.swift
│   │   └── WordExtractionService.swift
│   └── Persistence/       # 数据持久化
│       ├── DatabaseManager.swift
│       ├── VideoRepository.swift
│       └── VocabularyRepository.swift
├── Features/
│   ├── Home/              # 首页视频列表
│   ├── VideoPlayer/       # 视频播放 + 字幕叠加
│   ├── Transcription/     # 转录页面 + 任务列表
│   ├── Translation/       # 翻译页面 + 任务列表
│   ├── Vocabulary/        # 生词本列表/详情
│   └── Settings/          # 设置与复习整合页面
├── Shared/                # 共享组件
│   ├── DocumentPicker.swift
│   ├── SubtitleListView.swift
│   └── Extensions/
├── Resources/
│   ├── Info.plist
│   ├── WhisperModels/     # WhisperKit 本地模型
│   └── SampleVideos/       # 示例视频目录
└── project.yml            # XcodeGen 配置
```

## 技术栈

| 类别 | 技术 |
|-----|------|
| UI 框架 | SwiftUI |
| 视频播放 | AVPlayer + AVKit |
| 语音识别 | WhisperKit (openai_whisper-tiny) |
| 字幕翻译 | Microsoft Translator API |
| 数据持久化 | SQLite.swift |
| 项目生成 | XcodeGen |
| 包管理 | Swift Package Manager |

## 环境要求

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9

## 快速开始

### 1. 安装依赖

```bash
# 安装 XcodeGen（如果未安装）
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate
```

### 2. 配置签名（可选）

在 Xcode 中打开 `SpeakingEnglish.xcodeproj`，选择 Signing & Capabilities 配置团队账号。

> **注意**：需要开发者账号。

### 3. 添加示例视频

将 MP4 视频和对应的 SRT/ASS 字幕文件放入 `Resources/SampleVideos/` 目录。

### 4. 构建运行

```bash
# 使用 xcodebuild 构建
xcodebuild -project SpeakingEnglish.xcodeproj -scheme SpeakingEnglish -configuration Debug build

# 或在 Xcode 中打开项目并运行
open SpeakingEnglish.xcodeproj
```

## 使用说明

### 转录视频

1. 进入「转录」页面
2. 选择本地 MP4 视频文件
3. 点击「开始转录」
4. 页面显示任务列表和进度
5. 转录完成后可选择：
   - 查看详情和字幕预览
   - 翻译字幕为中文
   - 导入到视频库
   - 下载字幕文件

### 翻译字幕

1. 进入「翻译」页面
2. 选择 SRT/ASS 字幕文件
3. 自动添加翻译任务
4. 可查看任务进度
5. 翻译完成后可下载/分享

### 观看视频学习

1. 在首页选择已上传的视频
2. 视频播放时字幕同步显示
3. 点击任意单词添加到生词本
4. 在生词本中查看释义和例句

### 复习记忆

1. 进入「设置与复习」页面
2. 切换到「复习」标签
3. 根据记忆情况选择评分
4. 系统使用 SM-2 算法安排下次复习时间
5. 定期复习直到完全掌握

### 设置

- **学习统计**：查看总单词数、待复习数、今日已学
- **关于应用**：应用介绍和版本信息
- **使用帮助**：使用说明和常见问题
- **数据重置**：清除所有本地数据

## 已知限制

1. **WhisperKit 模型**：首次使用需要 Core ML 模型，已预置在 Resources/WhisperModels 目录
2. **翻译 API**：使用 Microsoft Translator API，需要网络连接

## License

MIT License
