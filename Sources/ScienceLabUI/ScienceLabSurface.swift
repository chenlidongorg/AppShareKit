#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scienceLabPalette) private var palette
    var cornerRadius: CGFloat = 18
    var interactive = false
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(palette.opaqueSurface, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                content.glassEffect(
                    .regular.tint(tint ?? .clear).interactive(interactive),
                    in: shape
                )
            } else {
                fallback(content, shape: shape)
            }
            #else
            fallback(content, shape: shape)
            #endif
        }
    }

    private func fallback(_ content: Content, shape: RoundedRectangle) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macCatalyst 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 4) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
#endif
