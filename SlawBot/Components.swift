import SwiftUI

enum SlawPalette {
    static let background = Color(hex: 0x090D0C)
    static let surface = Color(hex: 0x141A18)
    static let elevated = Color(hex: 0x1B2320)
    static let outline = Color(hex: 0x2A3530)
    static let mint = Color(hex: 0x8FE0B7)
    static let mintDeep = Color(hex: 0x4FB889)
    static let text = Color(hex: 0xF2F7F4)
    static let muted = Color(hex: 0x9CAAA3)
    static let warning = Color(hex: 0xF1B96A)
    static let danger = Color(hex: 0xFF7F78)
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
