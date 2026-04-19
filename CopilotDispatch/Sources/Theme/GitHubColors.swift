import SwiftUI

enum GitHubColors {
    // Backgrounds — GitHub dark theme
    static let background = Color(hex: 0x0d1117)
    static let surface = Color(hex: 0x161b22)
    static let surfaceHover = Color(hex: 0x1c2129)
    static let border = Color(hex: 0x30363d)
    static let borderMuted = Color(hex: 0x21262d)

    // Text
    static let text = Color(hex: 0xc9d1d9)
    static let textMuted = Color(hex: 0x8b949e)
    static let textSubtle = Color(hex: 0x6e7681)

    // Brand Primary — GitHub Green (brand.github.com/foundations/color)
    static let green = Color(hex: 0x0FBF3E)            // GitHub Green — primary brand color
    static let greenEmphasis = Color(hex: 0x08872B)     // Green 5 — dark accent, button bg

    // Copilot Theme (brand.github.com/brand-identity/copilot)
    static let purple = Color(hex: 0x8534F3)            // Copilot Purple — primary
    static let purpleLight = Color(hex: 0xC898FD)       // Purple 1 — muted/background accents
    static let purpleMuted = Color(hex: 0xB870FF)       // Purple 2 — highlights

    // Brand Accent colors
    static let blue = Color(hex: 0x3094FF)              // Security Blue
    static let orange = Color(hex: 0xF08A3A)            // Brand Orange 2

    // Functional colors (not brand-prescribed, used for status UI)
    static let red = Color(hex: 0xf85149)               // Error, danger
    static let yellow = Color(hex: 0xd29922)            // Warning, pending

    // Semantic — Buttons
    static let btnPrimary = Color(hex: 0x08872B)        // Green 5 — AA contrast with white text
    static let btnPrimaryText = Color.white
    static let btnSecondary = Color(hex: 0x21262d)
    static let btnSecondaryText = Color(hex: 0xc9d1d9)
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

enum GitHubIcon {
    static func logo(size: CGFloat = 22) -> some View {
        GitHubLogoView(size: size)
    }
}

struct GitHubLogoView: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                loadImage(name: "gh_icon_white", ext: "jpeg")
            } else {
                loadImage(name: "gh_icon", ext: "png")
            }
        }
        .frame(width: size, height: size)
    }

    private func loadImage(name: String, ext: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: size * 0.7))
            }
        }
    }
}
