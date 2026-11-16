import SwiftUI

enum SlawPalette {
    static let background = Color(hex: 0xF5F7F8)
    static let surface = Color(hex: 0xFFFFFF)
    static let elevated = Color(hex: 0xEEF2F4)
    static let outline = Color(hex: 0xDDE5E1)
    static let mint = Color(hex: 0x167A53)
    static let mintDeep = Color(hex: 0x0D6645)
    static let text = Color(hex: 0x18231F)
    static let muted = Color(hex: 0x596A62)
    static let warning = Color(hex: 0x9A5B00)
    static let danger = Color(hex: 0xB23C35)
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct SlawMark: View {
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [SlawPalette.mint, SlawPalette.mintDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("S")
                .font(.system(size: size * 0.58, weight: .black, design: .rounded))
                .foregroundStyle(SlawPalette.background)
                .offset(x: -size * 0.015, y: -size * 0.025)
            Circle()
                .fill(SlawPalette.background)
                .frame(width: size * 0.11, height: size * 0.11)
                .offset(x: size * 0.27, y: -size * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ConversationArtwork: View {
    let conversation: ConversationSummary

    private static let colors: [Color] = [
        Color(hex: 0x6A56C7), Color(hex: 0xD45D46), Color(hex: 0x2388B2),
        Color(hex: 0xBD4F8F), Color(hex: 0xB87713), Color(hex: 0x178465),
        Color(hex: 0x4A67C4)
    ]

    private var color: Color {
        let seed = conversation.id.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7FFFFFFF }
        return Self.colors[seed % Self.colors.count]
    }

    private var symbol: String {
        let value = (conversation.displayTitle + " " + (conversation.repositoryLabel ?? "")).lowercased()
        if value.contains("design") || value.contains("ui") || value.contains("brand") { return "paintpalette.fill" }
        if value.contains("web") || value.contains("site") || value.contains("website") { return "globe" }
        if value.contains("data") || value.contains("chart") || value.contains("analytics") { return "chart.bar.fill" }
        if value.contains("bug") || value.contains("fix") || value.contains("debug") { return "ladybug.fill" }
        if value.contains("game") { return "gamecontroller.fill" }
        if value.contains("doc") || value.contains("readme") || value.contains("writing") { return "doc.text.fill" }
        if value.contains("photo") || value.contains("image") || value.contains("art") { return "photo.fill" }
        if value.contains("server") || value.contains("api") || value.contains("deploy") { return "server.rack" }
        return "terminal.fill"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.13))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.20), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 50, height: 50)
        .accessibilityHidden(true)
    }
}

struct StatusBadge: View {
    let title: String
    var tint: Color = SlawPalette.mint

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
    }
}
