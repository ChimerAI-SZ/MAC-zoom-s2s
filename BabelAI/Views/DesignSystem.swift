import SwiftUI

// MARK: - Design System Constants
struct Design {
    
    // MARK: Colors - Cold, minimal palette
    struct Colors {
        // Primary cold gray-blue tones
        static let primary = Color(red: 0.29, green: 0.33, blue: 0.41) // #4A5568 Cold gray-blue
        static let accent = Color(red: 0.18, green: 0.22, blue: 0.28) // #2D3748 Deep gray-blue
        static let secondary = Color(red: 0.44, green: 0.50, blue: 0.59) // #718096 Cool gray
        
        // Backgrounds
        static let background = Color(NSColor.windowBackgroundColor)
        static let cardBackground = Color(white: 0.97, opacity: 0.8)
        static let cardBackgroundDark = Color(white: 0.12, opacity: 0.8)
        
        // Text
        static let textPrimary = Color(NSColor.labelColor)
        static let textSecondary = Color(NSColor.secondaryLabelColor).opacity(0.7)
        
        // Subtle status colors
        static let success = Color(red: 0.41, green: 0.83, blue: 0.57).opacity(0.9) // #68D391 Soft green
        static let warning = Color(red: 0.96, green: 0.88, blue: 0.37).opacity(0.9) // #F6E05E Soft yellow
        static let error = Color(red: 0.99, green: 0.51, blue: 0.51).opacity(0.9) // #FC8181 Soft red
        
        // Status indicators
        static let statusIdle = Color(white: 0.6)
        static let statusConnecting = Color(red: 0.44, green: 0.50, blue: 0.59)
        static let statusConnected = Color(red: 0.41, green: 0.83, blue: 0.57).opacity(0.7)
        static let statusError = Color(red: 0.99, green: 0.51, blue: 0.51).opacity(0.7)
    }
    
    // MARK: Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: Corner Radius
    struct Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let full: CGFloat = 100
    }
    
    // MARK: Animation
    struct Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
    
    // MARK: Typography
    struct Typography {
        static let largeTitle = Font.system(size: 26, weight: .semibold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .medium)
        static let body = Font.system(size: 14)
        static let caption = Font.system(size: 12)
        static let footnote = Font.system(size: 11, weight: .regular)
    }
}

// MARK: - Custom Components

// Minimal flat button
struct ModernButton: ButtonStyle {
    var isPrimary = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Typography.headline)
            .foregroundColor(isPrimary ? .white : Design.Colors.primary)
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.vertical, Design.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.sm)
                    .fill(isPrimary ? Design.Colors.accent : Color.clear)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.sm)
                    .stroke(isPrimary ? Color.clear : Design.Colors.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Design.Animation.smooth, value: configuration.isPressed)
    }
}

// Minimal card component
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Design.Spacing.lg
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(Design.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.sm)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
            )
    }
}

// Minimal status indicator
struct StatusIndicator: View {
    let isActive: Bool
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(isActive ? 1.0 : 0.6)
            .animation(
                isActive ? Design.Animation.smooth.repeatForever(autoreverses: true) : .default,
                value: isActive
            )
    }
}

// Minimal metric card
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String?
    
    init(title: String, value: String, color: Color = Design.Colors.secondary, icon: String? = nil) {
        self.title = title
        self.value = value
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            HStack(spacing: Design.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(color.opacity(0.6))
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(Design.Typography.caption)
                    .foregroundColor(Design.Colors.textSecondary)
            }
            
            Text(value)
                .font(Design.Typography.title)
                .foregroundColor(Design.Colors.textPrimary)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Spacing.md)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(Design.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.sm)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// Minimal toggle style
struct ModernToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundColor(Design.Colors.textPrimary)
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .fill(configuration.isOn ? Design.Colors.accent : Color.gray.opacity(0.2))
                .frame(width: 42, height: 24)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .offset(x: configuration.isOn ? 9 : -9)
                        .animation(Design.Animation.smooth, value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// Custom slider style
struct ModernSliderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accentColor(Design.Colors.primary)
    }
}

// Minimal settings group
struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(Design.Colors.secondary)
                    .font(.system(size: 14))
                Text(title)
                    .font(Design.Typography.headline)
                    .foregroundColor(Design.Colors.textPrimary)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Spacing.lg)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        .cornerRadius(Design.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.sm)
                .stroke(Color.gray.opacity(0.05), lineWidth: 0.5)
        )
    }
}

// MARK: - View Extensions
extension View {
    func glassBackground() -> some View {
        self.background(.ultraThinMaterial)
            .cornerRadius(Design.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    func cardStyle() -> some View {
        self.padding(Design.Spacing.lg)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(Design.Radius.md)
            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}