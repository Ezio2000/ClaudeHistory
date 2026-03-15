# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

ClaudeHistory 是一个 macOS 菜单栏应用，用于浏览 Claude Code 的历史会话记录。它读取 `~/.claude/projects/` 目录下所有项目的 `.jsonl` 会话文件并展示。

Bundle ID: `com.claudehistory.app`

## 构建与运行

```bash
# 使用 xcodebuild 构建（Release 配置）
xcodebuild -project ClaudeHistory.xcodeproj -scheme ClaudeHistory -configuration Release build SYMROOT=$(pwd)/build

# 构建后运行
open build/Release/ClaudeHistory.app

# 或直接在 Xcode 中按 Cmd+R 运行
```

构建产物位于 `build/Build/Products/Release/ClaudeHistory.app`。

## 架构概览

这是一个纯 SwiftUI + AppKit 混合的 macOS 菜单栏应用，无外部依赖，共 4 个源文件：

```
ClaudeHistory/
├── ClaudeHistoryApp.swift   # 应用入口；AppDelegate 负责创建 NSStatusItem（菜单栏图标）和 NSPopover
├── ContentView.swift        # 所有 UI 视图：SessionListView / SessionRowView / SessionDetailSheet / MessageView
├── Session.swift            # 数据模型：ClaudeSession、ClaudeMessage、HistoryEntry
└── SessionViewModel.swift   # 业务逻辑：加载/搜索/删除会话（ObservableObject）
```

### 数据流

`~/.claude/projects/<项目目录>/<会话UUID>.jsonl` -> `SessionViewModel.loadSessions()` 解析 JSONL -> `ClaudeSession` + `ClaudeMessage` 模型 -> SwiftUI 视图渲染

### 关键设计点

- **菜单栏模式**：`NSApp.setActivationPolicy(.accessory)` 隐藏 Dock 图标；`NSPopover(.transient)` 点击外部自动关闭
- **数据来源**：遍历 `~/.claude/projects/` 下所有子目录，读取 `.jsonl` 文件（排除 `sessions-index.json`）
- **消息内容解析**：content 字段可能是字符串或数组，数组中包含 `text`/`tool_use`/`tool_result`/`thinking` 四种 type
- **消息类型标记**：通过内容字符串匹配识别工具调用（`🔧 工具调用`）、工具结果（`📊 工具结果`）、元数据（XML 标签前缀）
- **搜索防抖**：`$searchText.debounce(300ms)` 结合 `combineLatest($sessions)` 实现实时过滤
- **分页显示**：`SessionDetailSheet` 中每页固定 20 条消息，支持页码直接输入跳转
- **删除会话**：直接删除对应 `.jsonl` 文件，通过 `sessions.removeAll` 同步更新 UI

### 时间戳处理

JSONL 中的 `timestamp` 字段为 ISO8601 字符串，解析后转换为毫秒整数存储；显示时除以 1000 转回秒级 `TimeInterval`。
