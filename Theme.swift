import SwiftUI

extension Color {
    init(hex: String) {
        let value = hex.replacingOccurrences(of: "#", with: "")
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(red: Double((number >> 16) & 0xFF) / 255, green: Double((number >> 8) & 0xFF) / 255, blue: Double(number & 0xFF) / 255)
    }
}

enum AppTheme {
    static let ink = Color(hex: "#17202B")
    static let secondary = Color(hex: "#697382")
    static let canvas = Color(hex: "#F5F7FA")
    static let card = Color.white
    static let accent = Color(hex: "#5B67D8")
    static let mint = Color(hex: "#DDF3EA")
    static let lavender = Color(hex: "#E9E8FB")
}

struct SectionTitle: View {
    let title: String
    var action: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.ink)
            Spacer()
            if let action { Text(action).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.accent) }
        }
    }
}

struct SoftCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).background(AppTheme.card).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}
