import Prism
import SwiftUI
import Testing
import UIKit

/// The components Joeri compared (Flux 10549420830), one screen at the default text size
/// and at AX5, written to $PRISM_SHOTS as PNG. Screenshots only: not part of the PR's checks.
struct ScreenshotTests {
    @MainActor static var screen: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: .constant("someone@example.org")).prismTextField()
            TextField("", text: .constant("100")).prismTextField { Text("€") }
            PrismSelect(icon: Image(systemName: "chevron.down")) { Button("One") {} } label: {
                Text("Bosnia and Herzegovina")
            }
            PrismRadioGroup {
                PrismRadio(checked: true) { Text("Yes") }
                PrismRadio(checked: false) { Text("No") }
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

    @Test(arguments: [DynamicTypeSize.large, .accessibility5])
    @MainActor func screen(_ size: DynamicTypeSize) async throws {
        guard let out = ProcessInfo.processInfo.environment["PRISM_SHOTS"] else { return }
        let host = UIHostingController(
            rootView: Self.screen.environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, .light))
        host.safeAreaRegions = []
        var fitted = host.sizeThatFits(in: CGSize(width: 393, height: 4000))
        fitted.height += 400
        let window = UIWindow(frame: CGRect(origin: .zero, size: fitted))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        let name = size == .large ? "ios-default.png" : "ios-ax5.png"
        try FileManager.default.createDirectory(
            atPath: out, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: URL(fileURLWithPath: out).appending(path: name))
    }
}
