import Foundation
import Combine
import os.log

class SessionViewModel: ObservableObject {
    @Published var sessions: [ClaudeSession] = []
    @Published var filteredSessions: [ClaudeSession] = []
    @Published var selectedSession: ClaudeSession?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let projectsPath = "\(NSHomeDirectory())/.claude/projects"
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .combineLatest($sessions) { text, sessions in
                if text.isEmpty {
                    return sessions
                }
                return sessions.filter { session in
                    session.id.contains(text.lowercased()) ||
                    session.previewText.localizedCaseInsensitiveContains(text)
                }
            }
            .assign(to: &$filteredSessions)
    }

    func loadSessions() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let projectsURL = URL(fileURLWithPath: self.projectsPath)
                guard FileManager.default.fileExists(atPath: self.projectsPath) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "项目目录不存在"
                        self.isLoading = false
                    }
                    return
                }

                var allSessions: [ClaudeSession] = []

                // 遍历所有项目目录
                let projectDirs = try FileManager.default.contentsOfDirectory(
                    at: projectsURL,
                    includingPropertiesForKeys: nil
                )

                for projectDir in projectDirs {
                    guard projectDir.hasDirectoryPath else { continue }

                    // 查找项目下的所有 .jsonl 会话文件
                    let sessionFiles = try FileManager.default.contentsOfDirectory(
                        at: projectDir,
                        includingPropertiesForKeys: nil
                    ).filter { $0.pathExtension == "jsonl" && $0.lastPathComponent != "sessions-index.json" }

                    for sessionFile in sessionFiles {
                        let content = try String(contentsOf: sessionFile, encoding: .utf8)
                        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

                        var messages: [ClaudeMessage] = []
                        let dateFormatter = ISO8601DateFormatter()
                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                        for line in lines {
                            if let data = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                                // 获取会话ID
                                var sessionId = json["sessionId"] as? String
                                if sessionId == nil {
                                    sessionId = sessionFile.deletingPathExtension().lastPathComponent
                                }

                                // 解析消息
                                if let message = json["message"] as? [String: Any],
                                   let role = message["role"] as? String,
                                   let content = message["content"] {

                                    // 转换为字符串
                                    var contentStr = ""
                                    if let str = content as? String {
                                        contentStr = str
                                    } else if let array = content as? [Any] {
                                        // 数组类型，提取各类型的内容
                                        var parts: [String] = []
                                        for item in array {
                                            if let dict = item as? [String: Any],
                                               let type = dict["type"] as? String {
                                                switch type {
                                                case "text":
                                                    if let text = dict["text"] as? String {
                                                        parts.append(text)
                                                    }
                                                case "tool_use":
                                                    // 工具调用 - 只显示参数
                                                    if let input = dict["input"] as? [String: Any] {
                                                        if let data = try? JSONSerialization.data(withJSONObject: input, options: .prettyPrinted),
                                                           let str = String(data: data, encoding: .utf8) {
                                                            parts.append(str)
                                                        }
                                                    } else if let name = dict["name"] as? String {
                                                        parts.append("工具: \(name)")
                                                    }
                                                case "tool_result":
                                                    // 工具结果 - 只显示内容
                                                    if let isError = dict["is_error"] as? Bool, isError {
                                                        parts.append("⚠️ 错误")
                                                    }
                                                    if let toolContent = dict["content"] as? String {
                                                        parts.append(toolContent)
                                                    }
                                                case "thinking":
                                                    if let thinking = dict["thinking"] as? String {
                                                        parts.append("💭 \(thinking)")
                                                    }
                                                default:
                                                    if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
                                                       let str = String(data: data, encoding: .utf8) {
                                                        parts.append(str)
                                                    }
                                                }
                                            }
                                        }
                                        contentStr = parts.joined(separator: "\n\n")
                                    } else {
                                        contentStr = "\(content)"
                                    }

                                    // 解析时间戳
                                    var timestamp: Int?
                                    if let tsStr = json["timestamp"] as? String {
                                        if let date = dateFormatter.date(from: tsStr) {
                                            timestamp = Int(date.timeIntervalSince1970 * 1000)
                                        }
                                    }

                                    // 提取模型名称
                                    let model = message["model"] as? String

                                    let msg = ClaudeMessage(
                                        id: UUID().uuidString,
                                        role: role,
                                        content: contentStr,
                                        timestamp: timestamp,
                                        model: model
                                    )
                                    messages.append(msg)
                                }
                            }
                        }

                        if !messages.isEmpty {
                            // 按时间戳排序消息，用最早的消息时间作为会话时间
                            let sortedMessages = messages.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }

                            let sessionId = sessionFile.deletingPathExtension().lastPathComponent
                            let sessionTimestamp = sortedMessages.first?.timestamp ?? Int(Date().timeIntervalSince1970 * 1000)

                            os_log("Session %@: %d messages, timestamp: %d", type: .info, String(sessionId.prefix(8)), sortedMessages.count, sessionTimestamp)

                            let session = ClaudeSession(
                                id: sessionId,
                                timestamp: sessionTimestamp,
                                messages: sortedMessages
                            )
                            allSessions.append(session)
                        }
                    }
                }

                // 按时间排序
                allSessions.sort { $0.timestamp > $1.timestamp }

                DispatchQueue.main.async {
                    self.sessions = allSessions
                    self.isLoading = false
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func deleteSession(_ session: ClaudeSession) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let projectsURL = URL(fileURLWithPath: self.projectsPath)

                // 遍历所有项目目录查找会话文件
                let projectDirs = try FileManager.default.contentsOfDirectory(
                    at: projectsURL,
                    includingPropertiesForKeys: nil
                )

                for projectDir in projectDirs {
                    guard projectDir.hasDirectoryPath else { continue }

                    let sessionFile = projectDir.appendingPathComponent("\(session.id).jsonl")

                    if FileManager.default.fileExists(atPath: sessionFile.path) {
                        try FileManager.default.removeItem(at: sessionFile)

                        DispatchQueue.main.async {
                            self.sessions.removeAll { $0.id == session.id }
                        }
                        return
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func deleteOldSessions() {
        // TODO: 实现删除旧会话
    }
}
