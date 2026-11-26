import Prism
import SwiftUI
import Testing
import UIKit

/// A message bar is its text's height and the design's padding above and below it, with the
/// design's least height as a floor, at every text size, as on Android and the web. At AX5
/// its least height scaled with Dynamic Type, which made a one-line bar about three times
/// its text's height (Flux 10549420830).
struct MessageBarTests {
    static let messages = [
        "Saved", "Your session ends in 5 minutes. Save your work to keep it.",
    ]

    @Test(arguments: [DynamicTypeSize.large, .accessibility5], messages)
    @MainActor func isItsTextAndPadding(_ size: DynamicTypeSize, _ message: String) {
        let look = PrismMessageBarLooks().root
        let width: CGFloat = 361
        func measure(_ view: some View, width: CGFloat) -> CGSize {
            UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
                .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        }
        let bar = measure(PrismMessageBar { Text(message) }, width: width)
        let padding = look.padding
        let inner = width - (padding.leading ?? 0) - (padding.trailing ?? 0)
        let text = measure(
            Text(message).prismText(look).multilineTextAlignment(.center), width: inner)
        let expected = max(look.minHeight ?? 0, text.height + (padding.top ?? 0) + (padding.bottom ?? 0))
        print("message bar at \(size), \"\(message.prefix(12))\": \(bar.height) pt, text \(text.height) pt")
        #expect(
            abs(bar.height - expected) <= 1,
            "at \(size) the bar is \(bar.height) pt high, its text \(text.height) pt: expected \(expected)")
    }
}
