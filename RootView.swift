import SwiftUI

struct RootView: View {
    @Environment(HealthStore.self) private var store
    var body: some View {
        TabView(selection: Bindable(store).selectedTab) {
            DashboardView().tabItem { Label("首页", systemImage: "house.fill") }.tag(0)
            InsightsView().tabItem { Label("洞察", systemImage: "sparkles") }.tag(1)
            ChatView().tabItem { Label("AI 对话", systemImage: "bubble.left.and.bubble.right.fill") }.tag(2)
            DataView().tabItem { Label("数据", systemImage: "chart.bar.fill") }.tag(3)
            SettingsView().tabItem { Label("我的", systemImage: "person.fill") }.tag(4)
        }
        .tint(AppTheme.accent)
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Text(toast).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10).background(AppTheme.ink).clipShape(Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)).onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { store.toast = nil }
                }
            }
        }
        .sheet(isPresented: Bindable(store).showAddMetric) { AddMetricView() }
    }
}

struct DashboardView: View {
    @Environment(HealthStore.self) private var store
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if store.metrics.isEmpty { EmptyHealthState() } else { hero }
                    if !store.metrics.isEmpty { HStack { SectionTitle(title: "\(store.healthRange.rawValue)状态"); Spacer(); Picker("数据范围", selection: Bindable(store).healthRange) { ForEach(HealthDataRange.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).onChange(of: store.healthRange) { _, _ in store.syncHealthData() } } }
                    if !store.metrics.isEmpty { LazyVGrid(columns: columns, spacing: 12) { ForEach(store.metrics) { MetricCard(metric: $0) } } }
                    if let firstInsight = store.insights.first { HStack { SectionTitle(title: "给你的建议"); Spacer(); Button("查看全部") { store.showAllInsights = true }.font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.accent) }; InsightPreview(insight: firstInsight) }
                    healthConnection
                }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar)
                .task { while !Task.isCancelled { store.refreshHealthScore(); try? await Task.sleep(for: .seconds(3600)) } }
                .sheet(isPresented: Bindable(store).showHistory) { HistoryView() }
                .sheet(isPresented: Bindable(store).showAllInsights) { AllInsightsView() }
                .sheet(isPresented: Bindable(store).showHealthScoreDetails) { HealthScoreDetailsView() }
        }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text("周三，10 月 4 日").font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.secondary); Text("早上好，Lucas").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink) }
            Spacer()
            Button { store.selectedTab = 4 } label: { ZStack { Circle().fill(AppTheme.lavender).frame(width: 44, height: 44); Image(systemName: "person.fill").foregroundStyle(AppTheme.accent); Circle().fill(.green).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2)).offset(x: 15, y: -15) } }.buttonStyle(.plain)
        }
    }
    private var hero: some View {
        Button { store.showHealthScoreDetails = true } label: { SoftCard { HStack(spacing: 16) { ZStack { Circle().stroke(.white.opacity(0.35), lineWidth: 7); Circle().trim(from: 0, to: CGFloat(store.healthScore ?? 0) / 100).stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90)); Text(store.healthScore.map(String.init) ?? "—").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(.white) }.frame(width: 82, height: 82); VStack(alignment: .leading, spacing: 6) { Text("今日健康分").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8)); Text(store.healthScore == nil ? "等待真实数据" : "基于当前健康数据计算").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white); Text("点击查看组成与 AI 建议").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.8)) }.padding(20).background(LinearGradient(colors: [AppTheme.accent, Color(hex: "#7D88E8")], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)) } }.buttonStyle(.plain)
    }
    private var healthConnection: some View {
        SoftCard { HStack(spacing: 13) { Image(systemName: "heart.text.square.fill").font(.system(size: 23)).foregroundStyle(.red); VStack(alignment: .leading, spacing: 3) { Text("Apple 健康").font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.ink); Text(store.isSyncingHealth ? "正在同步…" : (store.isHealthConnected ? "已自动同步 · 刚刚更新" : "点击授权并同步")).font(.system(size: 12)).foregroundStyle(AppTheme.secondary) }; Spacer(); Button { store.connectHealth() } label: { Image(systemName: store.isSyncingHealth ? "arrow.triangle.2.circlepath" : (store.isHealthConnected ? "checkmark" : "arrow.down.circle")).foregroundStyle(store.isHealthConnected ? .green : AppTheme.accent).frame(width: 34, height: 34).background(AppTheme.canvas).clipShape(Circle()) }.disabled(store.isSyncingHealth) } }
    }
}

struct HealthScoreDetailsView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List { Section("组成") { if store.healthScoreComponents.isEmpty { Text("同步 Apple 健康或添加真实记录后计算健康分。") } else { ForEach(store.healthScoreComponents) { item in HStack { Image(systemName: item.icon).foregroundStyle(AppTheme.accent).frame(width: 28); VStack(alignment: .leading) { Text(item.title).bold(); Text(item.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(item.score)").font(.title3.bold()).foregroundStyle(item.score >= 80 ? .green : .orange) } } } }; Section("AI 建议") { if store.insights.isEmpty { Text("点击首页的 AI 洞察开始分析。") } else { Text(store.insights[0].detail) } } }.navigationTitle("健康分详情").toolbar { Button("重新计算") { store.refreshHealthScore() }; Button("完成") { dismiss() } } } }
}

struct EmptyHealthState: View {
    @Environment(HealthStore.self) private var store
    var body: some View { SoftCard { VStack(alignment: .leading, spacing: 12) { Image(systemName: "heart.text.square").font(.system(size: 32)).foregroundStyle(AppTheme.accent); Text("尚无健康数据").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); Text("连接 Apple 健康或手动添加一条记录后，这里会显示你的真实状态。我们不会用演示数据填充健康指标。").font(.system(size: 14)).foregroundStyle(AppTheme.secondary).lineSpacing(3); HStack { Button("连接 Apple 健康") { store.connectHealth() }.buttonStyle(.borderedProminent).tint(AppTheme.accent); Button("手动添加") { store.showAddMetric = true }.buttonStyle(.bordered) } } } }
}

struct MetricCard: View {
    let metric: HealthMetric
    var body: some View { SoftCard { VStack(alignment: .leading, spacing: 14) { HStack { Image(systemName: metric.icon).foregroundStyle(Color(hex: metric.colorHex)); Spacer(); Text(metric.trend).font(.system(size: 11, weight: .bold)).foregroundStyle(.green).padding(.horizontal, 7).padding(.vertical, 4).background(.green.opacity(0.1)).clipShape(Capsule()) }; Text(metric.title).font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.secondary); Text(metric.value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); Text(metric.unit).font(.system(size: 11)).foregroundStyle(AppTheme.secondary) } } }
}

struct InsightPreview: View {
    @Environment(HealthStore.self) private var store
    let insight: Insight
    var body: some View { SoftCard { HStack(alignment: .top, spacing: 14) { Image(systemName: insight.icon).font(.system(size: 19)).foregroundStyle(Color(hex: insight.tintHex)).frame(width: 38, height: 38).background(Color(hex: insight.tintHex).opacity(0.12)).clipShape(Circle()); VStack(alignment: .leading, spacing: 7) { Text(insight.category.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(AppTheme.secondary); Text(insight.title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); Text(insight.detail).font(.system(size: 13)).foregroundStyle(AppTheme.secondary).lineSpacing(3); Button(insight.action) { store.performAction(for: insight) }.font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.accent).padding(.top, 2) }; Spacer() } } }
}
