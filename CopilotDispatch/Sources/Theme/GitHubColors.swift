import SwiftUI

enum GitHubColors {
    static let background = Color(hex: 0x0d1117)
    static let surface = Color(hex: 0x161b22)
    static let surfaceHover = Color(hex: 0x1c2129)
    static let border = Color(hex: 0x30363d)
    static let borderMuted = Color(hex: 0x21262d)

    static let text = Color(hex: 0xe6edf3)
    static let textMuted = Color(hex: 0x8b949e)
    static let textSubtle = Color(hex: 0x6e7681)

    static let green = Color(hex: 0x3fb950)
    static let red = Color(hex: 0xf85149)
    static let blue = Color(hex: 0x58a6ff)
    static let purple = Color(hex: 0xbc8cff)
    static let yellow = Color(hex: 0xd29922)
    static let orange = Color(hex: 0xd18616)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
