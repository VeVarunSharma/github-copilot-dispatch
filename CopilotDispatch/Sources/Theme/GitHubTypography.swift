import SwiftUI

enum GitHubTypography {
    static let title = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
    static let terminal = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let terminalBold = Font.system(size: 13, weight: .bold, design: .monospaced)
    static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
}

enum GitHubSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}
