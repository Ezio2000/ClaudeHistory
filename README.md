# ClaudeHistory

一个 macOS 菜单栏应用，用于快速浏览和搜索 Claude Code 的历史会话记录。

## 功能特性

- 常驻菜单栏，点击 💬 图标即可展开会话列表
- 支持按关键词搜索会话
- 点击会话查看完整对话详情，支持分页浏览（每页 20 条）
- 详情内支持消息内容搜索
- 一键复制消息内容到剪贴板
- 支持删除单条会话记录
- 自动识别并高亮展示工具调用、工具结果、元数据等特殊消息类型

## 安装

### 方式一：从预发布版本下载（推荐）

1. 前往 [Releases](https://github.com/Ezio2000/ClaudeHistory/releases) 页面
2. 下载最新版本的 `ClaudeHistory.dmg`
3. 双击打开 DMG 文件
4. 将 `ClaudeHistory.app` 拖入 `Applications` 文件夹
5. 在启动台或 Finder 中打开应用

> **首次打开提示**：macOS 可能会提示"无法验证开发者"。请前往「系统设置 → 隐私与安全性」，找到对应提示后点击「仍要打开」即可。

### 方式二：从源码构建

**前提**：已安装 Xcode（版本 15 及以上）。

```bash
# 克隆仓库
git clone https://github.com/Ezio2000/ClaudeHistory.git
cd ClaudeHistory

# 构建 Release 版本
xcodebuild -project ClaudeHistory.xcodeproj \
           -scheme ClaudeHistory \
           -configuration Release \
           build \
           SYMROOT=$(pwd)/build

# 运行
open build/Build/Products/Release/ClaudeHistory.app

# 或打包为 DMG（可选）
mkdir -p dist
cp -R build/Build/Products/Release/ClaudeHistory.app dist/
hdiutil create -volname "ClaudeHistory" -srcfolder dist -ov -format UDZO -imagekey zlib-level=9 dist/ClaudeHistory.dmg
```

## 使用指南

### 启动应用

打开应用后，Dock 栏不会出现图标（这是正常的菜单栏应用行为）。
顶部菜单栏右侧会出现 💬 图标，点击即可打开会话列表弹窗。

### 会话列表

| 操作 | 说明 |
|------|------|
| 点击 💬 图标 | 展开 / 收起会话列表 |
| 在搜索框输入 | 实时过滤会话（匹配会话 ID 或首条用户消息） |
| 点击 × | 清空搜索内容 |
| 点击会话行 | 打开该会话的详情窗口 |
| 点击 🗑 删除 | 删除该条会话（同时删除本地 `.jsonl` 文件） |
| 点击刷新按钮 | 重新从磁盘加载所有会话数据 |
| 点击弹窗外部 | 关闭弹窗 |

### 会话详情

点击任意会话后会打开详情窗口，显示完整的对话消息。

| 操作 | 说明 |
|------|------|
| 搜索框 + 按下 Return / 点击「搜索」 | 在当前会话内搜索关键词 |
| 左右箭头 / 页码输入框 | 翻页浏览消息（每页 20 条） |
| 点击「展开 / 收起」 | 折叠或展开超过 5 行的长消息 |
| 点击复制图标 | 复制该条消息的完整内容到剪贴板 |
| 点击「关闭」或按 Esc | 关闭详情窗口 |

### 消息类型说明

| 标识 | 含义 |
|------|------|
| 蓝色背景 | 用户消息 |
| 无背景 | 助手（Claude）回复 |
| 🔧 工具调用 | Claude 调用了某个工具（如 Bash、Read 等） |
| 📊 工具结果 | 工具执行的返回结果 |
| 橙色背景 + 元数据标签 | 系统注入的元数据消息（如命令回显等） |

### 数据来源

应用读取本机 `~/.claude/projects/` 目录下所有项目的会话文件（`.jsonl` 格式），这是 Claude Code 在本机自动生成的会话记录。无需任何额外配置，打开应用即可看到历史记录。

> **注意**：删除会话操作会直接删除本地 `.jsonl` 文件，不可恢复，请谨慎操作。

## 项目结构

```
ClaudeHistory/
├── ClaudeHistory.xcodeproj/    # Xcode 项目文件
├── ClaudeHistory/
│   ├── ClaudeHistoryApp.swift  # 应用入口，菜单栏图标与弹窗管理
│   ├── ContentView.swift       # 全部 UI 视图
│   ├── Session.swift           # 数据模型（ClaudeSession、ClaudeMessage）
│   ├── SessionViewModel.swift  # 业务逻辑，读取/搜索/删除会话
│   └── Info.plist
├── .gitignore
├── CLAUDE.md                   # 开发文档（架构、构建命令、关键设计点）
└── README.md
```

> **注**：`build/` 和 `dist/` 目录为本地构建产物，不入库。预编译的 DMG 发布在 [Releases](https://github.com/Ezio2000/ClaudeHistory/releases)。

## 系统要求

- macOS 13 Ventura 及以上
- 已安装并使用过 Claude Code（需存在 `~/.claude/projects/` 目录）
