import SwiftUI

struct ContentView: View {
    var body: some View {
        EmptyView()
    }
}

struct SessionListView: View {
    @ObservedObject var viewModel: SessionViewModel
    @State private var searchText = ""
    @State private var selectedSession: ClaudeSession?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索会话...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchText = newValue
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 会话列表
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重新加载") {
                        viewModel.loadSessions()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewModel.filteredSessions.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(viewModel.searchText.isEmpty ? "暂无会话记录" : "未找到匹配结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredSessions) { session in
                            SessionRowView(session: session, viewModel: viewModel)
                                .onTapGesture {
                                    selectedSession = session
                                }
                            Divider()
                        }
                    }
                }
            }

            // 底部状态栏
            HStack {
                Text("\(viewModel.filteredSessions.count) 个会话")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { viewModel.loadSessions() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("刷新")
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }
}

struct SessionRowView: View {
    let session: ClaudeSession
    @ObservedObject var viewModel: SessionViewModel
    @State private var showDeleteFeedback = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "message")
                        .foregroundColor(.blue)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.previewText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text(session.dateString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(session.id.prefix(8))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text("\(session.messageCount) 条")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.separatorColor))
                    .cornerRadius(4)

                Button(action: {
                    viewModel.deleteSession(session)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDeleteFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            showDeleteFeedback = false
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: showDeleteFeedback ? "checkmark" : "trash")
                            .font(.caption)
                        if showDeleteFeedback {
                            Text("已删除")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(showDeleteFeedback ? .green : .red)
                }
                .buttonStyle(.plain)
                .help("删除会话")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

struct SessionDetailSheet: View {
    let session: ClaudeSession
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 1
    @State private var searchText = ""
    @State private var searchInput = ""

    private let pageSize = 20

    private var totalPages: Int {
        guard let messages = session.messages else { return 1 }
        return (messages.count + pageSize - 1) / pageSize
    }

    private var filteredMessages: [ClaudeMessage] {
        guard let messages = session.messages else { return [] }
        if searchText.isEmpty {
            return messages
        }
        return messages.filter { message in
            message.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var currentPageMessages: [ClaudeMessage] {
        let start = (currentPage - 1) * pageSize
        let end = min(start + pageSize, filteredMessages.count)
        if start >= filteredMessages.count {
            return []
        }
        return Array(filteredMessages[start..<end])
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                VStack(alignment: .leading) {
                    Text(session.dateString)
                        .font(.headline)
                    Text("ID: \(session.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 分页和搜索工具栏
            HStack(spacing: 12) {
                // 搜索框
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索消息...", text: $searchInput)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            searchText = searchInput
                            currentPage = 1
                        }
                    if !searchInput.isEmpty {
                        Button(action: { searchInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        searchText = searchInput
                        currentPage = 1
                    }) {
                        Text("搜索")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)

                Spacer()

                // 分页控制
                HStack(spacing: 8) {
                    Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage <= 1)

                    // 页码输入
                    HStack(spacing: 4) {
                        Text("第")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("", value: $currentPage, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 35)
                            .multilineTextAlignment(.center)
                            .onChange(of: currentPage) { _, newValue in
                                if newValue < 1 { currentPage = 1 }
                                if newValue > totalPages { currentPage = totalPages }
                            }
                        Text("/ \(totalPages)页")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: { if currentPage < totalPages { currentPage += 1 } }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage >= totalPages)

                    Text("共 \(filteredMessages.count) 条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 消息列表
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if currentPageMessages.isEmpty {
                        VStack {
                            Text(searchText.isEmpty ? "暂无消息" : "未找到匹配结果")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(currentPageMessages) { message in
                            MessageView(message: message)
                                .id(message.id)
                            if message.id != currentPageMessages.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            currentPage = 1
        }
    }
}

struct MessageView: View {
    let message: ClaudeMessage
    @State private var isExpanded = false
    @State private var showCopyFeedback = false

    private let maxLines = 5

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private var dateFormatter: DateFormatter {
        Self.dateFormatter
    }

    // 估算是否需要折叠
    private var needsCollapse: Bool {
        let lineCount = message.content.components(separatedBy: .newlines).count
        let charCount = message.content.count
        // 考虑 JSON 格式化后的实际行数
        let estimatedLines = max(lineCount, charCount / 80) // 假设每行约80字符
        // 只有超过5行时才折叠（刚好5行不折叠）
        return estimatedLines > maxLines
    }

    // 计算应该使用的行数限制
    private var effectiveLineLimit: Int? {
        if needsCollapse && !isExpanded {
            return maxLines
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(message.role == "user" ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: message.role == "user" ? "person" : "brain")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.displayRole)
                        .font(.headline)
                    if message.isMetaData {
                        Text("元数据")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(4)
                    }
                    if message.isToolUse {
                        if let toolName = message.toolType {
                            Text("🔧 \(toolName)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        } else {
                            Text("🔧 工具调用")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                    if message.isToolResult {
                        Text("📊 工具结果")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(4)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text(dateFormatter.string(from: message.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopyFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                withAnimation {
                                    showCopyFeedback = false
                                }
                            }
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                if showCopyFeedback {
                                    Text("已复制")
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(showCopyFeedback ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("复制内容")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .lineLimit(effectiveLineLimit)
                        .allowsHitTesting(false)

                    // 根据估算结果显示展开/折叠按钮
                    if needsCollapse {
                        Button(action: { isExpanded.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                                Text(isExpanded ? "收起" : "展开")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(message.isMetaData ? Color.orange.opacity(0.05) :
                   (message.isToolUse ? Color.blue.opacity(0.05) :
                   (message.isToolResult ? Color.green.opacity(0.05) :
                   (message.role == "user" ? Color.blue.opacity(0.05) : Color.clear))))
    }
}

#Preview {
    SessionListView(viewModel: SessionViewModel())
}
