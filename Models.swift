import Foundation
import Observation

struct HealthMetric: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let trend: String
    let icon: String
    let colorHex: String
}

struct Insight: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let title: String
    let detail: String
    let action: String
    let icon: String
    let tintHex: String
}

struct ChatMessage: Identifiable, Hashable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

struct HealthScoreComponent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let score: Int
    let detail: String
    let icon: String
}

enum ModelTier: String, CaseIterable, Identifiable {
    case balanced = "平衡"
    case fast = "极速"
    case deep = "深度"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .balanced: "适合大多数设备 · 约 1.2 秒"
        case .fast: "优先响应速度 · 约 0.5 秒"
        case .deep: "更细致的长期分析 · 约 3 秒"
        }
    }
}

@MainActor
@Observable
final class HealthStore {
    private let healthKit = HealthKitService()
    private let analyzer = LocalHealthAnalyzer()
    let modelLibrary = ModelLibrary()
    var selectedTab = 0
    var isHealthConnected = false
    var isSyncingHealth = false
    var selectedModel: ModelTier = .balanced { didSet { persistPreferences() } }
    var selectedGGUFModelID: String? { didSet { persistPreferences() } }
    var healthRange: HealthDataRange = .today
    let deviceProfile = DeviceModelProfile.current
    var isAnalyzing = false
    var showAddMetric = false
    var showHistory = false
    var showAllInsights = false
    var showReminderSettings = false
    var showPrivacyDetails = false
    var showHealthScoreDetails = false
    var reminderEnabled = true
    var reminderDate = Calendar.current.date(from: DateComponents(hour: 20, minute: 30)) ?? .now
    var toast: String?
    var chatMessages: [ChatMessage] = []
    var chatInput = ""
    var isChatting = false

    var metrics: [HealthMetric] = []
    private var todayScoreMetrics: [HealthMetric] = []

    var insights: [Insight] = []
    var scoreUpdatedAt = Date()

    var healthScoreComponents: [HealthScoreComponent] {
        var result: [HealthScoreComponent] = []
        let scoreSource = todayScoreMetrics.isEmpty ? metrics : todayScoreMetrics
        if let steps = numericMetric("步数", from: scoreSource) { result.append(HealthScoreComponent(title: "活动", score: min(100, Int(steps / 8000 * 100)), detail: "步数 \(Int(steps))", icon: "figure.walk")) }
        if let exercise = numericMetric("锻炼时间", from: scoreSource) { result.append(HealthScoreComponent(title: "锻炼", score: min(100, Int(exercise / 30 * 100)), detail: "锻炼 \(Int(exercise)) 分钟", icon: "figure.run")) }
        if let heart = numericMetric("心率", from: scoreSource) { let score = heart >= 50 && heart <= 100 ? 90 : 60; result.append(HealthScoreComponent(title: "心率", score: score, detail: "平均 \(Int(heart)) 次/分钟", icon: "heart.fill")) }
        if let oxygen = numericMetric("血氧", from: scoreSource) { result.append(HealthScoreComponent(title: "血氧", score: min(100, Int(oxygen * 100)), detail: String(format: "血氧 %.1f%%", oxygen * 100), icon: "drop.fill")) }
        if let sleep = numericMetric("睡眠", from: scoreSource) { result.append(HealthScoreComponent(title: "睡眠", score: min(100, Int(sleep / 8 * 100)), detail: String(format: "睡眠 %.1f 小时", sleep), icon: "bed.double.fill")) }
        return result
    }
    var healthScore: Int? { let components = healthScoreComponents; guard !components.isEmpty else { return nil }; return components.reduce(0) { $0 + $1.score } / components.count }

    func refreshHealthScore() { scoreUpdatedAt = .now }
    func newChat() { chatMessages.removeAll(); chatInput = "" }
    private func numericMetric(_ title: String, from source: [HealthMetric]? = nil) -> Double? { guard let metric = (source ?? metrics).first(where: { $0.title == title }) else { return nil }; let allowed = metric.value.filter { $0.isNumber || $0 == "." }; return Double(allowed) }

    private var isRestoring = true
    private let preferencesKey = "smarthealth.preferences.v1"
    private let tierKey = "smarthealth.model-tier.v1"
    private let metricsKey = "smarthealth.metrics.v1"

    init() {
        modelLibrary.restoreInstalledModels()
        if let rawModel = UserDefaults.standard.string(forKey: preferencesKey), !rawModel.isEmpty { selectedGGUFModelID = rawModel }
        if let rawTier = UserDefaults.standard.string(forKey: tierKey), let tier = ModelTier(rawValue: rawTier) { selectedModel = tier }
        if let data = UserDefaults.standard.data(forKey: metricsKey), let saved = try? JSONDecoder().decode([HealthMetric].self, from: data) { metrics = saved }
        if selectedGGUFModelID == nil, let installed = modelLibrary.ggufCatalog.first(where: { modelLibrary.ggufURL(for: $0) != nil }) { selectedGGUFModelID = installed.id }
        isRestoring = false
    }

    private func persistPreferences() {
        guard !isRestoring else { return }
        UserDefaults.standard.set(selectedGGUFModelID ?? "", forKey: preferencesKey)
        UserDefaults.standard.set(selectedModel.rawValue, forKey: tierKey)
    }

    private func persistMetrics() {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        UserDefaults.standard.set(data, forKey: metricsKey)
    }

    func askAI(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatting else { return }
        chatInput = ""
        chatMessages.append(ChatMessage(role: .user, text: trimmed))
        isChatting = true
        let summary = metrics.isEmpty ? "暂无健康数据" : metrics.map { "\($0.title): \($0.value) \($0.unit)" }.joined(separator: "；")
        let modelID = selectedGGUFModelID
        Task {
            do {
                let generated = try await modelLibrary.chat(modelID: modelID, question: trimmed, summary: summary)
                chatMessages.append(ChatMessage(role: .assistant, text: generated))
            } catch {
                chatMessages.append(ChatMessage(role: .assistant, text: "当前模型无法完成回答：\(error.localizedDescription)"))
            }
            isChatting = false
        }
    }

    func runAnalysis() {
        guard !metrics.isEmpty else { toast = "请先同步 Apple 健康或添加一条记录"; return }
        isAnalyzing = true
        let currentMetrics = metrics
        Task {
            let insight: Insight
            do {
                let summary = currentMetrics.map { "\($0.title): \($0.value) \($0.unit)" }.joined(separator: "；")
                guard let generated = try await modelLibrary.predictGGUF(modelID: selectedGGUFModelID, summary: summary), !generated.isEmpty else { throw GGUFInferenceError.modelLoadFailed }
                insight = Insight(category: "GGUF 本地模型分析", title: "根据你的健康数据", detail: generated, action: "继续保持这个节奏", icon: "sparkles", tintHex: "#5B67D8")
            } catch {
                insight = Insight(category: "GGUF 本地模型", title: "暂时无法生成洞察", detail: modelLibrary.hasInstalledGGUF ? "GGUF 模型加载或推理失败，请确认模型文件完整且设备有足够内存。" : "请先下载一个 GGUF 模型，健康洞察只使用本地 GGUF 模型。", action: "前往模型库下载", icon: "arrow.down.circle", tintHex: "#5B67D8")
                toast = modelLibrary.hasInstalledGGUF ? "GGUF 推理失败" : "请先下载 GGUF 模型"
            }
            if insights.isEmpty { insights = [insight] } else { insights[0] = insight }
            isAnalyzing = false
            if toast == nil || !toast!.hasPrefix("模型推理失败") {
                if !insight.title.contains("暂时无法") { toast = "AI 已完成今日 GGUF 分析" }
            }
        }
    }

    func connectHealth() {
        if isHealthConnected {
            isHealthConnected = false
            toast = "已暂停自动同步"
            return
        }
        syncHealthData()
    }

    func syncHealthData() {
        isSyncingHealth = true
        Task {
            do {
                try await healthKit.requestAccess()
                let values = try await healthKit.todayMetrics(range: healthRange)
                let syncedTitles = Set(values.map(\.title)); metrics.removeAll { $0.unit.contains("·") && !syncedTitles.contains($0.title) }
                for value in values { updateMetric(title: value.title, value: value.value, unit: "\(value.unit)", trend: "同步", icon: value.icon, color: value.color) }
                if healthRange == .today { todayScoreMetrics = metrics.filter { syncedTitles.contains($0.title) } }
                isHealthConnected = true
                toast = metrics.isEmpty ? "已授权，但当前范围没有可读取的数量型健康样本" : "Apple 健康已同步 \(values.count) 项数据 · \(healthRange.rawValue)"
            } catch {
                toast = error.localizedDescription
            }
            isSyncingHealth = false
        }
    }

    private func updateMetric(title: String, value: String, unit: String, trend: String, icon: String, color: String) {
        let metric = HealthMetric(title: title, value: value, unit: unit, trend: trend, icon: icon, colorHex: color)
        if let index = metrics.firstIndex(where: { $0.title == title }) { metrics[index] = metric } else { metrics.append(metric) }
        persistMetrics()
    }

    func addManualMetric(type: String, value: String) {
        let title: String
        let unit: String
        let icon: String
        let color: String
        switch type {
        case "饮水": title = "饮水"; unit = "ml · 手动"; icon = "drop.fill"; color = "#4B9ED8"
        case "体重": title = "体重"; unit = "kg · 手动"; icon = "scalemass.fill"; color = "#8D6CCF"
        default: title = "心情"; unit = "分 · 手动"; icon = "face.smiling.fill"; color = "#E88B43"
        }
        metrics.insert(HealthMetric(title: title, value: value, unit: unit, trend: "刚刚", icon: icon, colorHex: color), at: 0)
        persistMetrics()
        toast = "已添加\(title)记录"
    }

    func performAction(for insight: Insight) {
        if insight.action == "记录一杯水" {
            addManualMetric(type: "饮水", value: "250")
        } else {
            toast = insight.action
        }
    }
}
