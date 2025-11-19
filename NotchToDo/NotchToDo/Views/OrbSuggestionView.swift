import Cocoa
import SwiftUI

/// SwiftUI view for displaying orb suggestions
struct OrbSuggestionListView: View {
    let suggestion: OrbSuggestion
    let onSelect: (ProjectOrb) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Suggested Folders")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Task preview
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 12))

                Text(suggestion.taskText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))

            // Suggestions list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(Array(suggestion.topMatches.enumerated()), id: \.element.orb.id) { index, match in
                        OrbSuggestionRow(
                            orb: match.orb,
                            confidence: match.confidence,
                            method: match.method,
                            isPrimary: index == 0
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(match.orb)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 280)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

/// Row for a single orb suggestion
struct OrbSuggestionRow: View {
    let orb: ProjectOrb
    let confidence: Double
    let method: OrbClassificationResult.ClassificationMethod
    let isPrimary: Bool

    private var orbColor: Color {
        Color(nsColor: orb.color)
    }

    private var confidenceText: String {
        String(format: "%.0f%%", confidence * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Orb color indicator
            Circle()
                .fill(orbColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            // Orb info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(orb.name)
                        .font(.system(size: 13, weight: isPrimary ? .semibold : .regular))
                        .foregroundColor(.white)

                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                }

                HStack(spacing: 4) {
                    Text("\(orb.taskCount) tasks")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))

                    Text(method.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Confidence badge
            Text(confidenceText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(confidenceColor.opacity(0.15))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isPrimary ? Color.white.opacity(0.08) : Color.clear
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var confidenceColor: Color {
        if confidence > 0.7 {
            return Color.green
        } else if confidence > 0.4 {
            return Color.yellow
        } else {
            return Color.orange
        }
    }
}

/// Visual effect blur for macOS
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// AppKit wrapper for the suggestion view
class OrbSuggestionViewController: NSViewController {
    private let suggestion: OrbSuggestion
    private let onSelect: (ProjectOrb) -> Void
    private let onDismiss: () -> Void

    init(suggestion: OrbSuggestion, onSelect: @escaping (ProjectOrb) -> Void, onDismiss: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingView = NSHostingView(
            rootView: OrbSuggestionListView(
                suggestion: suggestion,
                onSelect: onSelect,
                onDismiss: onDismiss
            )
        )
        self.view = hostingView
    }
}
