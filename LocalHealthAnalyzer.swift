import Foundation

struct LocalHealthAnalyzer {
    func analyze(metrics: [HealthMetric], tier: ModelTier, package: BuiltInModelPackage? = nil) async -> Insight {
        let sleep = metrics.first(where: { $0.title == "睡眠" })?.value ?? "7h"
        let steps = metrics.first(where: { $0.title == "步数" })?.value ?? "0"
        let detail: String
        let action: String
        switch tier {
        case .fast:
            detail = "已快速扫描睡眠、活动和心率。你昨晚睡眠约 \(sleep)，今天步数为 \(steps)，整体状态平稳。"
            action = "保持轻量活动"
        case .balanced:
            detail = "结合近期睡眠、活动和心率趋势，你昨晚睡眠约 \(sleep)，今天已完成 \(steps) 步。当前适合保持规律节奏。"
            action = "安排一次 20 分钟散步"
        case .deep:
            detail = "深度分析发现：睡眠与活动之间保持良好平衡。昨晚约 \(sleep)，今日步数 \(steps)，建议把运动安排在晚餐前，帮助维持今晚的入睡节奏。"
            action = "继续保持这个节奏"
        }
        let title = package?.title ?? "你的恢复节奏不错"
        let suffix = package.map { "\($0.prompt)\n\n" } ?? ""
        return Insight(category: "刚刚更新 · \(package?.latency ?? "内置分析")", title: title, detail: suffix + detail, action: action, icon: "sparkles", tintHex: "#5B67D8")
    }
}
