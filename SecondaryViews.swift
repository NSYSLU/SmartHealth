import SwiftUI

struct InsightsView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { Text("AI 洞察").font(.largeTitle.bold()); Text("基于你的真实数据，每天给出一条刚刚好的建议").foregroundStyle(AppTheme.secondary); Button { store.runAnalysis() } label: { Label(store.isAnalyzing ? "正在分析你的数据…" : "重新分析今日状态", systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .leading).padding(16).background(AppTheme.lavender).clipShape(RoundedRectangle(cornerRadius: 15)) }.buttonStyle(.plain); ForEach(store.insights) { InsightPreview(insight: $0) } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar) } }
}

struct DataView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { HStack { Text("健康数据").font(.largeTitle.bold()); Spacer(); Button { store.showAddMetric = true } label: { Image(systemName: "plus").foregroundStyle(.white).frame(width: 38, height: 38).background(AppTheme.accent).clipShape(Circle()) } }; Text("数据越完整，AI 的建议越贴合你").foregroundStyle(AppTheme.secondary); chart; SectionTitle(title: "全部指标", action: "管理"); ForEach(store.metrics) { metric in SoftCard { HStack { Image(systemName: metric.icon).foregroundStyle(Color(hex: metric.colorHex)); Text(metric.title); Spacer(); Text(metric.value).bold(); Text(metric.unit).font(.caption).foregroundStyle(AppTheme.secondary) } } } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar) } }
    private var chart: some View { SoftCard { VStack(alignment: .leading, spacing: 14) { HStack { Text("健康分趋势").bold(); Spacer(); Text("近 7 天").foregroundStyle(AppTheme.accent) }; HStack(alignment: .bottom, spacing: 10) { ForEach(Array([42,55,48,70,63,78,82].enumerated()), id: \.offset) { item in RoundedRectangle(cornerRadius: 5).fill(item.element == 82 ? AppTheme.accent : AppTheme.lavender).frame(maxWidth: .infinity).frame(height: CGFloat(item.element)) } }.frame(height: 90, alignment: .bottom) } } }
}

struct SettingsView: View {
    @Environment(HealthStore.self) private var store
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { Text("我的设置").font(.largeTitle.bold()); modelCard; SoftCard { VStack(spacing: 0) { setting(icon: "heart.text.square.fill", title: "Apple 健康", detail: store.isHealthConnected ? "已连接" : "未连接", color: .red) { store.connectHealth() }; Divider(); setting(icon: "bell.badge.fill", title: "每日提醒", detail: "每天 20:30", color: .orange) {}; Divider(); setting(icon: "lock.fill", title: "隐私与数据", detail: "本地优先", color: AppTheme.accent) {} } } }.padding(20) }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar) } }
    private var modelCard: some View { SoftCard { VStack(alignment: .leading, spacing: 15) { HStack { VStack(alignment: .leading) { Text("本地 AI 模型").bold(); Text("数据只在你的 iPhone 上处理").font(.caption).foregroundStyle(AppTheme.secondary) }; Spacer(); Image(systemName: "lock.shield.fill").foregroundStyle(.green) }; Picker("", selection: Bindable(store).selectedModel) { ForEach(ModelTier.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented); Text(store.selectedModel.subtitle).font(.caption).foregroundStyle(AppTheme.secondary) } } }
    private func setting(icon: String, title: String, detail: String, color: Color, action: @escaping () -> Void) -> some View { Button(action: action) { HStack { Image(systemName: icon).foregroundStyle(color).frame(width: 28); VStack(alignment: .leading) { Text(title).bold(); Text(detail).font(.caption).foregroundStyle(AppTheme.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.gray) }.padding(.vertical, 12) }.buttonStyle(.plain) }
}

struct AddMetricView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var type = "饮水"
    @State private var value = ""
    var body: some View { NavigationStack { Form { Picker("指标", selection: $type) { Text("饮水").tag("饮水"); Text("心情").tag("心情"); Text("体重").tag("体重") }; TextField("例如 500", text: $value).keyboardType(.decimalPad); Text("手动记录会和 Apple 健康数据一起用于 AI 分析。数据只保存在你的设备上。").font(.footnote).foregroundStyle(.secondary) }.navigationTitle("添加记录").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { store.toast = "已添加 \(type) 记录"; dismiss() }.disabled(value.isEmpty) } } } }
}
