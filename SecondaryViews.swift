import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(HealthStore.self) private var store
    private let suggestions = ["根据我今天的数据，最该先改善什么？", "我的活动量和恢复状态怎么样？", "给我一个今天能做到的健康行动"]
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if store.chatMessages.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: "sparkles").font(.title2).foregroundStyle(AppTheme.accent)
                                    Text("和本地 AI 聊聊你的健康").font(.title2.bold())
                                    Text("问题和健康记录只在本机处理。先选一个建议开始。\(store.selectedGGUFModelID == nil ? "请先在设置中下载模型。" : "")").font(.subheadline).foregroundStyle(AppTheme.secondary)
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button(suggestion) { store.askAI(suggestion) }.buttonStyle(.bordered).tint(AppTheme.accent)
                                    }
                                }.padding(.top, 30)
                            } else {
                                ForEach(store.chatMessages) { message in
                                    ChatBubble(message: message).id(message.id)
                                }
                                if store.isChatting {
                                    HStack(spacing: 10) {
                                        ThinkingOrb(state: .working, size: 28)
                                        Text("正在思考…").foregroundStyle(AppTheme.secondary)
                                    }.padding(.vertical, 8)
                                }
                                if let last = store.chatMessages.last, last.role == .assistant {
                                    Button("继续追问：刚才的建议怎么执行？") { store.askAI("刚才的建议怎么执行？") }.font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                                }
                            }
                        }.padding(20)
                    }.onChange(of: store.chatMessages.count) { _, _ in if let id = store.chatMessages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
                }
                HStack(spacing: 10) { TextField("问问你的健康…", text: Bindable(store).chatInput, axis: .vertical).lineLimit(1...4).submitLabel(.send).onSubmit { store.askAI(store.chatInput) }.padding(11).background(AppTheme.canvas).clipShape(RoundedRectangle(cornerRadius: 14)); Button { store.askAI(store.chatInput) } label: { Image(systemName: "arrow.up").foregroundStyle(.white).frame(width: 36, height: 36).background(AppTheme.accent).clipShape(Circle()) }.disabled(store.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isChatting); Button("完成") { hideKeyboard() }.font(.caption).foregroundStyle(AppTheme.secondary) }.padding(12).background(.white)
            }.background(AppTheme.canvas).contentShape(Rectangle()).onTapGesture { hideKeyboard() }.scrollDismissesKeyboard(.interactively).navigationTitle("AI 对话").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { store.newChat() } label: { Label("新对话", systemImage: "square.and.pencil") } } }
        }
    }
}

private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

struct ChatBubble: View {
    let message: ChatMessage
    var body: some View { HStack { if message.role == .assistant { Image(systemName: "sparkles").foregroundStyle(AppTheme.accent) }; Text(message.text).padding(13).background(message.role == .user ? AppTheme.accent : .white).foregroundStyle(message.role == .user ? .white : AppTheme.ink).clipShape(RoundedRectangle(cornerRadius: 16)); if message.role == .user { Spacer(minLength: 40) } }.frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading) }
}

struct InsightsView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 18) { Text("AI 洞察").font(.largeTitle.bold()); Text("基于你的真实数据，生成可执行的健康建议").foregroundStyle(AppTheme.secondary); Button { store.runAnalysis() } label: { HStack(spacing: 10) { if store.isAnalyzing { ThinkingOrb(state: .searching, size: 24) } else { Image(systemName: "sparkles") }; Text(store.isAnalyzing ? "正在分析你的数据…" : "重新分析当前数据") }.frame(maxWidth: .infinity).padding(15).background(AppTheme.lavender).clipShape(RoundedRectangle(cornerRadius: 15)) }.buttonStyle(.plain); if store.insights.isEmpty { Text("连接 Apple 健康或添加数据后，AI 才会生成建议。").foregroundStyle(AppTheme.secondary).padding(.vertical, 24) } else { ForEach(store.insights) { InsightPreview(insight: $0) } } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar) } }
}

struct DataView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { HStack { Text("健康数据").font(.largeTitle.bold()); Spacer(); Button { store.showAddMetric = true } label: { Image(systemName: "plus").foregroundStyle(.white).frame(width: 38, height: 38).background(AppTheme.accent).clipShape(Circle()) } }; Text("数据越完整，AI 的建议越贴合你").foregroundStyle(AppTheme.secondary); if store.metrics.isEmpty { Text("还没有记录。连接 Apple 健康或点击右上角添加一条数据。").foregroundStyle(AppTheme.secondary).padding(.vertical, 30) } else { chart; SectionTitle(title: "全部指标"); ForEach(store.metrics) { metric in SoftCard { HStack { Image(systemName: metric.icon).foregroundStyle(Color(hex: metric.colorHex)); Text(metric.title); Spacer(); Text(metric.value).bold(); Text(metric.unit).font(.caption).foregroundStyle(AppTheme.secondary) } } } } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar) } }
    private var chart: some View { SoftCard { VStack(alignment: .leading, spacing: 14) { HStack { Text("健康数据").bold(); Spacer(); Text("当前记录").foregroundStyle(AppTheme.accent) }; Text("趋势图会在积累多天真实数据后显示。").font(.caption).foregroundStyle(AppTheme.secondary) } } }
}

struct SettingsView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { Text("我的设置").font(.largeTitle.bold()); modelCard; SoftCard { VStack(spacing: 0) { setting(icon: "heart.text.square.fill", title: "Apple 健康", detail: store.isSyncingHealth ? "正在同步…" : (store.isHealthConnected ? "已连接" : "点击授权"), color: .red) { store.connectHealth() }; Divider(); setting(icon: "bell.badge.fill", title: "每日提醒", detail: store.reminderEnabled ? "每天 20:30" : "已关闭", color: .orange) { store.showReminderSettings = true }; Divider(); setting(icon: "lock.fill", title: "隐私与数据", detail: "本地优先", color: AppTheme.accent) { store.showPrivacyDetails = true } } } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar).sheet(isPresented: Bindable(store).showReminderSettings) { ReminderView() }.sheet(isPresented: Bindable(store).showPrivacyDetails) { PrivacyView() } } }
    private var modelCard: some View { SoftCard { VStack(alignment: .leading, spacing: 12) { HStack { VStack(alignment: .leading) { Text("本地 GGUF 模型").bold(); Text("数据只在你的 iPhone 上处理").font(.caption).foregroundStyle(AppTheme.secondary) }; Spacer(); Image(systemName: "lock.shield.fill").foregroundStyle(.green) }; Text(selectedModelText).font(.subheadline.weight(.semibold)); Text("在模型库下载并选择 Qwen 或 Gemma 4，分析和对话都会使用它。").font(.caption).foregroundStyle(AppTheme.secondary); NavigationLink { ModelLibraryView() } label: { Label("管理与下载模型", systemImage: "arrow.down.circle") }.font(.subheadline.weight(.semibold)) } } }
    private var selectedModelText: String { if let id = store.selectedGGUFModelID, let model = store.modelLibrary.ggufCatalog.first(where: { $0.id == id }) { return model.name }; return "尚未选择模型" }
    private func setting(icon: String, title: String, detail: String, color: Color, action: @escaping () -> Void) -> some View { Button(action: action) { HStack { Image(systemName: icon).foregroundStyle(color).frame(width: 28); VStack(alignment: .leading) { Text(title).bold(); Text(detail).font(.caption).foregroundStyle(AppTheme.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.gray) }.padding(.vertical, 12) }.buttonStyle(.plain) }
}

struct AddMetricView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var type = "饮水"
    @State private var value = ""
    var body: some View { NavigationStack { Form { Picker("指标", selection: $type) { Text("饮水").tag("饮水"); Text("心情").tag("心情"); Text("体重").tag("体重") }; TextField("例如 500", text: $value).keyboardType(.decimalPad); Text("手动记录会和 Apple 健康数据一起用于 AI 分析。数据只保存在你的设备上。").font(.footnote).foregroundStyle(.secondary) }.navigationTitle("添加记录").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { store.addManualMetric(type: type, value: value); dismiss() }.disabled(value.isEmpty) } } } }
}

struct HistoryView: View { @Environment(\.dismiss) private var dismiss; @Environment(HealthStore.self) private var store; var body: some View { NavigationStack { VStack(alignment: .leading, spacing: 18) { if store.metrics.isEmpty { Text("还没有足够的真实数据").font(.title2.bold()); Text("积累几天 Apple 健康或手动记录后，这里会显示趋势。").foregroundStyle(AppTheme.secondary) } else { Text("最近 7 天").font(.title2.bold()); Text("趋势会根据你已记录的真实数据逐步生成。").foregroundStyle(AppTheme.secondary) }; Spacer() }.padding(20).navigationTitle("趋势回顾").toolbar { Button("完成") { dismiss() } } } } }
struct AllInsightsView: View { @Environment(HealthStore.self) private var store; @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { ScrollView { VStack(spacing: 16) { ForEach(store.insights) { InsightPreview(insight: $0) } }.padding(20) }.navigationTitle("全部建议").toolbar { Button("完成") { dismiss() } } } } }
struct ReminderView: View { @Environment(HealthStore.self) private var store; @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { Form { Toggle("每日健康提醒", isOn: Bindable(store).reminderEnabled); DatePicker("提醒时间", selection: Bindable(store).reminderDate, displayedComponents: .hourAndMinute) }.navigationTitle("每日提醒").toolbar { Button("完成") { dismiss() } } } } }
struct PrivacyView: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List { Label("健康数据仅用于生成建议", systemImage: "lock.fill"); Label("AI 模型在设备上运行", systemImage: "iphone"); Label("你可以随时删除手动记录", systemImage: "trash") }.navigationTitle("隐私与数据").toolbar { Button("完成") { dismiss() } } } } }

struct ModelLibraryView: View {
    @Environment(HealthStore.self) private var store
    var body: some View {
        List {
            Section { Text("下载后的 GGUF 文件保存在本机，健康数据不会上传。首次下载建议使用 Wi-Fi；E2B/E4B 需要较多存储空间和内存。").font(.footnote).foregroundStyle(.secondary) }
            Section("GGUF 本地模型") {
                ForEach(store.modelLibrary.ggufCatalog) { model in GGUFModelRow(model: model) }
            }
        }.navigationTitle("模型库").toolbar { ToolbarItem(placement: .topBarTrailing) { Image(systemName: "lock.shield.fill").foregroundStyle(.green) } }.task { store.modelLibrary.restoreInstalledModels() }
    }
}

struct GGUFModelRow: View {
    @Environment(HealthStore.self) private var store
    let model: GGUFModel
    var state: ModelDownloadState { store.modelLibrary.ggufState(for: model) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: store.selectedGGUFModelID == model.id ? "checkmark.circle.fill" : "cpu").foregroundStyle(store.selectedGGUFModelID == model.id ? .green : .orange); VStack(alignment: .leading) { Text(model.name).font(.subheadline.bold()); Text("\(model.detail) · \(model.sizeText)").font(.caption).foregroundStyle(.secondary) }; Spacer(); action }
            if case .downloading = state {
                let progress = store.modelLibrary.ggufProgress[model.id] ?? 0
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress).tint(.orange)
                    HStack {
                        Text("已完成 \(Int(progress * 100))%")
                        Spacer()
                        Text(speedText(store.modelLibrary.ggufDownloadSpeed[model.id] ?? 0))
                    }.font(.caption2).foregroundStyle(.secondary)
                }
            }
            if case .failed(let message) = state { Text(message).font(.caption2).foregroundStyle(.red) }
            if case .downloaded = state { Text("已下载到本机；分析时会优先使用此模型。").font(.caption2).foregroundStyle(.secondary) }
        }.padding(.vertical, 5)
    }
    private func speedText(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "正在连接…" }
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var index = 0
        while value >= 1024 && index < units.count - 1 { value /= 1024; index += 1 }
        return String(format: "%.1f %@", value, units[index])
    }
    @ViewBuilder private var action: some View {
        switch state {
        case .notDownloaded, .failed: Button("下载") { store.modelLibrary.downloadGGUF(model) }.buttonStyle(.borderedProminent).tint(.orange)
        case .downloading: ProgressView()
        case .downloaded: HStack { Button(store.selectedGGUFModelID == model.id ? "使用中" : "使用") { store.selectedGGUFModelID = model.id }.buttonStyle(.bordered).tint(store.selectedGGUFModelID == model.id ? .green : .orange); Button { store.modelLibrary.deleteGGUF(model); if store.selectedGGUFModelID == model.id { store.selectedGGUFModelID = nil } } label: { Image(systemName: "trash") }.buttonStyle(.bordered).tint(.red) }
        case .builtIn: EmptyView()
        }
    }
}

struct ModelRow: View {
    @Environment(HealthStore.self) private var store
    let model: DownloadableModel
    var state: ModelDownloadState { store.modelLibrary.state(for: model) }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.tier == store.selectedModel ? "checkmark.circle.fill" : "cpu").foregroundStyle(model.tier == store.selectedModel ? AppTheme.accent : AppTheme.secondary).font(.title3)
            VStack(alignment: .leading, spacing: 4) { Text(model.name).font(.subheadline.bold()); Text("\(model.detail) · \(model.sizeText)").font(.caption).foregroundStyle(.secondary); if case .downloading = state { ProgressView(value: store.modelLibrary.activeProgress[model.id] ?? 0).tint(AppTheme.accent) }; if case .failed(let message) = state { Text(message).font(.caption2).foregroundStyle(.red) } }
            Spacer()
            action
        }.padding(.vertical, 5)
    }
    @ViewBuilder private var action: some View {
        switch state {
        case .builtIn: HStack(spacing: 6) { Button(model.tier == store.selectedModel ? "使用中" : "使用") { store.selectedModel = model.tier }.buttonStyle(.bordered).tint(model.tier == store.selectedModel ? .green : AppTheme.accent); Button { store.modelLibrary.delete(model) } label: { Image(systemName: "trash") }.buttonStyle(.bordered).tint(.red) }
        case .notDownloaded, .failed: Button("重新安装") { store.modelLibrary.install(model) }.buttonStyle(.borderedProminent).tint(AppTheme.accent)
        case .downloading: ProgressView()
        case .downloaded: Button("删除") { store.modelLibrary.delete(model) }.buttonStyle(.bordered).tint(.red)
        }
    }
}

enum ThinkingOrbState {
    case working, searching, solving, listening, connecting, weaving, composing, breathing, shaping
}

struct ThinkingOrb: View {
    let state: ThinkingOrbState
    let size: CGFloat
    var speed: Double = 1
    var dark = false
    var paused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused || reduceMotion)) { timeline in
            let time = paused || reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2
                let base = dark ? Color.white : AppTheme.accent
                let glow = dark ? Color.cyan : AppTheme.lavender
                let pulse = 0.86 + 0.10 * sin(time * 2.2)
                let wobble = 0.08 * sin(time * 1.6 + phaseOffset)
                let coreRadius = radius * (0.42 + wobble) * pulse

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * (size > 30 ? 0.20 : 0.12)))
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)), with: .color(glow.opacity(0.55)))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - coreRadius * 0.72, y: center.y - coreRadius * 0.72, width: coreRadius * 1.44, height: coreRadius * 1.44)), with: .color(base))

                let orbitCount = size > 30 ? 3 : 2
                for index in 0..<orbitCount {
                    let angle = time * (0.9 + Double(index) * 0.18) + Double(index) * 2.1 + phaseOffset
                    let orbitRadius = radius * (0.58 + CGFloat(index) * 0.09)
                    let dotRadius = radius * (size > 30 ? 0.085 : 0.11)
                    let point = CGPoint(x: center.x + cos(angle) * orbitRadius, y: center.y + sin(angle * 1.15) * orbitRadius)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(base.opacity(0.85 - Double(index) * 0.16)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("AI 正在工作")
    }

    private var phaseOffset: Double {
        switch state {
        case .working: 0
        case .searching: 0.7
        case .solving: 1.4
        case .listening: 2.1
        case .connecting: 2.8
        case .weaving: 3.5
        case .composing: 4.2
        case .breathing: 4.9
        case .shaping: 5.6
        }
    }
}
