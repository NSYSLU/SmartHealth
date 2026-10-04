import Foundation
import Observation

struct HealthMetric: Identifiable, Hashable {
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

@Observable
final class HealthStore {
    var selectedTab = 0
    var isHealthConnected = true
    var selectedModel: ModelTier = .balanced
    var isAnalyzing = false
    var showAddMetric = false
    var toast: String?

    var metrics: [HealthMetric] = [
        HealthMetric(title: "睡眠", value: "7h 42m", unit: "昨晚", trend: "+18%", icon: "moon.stars.fill", colorHex: "#5B67D8"),
        HealthMetric(title: "步数", value: "8,426", unit: "今日", trend: "+12%", icon: "figure.walk", colorHex: "#32A87D"),
        HealthMetric(title: "心率", value: "68", unit: "BPM 平均", trend: "稳定", icon: "heart.fill", colorHex: "#E66A6A"),
        HealthMetric(title: "活跃能量", value: "486", unit: "千卡", trend: "+8%", icon: "flame.fill", colorHex: "#E88B43")
    ]

    var insights: [Insight] = [
        Insight(category: "今日建议", title: "把恢复放在第一位", detail: "你的睡眠时长比过去 7 天平均值高 18%。今天适合保持轻量活动，让身体完成恢复。", action: "安排一次 20 分钟散步", icon: "sparkles", tintHex: "#5B67D8"),
        Insight(category: "睡眠趋势", title: "入睡时间正在变规律", detail: "连续 4 天在 23:00 前入睡，规律作息让你的静息心率下降了 3 BPM。", action: "继续保持这个节奏", icon: "moon.stars.fill", tintHex: "#32A87D"),
        Insight(category: "温和提醒", title: "下午可以多喝一杯水", detail: "根据今天的活动量，你还可以补充约 450 ml 水分，帮助维持专注。", action: "记录一杯水", icon: "drop.fill", tintHex: "#E88B43")
    ]

    func runAnalysis() {
        isAnalyzing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            self.isAnalyzing = false
            self.toast = "AI 已完成今日分析"
        }
    }

    func connectHealth() {
        isHealthConnected.toggle()
        toast = isHealthConnected ? "已连接 Apple 健康" : "已暂停自动同步"
    }
}
