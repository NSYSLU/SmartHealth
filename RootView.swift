import SwiftUI

struct RootView: View {
    @Environment(HealthStore.self) private var store
    var body: some View {
        TabView(selection: Bindable(store).selectedTab) {
            DashboardView().tabItem { Label("首页", systemImage: "house.fill") }.tag(0)
            InsightsView().tabItem { Label("洞察", systemImage: "sparkles") }.tag(1)
            DataView().tabItem { Label("数据", systemImage: "chart.bar.fill") }.tag(2)
            SettingsView().tabItem { Label("我的", systemImage: "person.fill") }.tag(3)
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
                    hero
                    SectionTitle(title: "今日状态", action: "过去 7 天")
                    LazyVGrid(columns: columns, spacing: 12) { ForEach(store.metrics) { MetricCard(metric: $0) } }
                    SectionTitle(title: "给你的建议", action: "查看全部")
                    InsightPreview(insight: store.insights[0])
                    healthConnection
                }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            }.background(AppTheme.canvas).toolbar(.hidden, for: .navigationBar)
        }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text("周三，10 月 4 日").font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.secondary); Text("早上好，Lucas").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink) }
            Spacer()
            ZStack { Circle().fill(AppTheme.lavender).frame(width: 44, height: 44); Image(systemName: "person.fill").foregroundStyle(AppTheme.accent); Circle().fill(.green).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2)).offset(x: 15, y: -15) }
        }
    }
    private var hero: some View {
        SoftCard { HStack(spacing: 16) { ZStack { Circle().stroke(.white.opacity(0.35), lineWidth: 7); Circle().trim(from: 0, to: 0.82).stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90)); Text("82").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(.white) }.frame(width: 82, height: 82); VStack(alignment: .leading, spacing: 6) { Text("今日健康分").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8)); Text("状态不错，继续保持").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white); Text("比昨天提升 6 分").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.65)) }.padding(20).background(LinearGradient(colors: [AppTheme.accent, Color(hex: "#7D88E8")], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)) }
    }
    private var healthConnection: some View {
        SoftCard { HStack(spacing: 13) { Image(systemName: "heart.text.square.fill").font(.system(size: 23)).foregroundStyle(.red); VStack(alignment: .leading, spacing: 3) { Text("Apple 健康").font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.ink); Text(store.isHealthConnected ? "已自动同步 · 刚刚更新" : "同步已暂停").font(.system(size: 12)).foregroundStyle(AppTheme.secondary) }; Spacer(); Toggle("", isOn: Bindable(store).isHealthConnected).labelsHidden().tint(AppTheme.accent) } }
    }
}

struct MetricCard: View {
    let metric: HealthMetric
    var body: some View { SoftCard { VStack(alignment: .leading, spacing: 14) { HStack { Image(systemName: metric.icon).foregroundStyle(Color(hex: metric.colorHex)); Spacer(); Text(metric.trend).font(.system(size: 11, weight: .bold)).foregroundStyle(.green).padding(.horizontal, 7).padding(.vertical, 4).background(.green.opacity(0.1)).clipShape(Capsule()) }; Text(metric.title).font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.secondary); Text(metric.value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); Text(metric.unit).font(.system(size: 11)).foregroundStyle(AppTheme.secondary) } } }
}

struct InsightPreview: View {
    let insight: Insight
    var body: some View { SoftCard { HStack(alignment: .top, spacing: 14) { Image(systemName: insight.icon).font(.system(size: 19)).foregroundStyle(Color(hex: insight.tintHex)).frame(width: 38, height: 38).background(Color(hex: insight.tintHex).opacity(0.12)).clipShape(Circle()); VStack(alignment: .leading, spacing: 7) { Text(insight.category.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(AppTheme.secondary); Text(insight.title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink); Text(insight.detail).font(.system(size: 13)).foregroundStyle(AppTheme.secondary).lineSpacing(3); Text(insight.action).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.accent).padding(.top, 2) }; Spacer() } } }
}
