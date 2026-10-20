import SwiftUI

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        // The primary action, always in color. Tinted glass (`.glassProminent`, `.glassEffect(.tint)`)
        // renders grey in the menu bar popover, so this is a filled disc with a glass-like rim.
        let tint: Color = isRecording ? .red : .blue
        Button(action: action) {
            Image(systemName: isRecording ? "stop.fill" : "record.circle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Constants.UI.controlButtonSize, height: Constants.UI.controlButtonSize)
                .background(tint.gradient, in: .circle)
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.35), radius: isHovering ? 12 : 8, y: 3)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.smooth, value: isRecording)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHovering ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
            .animation(.smooth(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
