import Prism
import SwiftUI
import Testing
import UIKit

/// The message bars Melle found too large on iOS (Flux 10549420830): a one-line and a
/// two-line bar, at the default text size and at AX5, written to $PRISM_SHOTS as PNG.
/// Screenshots only: not part of the PR's checks.
struct MessageBarShots {
    @MainActor static var screen: some View {
        VStack(alignment: .leading, spacing: 16) {
            PrismMessageBar { Text("Saved") }
            PrismMessageBar(tone: .warning) {
                Text("Your session ends in 5 minutes. Save your work to keep it.")
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
        let fitted = host.sizeThatFits(in: CGSize(width: 393, height: 4000))
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
        let name = size == .large ? "ios-message-bars-default.png" : "ios-message-bars-ax5.png"
        try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: URL(fileURLWithPath: out).appending(path: name))
    }
}
