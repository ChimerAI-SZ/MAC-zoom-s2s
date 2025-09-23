import SwiftUI

struct HealthView: View {
    @EnvironmentObject var health: HealthMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var animateAppear = false
    
    var body: some View {
        ZStack {
            // Background overlay for dismissing
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Content card
            VStack(alignment: .leading, spacing: Design.Spacing.xl) {
            // Header
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 24))
                    .foregroundColor(Design.Colors.primary)
                    .scaleEffect(animateAppear ? 1.0 : 0.9)
                    .animation(Design.Animation.bounce.repeatForever(autoreverses: true), value: animateAppear)
                
                Text("健康状态")
                    .font(Design.Typography.largeTitle)
                    .foregroundColor(Design.Colors.textPrimary)
                
                Spacer()
                
                // Status indicator
                HStack(spacing: Design.Spacing.sm) {
                    Circle()
                        .fill(overallHealthColor)
                        .frame(width: 8, height: 8)
                    Text(overallHealthStatus)
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.textSecondary)
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.xs)
                .background(
                    Capsule()
                        .fill(overallHealthColor.opacity(0.1))
                )
            }
            .padding(.bottom, Design.Spacing.md)
            
            // Performance Metrics
            VStack(spacing: Design.Spacing.lg) {
                HStack(spacing: Design.Spacing.md) {
                    MetricCard(
                        title: "运行时间",
                        value: formatUptime(health.metrics.uptime),
                        color: Design.Colors.success,
                        icon: "clock.fill"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.2), value: animateAppear)
                    
                    MetricCard(
                        title: "平均延迟",
                        value: String(format: "%.1f ms", health.metrics.avgPingMs),
                        color: pingColor(health.metrics.avgPingMs),
                        icon: "network"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.3), value: animateAppear)
                    
                    MetricCard(
                        title: "发送队列",
                        value: "\(health.metrics.queueSize)",
                        color: queueColor(health.metrics.queueSize),
                        icon: "tray.full"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.4), value: animateAppear)
                }
                
                HStack(spacing: Design.Spacing.md) {
                    MetricCardWithProgress(
                        title: "WebSocket事件",
                        value: "\(health.metrics.wsEvents)",
                        progress: min(Double(health.metrics.wsEvents) / 1000.0, 1.0),
                        color: Design.Colors.primary,
                        icon: "arrow.left.arrow.right.circle"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.5), value: animateAppear)
                    
                    MetricCardWithProgress(
                        title: "错误次数",
                        value: "\(health.metrics.errorCount)",
                        progress: min(Double(health.metrics.errorCount) / 10.0, 1.0),
                        color: errorCountColor(health.metrics.errorCount),
                        icon: "exclamationmark.triangle"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.6), value: animateAppear)
                    
                    MetricCardWithProgress(
                        title: "重连次数",
                        value: "\(health.metrics.reconnectCount)",
                        progress: min(Double(health.metrics.reconnectCount) / 5.0, 1.0),
                        color: reconnectColor(health.metrics.reconnectCount),
                        icon: "arrow.clockwise"
                    )
                    .opacity(animateAppear ? 1 : 0)
                    .offset(y: animateAppear ? 0 : 20)
                    .animation(Design.Animation.smooth.delay(0.7), value: animateAppear)
                }
            }
            
            Spacer()
            
            // Close button
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(ModernButton(isPrimary: true))
            }
            .opacity(animateAppear ? 1 : 0)
            .animation(Design.Animation.smooth.delay(0.8), value: animateAppear)
            }
            .padding(Design.Spacing.xxl)
            .frame(maxWidth: 620, maxHeight: 450)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(Design.Radius.md)
            .shadow(color: Color.black.opacity(0.1), radius: 10)
            .padding(40)
        }
        .frame(minWidth: 700, minHeight: 530)
        .background(Color.clear)
        .onAppear {
            withAnimation {
                animateAppear = true
            }
        }
    }
    
    private var overallHealthColor: Color {
        if health.metrics.errorCount > 5 || health.metrics.reconnectCount > 3 {
            return Design.Colors.error
        } else if health.metrics.errorCount > 2 || health.metrics.reconnectCount > 1 {
            return Design.Colors.warning
        } else {
            return Design.Colors.success
        }
    }
    
    private var overallHealthStatus: String {
        if health.metrics.errorCount > 5 || health.metrics.reconnectCount > 3 {
            return "需要关注"
        } else if health.metrics.errorCount > 2 || health.metrics.reconnectCount > 1 {
            return "运行正常"
        } else {
            return "状态良好"
        }
    }
    
    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    private func pingColor(_ ping: Double) -> Color {
        if ping < 50 {
            return Design.Colors.success
        } else if ping < 150 {
            return Design.Colors.warning
        } else {
            return Design.Colors.error
        }
    }
    
    private func queueColor(_ size: Int) -> Color {
        if size < 50 {
            return Design.Colors.success
        } else if size < 150 {
            return Design.Colors.warning
        } else {
            return Design.Colors.error
        }
    }
    
    private func errorCountColor(_ count: Int) -> Color {
        if count == 0 {
            return Design.Colors.success
        } else if count < 3 {
            return Design.Colors.warning
        } else {
            return Design.Colors.error
        }
    }
    
    private func reconnectColor(_ count: Int) -> Color {
        if count == 0 {
            return Design.Colors.success
        } else if count < 2 {
            return Design.Colors.warning
        } else {
            return Design.Colors.error
        }
    }
}

// Minimal metric card with progress
struct MetricCardWithProgress: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    let icon: String?
    
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
            
            // Minimal progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 2)
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color.opacity(0.7))
                        .frame(width: geometry.size.width * progress, height: 2)
                        .animation(Design.Animation.smooth, value: progress)
                }
            }
            .frame(height: 2)
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
