#if canImport(SwiftUI)
import SwiftUI

/// Shared outer navigation chrome. Text and dismissal have separate layout
/// slots, so long tool names cannot underlap the close/back touch target.
@available(iOS 15.0, macCatalyst 15.0, *)
public struct ScienceLabNavigationHeader: View {
    private let title: String
    private let subtitle: String?
    private let isBack: Bool
    private let labels: ScienceLabLabels
    private let onDismiss: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        subtitle: String? = nil,
        isBack: Bool = false,
        labels: ScienceLabLabels = .init(),
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isBack = isBack
        self.labels = labels
        self.onDismiss = onDismiss
    }

    private var compact: Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    private var meaningfulSubtitle: String? {
        guard let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return subtitle
    }

    private var spokenTitle: String {
        guard let subtitle = meaningfulSubtitle else { return title }
        return title + "\n" + subtitle
    }

    public var body: some View {
        ScienceLabGlassGroup {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !compact, let subtitle = meaningfulSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(spokenTitle))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("scienceLab.navigation.title")

                Button(action: onDismiss) {
                    Image(systemName: isBack ? "chevron.backward" : "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .modifier(ScienceLabSurface(cornerRadius: 14, interactive: true))
                }
                .buttonStyle(.plain)
                .fixedSize()
                .layoutPriority(1)
                .accessibilityLabel(Text(isBack ? labels.back : labels.close))
                .accessibilityIdentifier("scienceLab.navigation.dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 4 : 8)
            .frame(minHeight: 52)
        }
    }
}
#endif
