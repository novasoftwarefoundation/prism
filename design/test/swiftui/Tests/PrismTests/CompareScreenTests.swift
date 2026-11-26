import Foundation
import Prism
import SwiftUI
import Testing
import UIKit

/// The compare screen (design/test/compare/compare.sh): a component of every kind, as on
/// Android (design/test/compose, CompareScreenTest) and the web (design/test/compare/web.mjs),
/// at the default text size and at the largest, AX5, written to $PRISM_COMPARE as PNG. It
/// makes images and checks nothing: without PRISM_COMPARE it is skipped.
struct CompareScreenTests {
    static let out = ProcessInfo.processInfo.environment["PRISM_COMPARE"] ?? ""

    @MainActor static var screen: some View {
        VStack(alignment: .leading, spacing: 16) {
            Flow {
                ForEach(
                    [(PrismButtonVariant.primary, "Primary"), (.secondary, "Secondary"), (.soft, "Soft"),
                     (.plain, "Plain"), (.link, "Link"), (.text, "Text")], id: \.1
                ) { variant, name in
                    Button(name) {}.buttonStyle(.prism(variant))
                }
                Button {} label: { Image(systemName: "plus") }
                    .buttonStyle(.prism(.icon))
                    .accessibilityLabel("Add")
            }
            Flow {
                ForEach(
                    [(PrismButtonTone.success, "Success"), (.warning, "Warning"), (.danger, "Danger"),
                     (.neutral, "Neutral"), (.highlight, "Highlight")], id: \.1
                ) { tone, name in
                    Button(name) {}.buttonStyle(.prism(.primary, tone: tone))
                }
                Button("Disabled") {}.buttonStyle(.prism(.primary)).disabled(true)
                Button("Loading") {}.buttonStyle(.prism(.primary, loading: true))
            }
            PrismField(label: Text("Email")) {
                TextField("", text: .constant("someone@example.org")).prismTextField()
            }
            PrismField(invalid: true, label: Text("Name"), errorMessage: Text("Enter your name")) {
                TextField("", text: .constant("")).prismTextField(invalid: true)
            }
            TextField("", text: .constant("100")).prismTextField { Text("€") }
            TextEditor(text: .constant("Notes about the visit, on more than one line."))
                .prismTextArea()
                .frame(height: 96)
            PrismSelect(icon: Image(systemName: "chevron.down")) { Button("One") {} } label: {
                Text("Bosnia and Herzegovina")
            }
            Toggle("Remember me", isOn: .constant(true)).toggleStyle(.prism())
            PrismRadioGroup {
                PrismRadio(checked: true) { Text("Yes") }
                PrismRadio(checked: false) { Text("No") }
            }
            HStack(spacing: 16) {
                ProgressView().progressViewStyle(.prism(.accent))
                ProgressView(value: 0.4).progressViewStyle(.prism(.accent, size: .size32))
            }
            Flow {
                ForEach(
                    [(PrismTagTone.accent, "Accent"), (.success, "Success"), (.warning, "Warning"),
                     (.danger, "Danger"), (.neutral, "Neutral")], id: \.1
                ) { tone, name in
                    PrismTag(tone: tone) { Text(name) }
                }
            }
            PrismMessageBar { Text("Saved") }
            PrismMessageBar(tone: .warning) {
                Text("Your session ends in 5 minutes. Save your work to keep it.")
            }
            HStack(spacing: 8) {
                PrismStepIndicator(status: .complete) { Text("1") }
                PrismStepIndicator(status: .current) { Text("2") }
                PrismStepIndicator { Text("3") }
            }
            PrismImagePicker { Color(white: 0.733) } button: {
                Button("Choose a photo") {}.buttonStyle(.prism(.primary))
            }
        }
        .padding(16)
        .frame(width: 393, alignment: .topLeading)
        .background(Color.white)
    }

    @Test(.enabled(if: !out.isEmpty, "PRISM_COMPARE names the folder for the images"),
          arguments: [DynamicTypeSize.large, .accessibility5])
    @MainActor func screen(_ size: DynamicTypeSize) async throws {
        // The screen's height, measured in a window taller than it can be, then the window
        // cut to it: a text field settles its height only once it is laid out.
        let height = Height()
        let host = UIHostingController(
            rootView: Self.screen
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.value = $0 }
                .frame(maxHeight: .infinity, alignment: .top)
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, .light))
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 6000))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        window.frame.size.height = height.value.rounded(.up)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        let name = size == .large ? "compare-ios-default.png" : "compare-ios-ax5.png"
        try FileManager.default.createDirectory(atPath: Self.out, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: URL(fileURLWithPath: Self.out).appending(path: name))
    }
}

@MainActor private final class Height {
    var value: CGFloat = 0
}

/// Its views in rows, the next row where one is full, as Compose's FlowRow and the web's
/// flex-wrap do.
private struct Flow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(in: proposal.width ?? .infinity, subviews)
        return CGSize(
            width: proposal.width ?? frames.map(\.maxX).max() ?? 0,
            height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        for (frame, subview) in zip(frames(in: bounds.width, subviews), subviews) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(in width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += row + spacing
                row = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            row = max(row, size.height)
        }
        return frames
    }
}
