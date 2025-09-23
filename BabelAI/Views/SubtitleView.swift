import SwiftUI
import AppKit

// Modern subtitle view with glass morphism effect
struct SubtitleView: View {
    @EnvironmentObject var transcript: TranscriptModel
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Design.Spacing.md) {
                    if transcript.items.isEmpty {
                        VStack(spacing: Design.Spacing.md) {
                            Image(systemName: "captions.bubble")
                                .font(.system(size: 42))
                                .foregroundColor(Design.Colors.secondary.opacity(0.2))
                            Text("等待字幕内容...")
                                .font(Design.Typography.body)
                                .foregroundColor(Design.Colors.textSecondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                    } else {
                        ForEach(transcript.items.suffix(40), id: \.id) { item in
                            TranscriptItemView(
                                item: item,
                                isHovered: hoveredItemId == item.id
                            )
                            .onHover { hovering in
                                withAnimation(Design.Animation.smooth) {
                                    hoveredItemId = hovering ? item.id : nil
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .padding(Design.Spacing.xl)
                .onChange(of: transcript.items.count) { _ in
                    // Auto-scroll to bottom when new items are added
                    withAnimation(Design.Animation.smooth) {
                        if let lastItem = transcript.items.last {
                            proxy.scrollTo(lastItem.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 520, minHeight: 320)
    }
}

// Individual transcript item view
struct TranscriptItemView: View {
    let item: TranscriptItem
    let isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            if !item.source.isEmpty {
                HStack(alignment: .top, spacing: Design.Spacing.sm) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Design.Colors.secondary.opacity(0.5))
                    
                    Text(item.source)
                        .font(Design.Typography.body)
                        .foregroundColor(Design.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if !item.target.isEmpty {
                HStack(alignment: .top, spacing: Design.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(Design.Colors.secondary.opacity(0.4))
                    
                    Text(item.target)
                        .font(Design.Typography.body)
                        .foregroundColor(Design.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Design.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.gray.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 0.5)
        )
    }
}

final class SubtitleWindowController: NSWindowController {
    private var hosting: NSHostingView<AnyView>?
    private var isAlwaysOnTop: Bool = true

    convenience init(transcript: TranscriptModel) {
        let view = SubtitleView().environmentObject(transcript)
        let hosting = NSHostingView(rootView: AnyView(view))
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 520, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Babel AI Subtitles"
        window.level = .floating
        window.contentView = hosting
        self.init(window: window)
        self.hosting = hosting
    }

    func apply(opacity: Double, alwaysOnTop: Bool) {
        window?.alphaValue = CGFloat(max(0.3, min(1.0, opacity)))
        isAlwaysOnTop = alwaysOnTop
        window?.level = alwaysOnTop ? .floating : .normal
    }
}
