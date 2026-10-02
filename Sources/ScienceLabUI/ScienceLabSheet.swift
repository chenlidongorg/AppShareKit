#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabSheet<Content: View>: View {
    let title: String
    let doneLabel: String
    let prefersLarge: Bool
    let identifier: String
    private let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, doneLabel: String, prefersLarge: Bool, identifier: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.doneLabel = doneLabel
        self.prefersLarge = prefersLarge
        self.identifier = identifier
        self.content = content
    }

    var body: some View {
        sheetContent
            .modifier(ScienceLabSheetSizing(prefersLarge: prefersLarge))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }

    private var sheetContent: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneLabel) { dismiss() }
                        .accessibilityIdentifier("\(identifier).done")
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct ScienceLabSheetSizing: ViewModifier {
    let prefersLarge: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            content
                .presentationDetents(prefersLarge || dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
#endif
