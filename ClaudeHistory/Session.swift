import Foundation

struct ClaudeMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let timestamp: Int?
    let model: String? // 模型名称

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp ?? 0) / 1000)
    }

    // 判断是否是元数据消息
    var isMetaData: Bool {
        let metaPatterns = [
            "<local-command-caveat>",
            "<command-name>",
            "<command-",
            "<local-command-"
        ]
        return metaPatterns.contains { content.contains($0) }
    }

    // 判断是否包含工具调用
    var isToolUse: Bool {
        content.contains("🔧 工具调用")
    }

    // 判断是否包含工具结果
    var isToolResult: Bool {
        content.contains("📊 工具结果")
    }

    // 获取工具类型（如果有的话）
    var toolType: String? {
        if isToolUse {
            // 提取工具名称，如 "🔧 工具调用: Bash" -> "Bash"
            if let range = content.range(of: "🔧 工具调用: ") {
                let afterColon = content[range.upperBound...]
                if let newlineRange = afterColon.range(of: "\n") {
                    return String(afterColon[..<newlineRange.lowerBound])
                }
                return afterColon.components(separatedBy: "\n").first
            }
        } else if isToolResult {
            // 工具结果可能是多个
            return "工具结果"
        }
        return nil
    }

    // 获取显示名称
    var displayRole: String {
        if role == "assistant", let model = model {
            return model
        }
        return role == "user" ? "你" : "助手"
    }
}

struct ClaudeSession: Codable, Identifiable {
    let id: String
    let timestamp: Int
    let messages: [ClaudeMessage]?

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    var messageCount: Int {
        messages?.count ?? 0
    }

    var previewText: String {
        guard let msgs = messages, !msgs.isEmpty else {
            return "空会话"
        }

        // 预览显示第一条非元数据的用户消息
        let firstUserMessage = msgs.first(where: { message in
            message.role == "user" && !message.isMetaData && !message.content.isEmpty
        })?.content ?? ""

        if firstUserMessage.isEmpty {
            return "无有效用户消息"
        }
        return String(firstUserMessage.prefix(100)) + (firstUserMessage.count > 100 ? "..." : "")
    }
}

struct HistoryEntry: Codable {
    let sessionId: String
    let timestamp: Int
    let role: String?
    let content: String?

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
}
