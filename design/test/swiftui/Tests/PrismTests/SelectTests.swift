import Prism
import SwiftUI
import Testing
import UIKit

/// A select's label beside its icon, which grows with Dynamic Type: the label stays clear of
/// it at every text size. At AX5 it ran into the chevron, which outgrew the field's fixed
/// 40 pt on its side (Flux 10549420830).
struct SelectTests {
    @Test(arguments: [DynamicTypeSize.large, .accessibility5])
    @MainActor func labelStaysClearOfItsIcon(_ size: DynamicTypeSize) async throws {
        @MainActor final class Frames {
            var select = CGRect.zero
            var label = CGRect.zero
        }
        let frames = Frames()
        let looks = PrismSelectLooks()
        let icon = Image(systemName: "chevron.down")
        let view = VStack {
            PrismSelect(icon: icon) { Button("One") {} } label: {
                Text("Bosnia and Herzegovina")
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) {
                        frames.label = $0
                    }
            }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) {
                frames.select = $0
            }
        }
        .padding(16)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: view.environment(\.dynamicTypeSize, size))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        window.layoutIfNeeded()

        // The icon at this text size, where the select puts it: its inset from the field's
        // trailing edge.
        let width = UIHostingController(
            rootView: icon.prismLook(looks.icon).environment(\.dynamicTypeSize, size)
        ).sizeThatFits(in: CGSize(width: 390, height: 844)).width
        let iconStart = frames.select.maxX - (looks.icon.inset.trailing ?? 0) - width

        #expect(frames.label.width > 0 && width > 0)
        #expect(
            frames.label.maxX <= iconStart,
            "at \(size) the label ends at \(frames.label.maxX), past the icon's start \(iconStart)")
    }
}
