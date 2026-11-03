import Prism
import SwiftUI
import Testing
import UIKit

/// A component whose look and place change in one update, as when an error message
/// appears above it: its look animates, its move doesn't.
///
/// A geometry reader only sees where a view ends up, so the test reads what is drawn:
/// SwiftUI draws a box's border and background as layers, and Core Animation shows
/// each frame of an animation in their presentation layers.
@Suite(.serialized) struct AnimationTests {
    @Observable @MainActor final class Change {
        var on = false
    }

    /// A component and the state the change sets on it.
    struct Sample: CustomTestStringConvertible, Sendable {
        var component: String
        var state: String
        var testDescription: String { "\(component), \(state)" }
    }

    static let samples = [
        Sample(component: "text field", state: "invalid"),
        Sample(component: "text field", state: "focused"),
        Sample(component: "text field", state: "disabled"),
        Sample(component: "text field with prefix", state: "invalid"),
        Sample(component: "text area", state: "invalid"),
        Sample(component: "text area", state: "focused"),
        Sample(component: "text area", state: "disabled"),
        Sample(component: "checkbox", state: "checked"),
        Sample(component: "checkbox", state: "disabled"),
        Sample(component: "radio", state: "checked"),
        Sample(component: "radio", state: "disabled"),
        // The app's group, as the button's documentation says: a style can't stop
        // SwiftUI's `Button` from animating its move.
        Sample(component: "button in a geometry group", state: "disabled"),
    ]

    /// How far the change moves the component down.
    static let space: CGFloat = 60

    /// The component with the change's state, below a space that the change opens.
    struct Screen: View {
        var sample: Sample
        var change: Change

        var body: some View {
            let on = change.on
            VStack(alignment: .leading, spacing: 0) {
                if on { Color.clear.frame(height: AnimationTests.space) }
                component(
                    invalid: on && sample.state == "invalid",
                    focused: on && sample.state == "focused",
                    checked: on && sample.state == "checked"
                )
                .disabled(on && sample.state == "disabled")
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        @ViewBuilder func component(invalid: Bool, focused: Bool, checked: Bool) -> some View {
            switch sample.component {
            case "text field":
                TextField("", text: .constant("someone@example.org"))
                    .prismTextField(focused: focused, invalid: invalid)
            case "text field with prefix":
                TextField("", text: .constant("100"))
                    .prismTextField(focused: focused, invalid: invalid) { Text("€") }
            case "text area":
                TextEditor(text: .constant("A note"))
                    .prismTextArea(focused: focused, invalid: invalid)
                    .frame(height: 88)
            case "checkbox":
                Toggle("Remember me", isOn: .constant(checked)).toggleStyle(.prism())
            case "radio":
                PrismRadio(checked: checked) { Text("Yes") }
            default:
                Button("Save") {}.buttonStyle(.prism(.secondary)).geometryGroup()
            }
        }
    }

    /// What is drawn of the component's box in one frame: where its top is, and its
    /// border color, its background and its opacity.
    struct Drawn {
        var top: CGFloat
        var look: [CGFloat]

        func differs(from other: Drawn) -> Bool {
            look.count != other.look.count
                || zip(look, other.look).contains { abs($0 - $1) > 0.005 }
        }
    }

    /// The component's box, the first layer with a border, as it is on screen now.
    @MainActor static func drawn(in window: UIWindow) -> Drawn? {
        let screen = window.layer.presentation() ?? window.layer
        var layers: [CALayer] = []
        func walk(_ layer: CALayer) {
            layers.append(layer.presentation() ?? layer)
            layer.sublayers?.forEach(walk)
        }
        walk(window.layer)
        func frame(_ layer: CALayer) -> CGRect { layer.convert(layer.bounds, to: screen) }
        guard let box = layers.first(where: { $0.borderWidth > 0 && !$0.isHidden }) else {
            return nil
        }
        let inside = frame(box).insetBy(dx: box.borderWidth, dy: box.borderWidth)
        let background = layers.last {
            $0.backgroundColor != nil && frame($0).width < window.bounds.width
                && frame($0).insetBy(dx: -0.5, dy: -0.5).contains(inside)
        }
        var opacity = CGFloat(1)
        var layer: CALayer? = box
        while let current = layer {
            opacity *= CGFloat(current.opacity)
            layer = current.superlayer
        }
        return Drawn(
            top: frame(box).minY,
            look: components(box.borderColor) + components(background?.backgroundColor)
                + [opacity])
    }

    static func components(_ color: CGColor?) -> [CGFloat] {
        guard let color,
            let srgb = CGColorSpace(name: CGColorSpace.extendedSRGB),
            let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?
                .components
        else { return [0, 0, 0, 0] }
        return components
    }

    @Test(arguments: samples)
    @MainActor func onlyTheLookAnimates(_ sample: Sample) async throws {
        let change = Change()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: Screen(sample: sample, change: change))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        let before = try #require(Self.drawn(in: window), "\(sample): no box drawn")

        // One update, with no animation of its own: the space opens and the state changes.
        change.on = true
        var frames: [Drawn] = []
        let clock = ContinuousClock()
        let end = clock.now + .milliseconds(500)
        while clock.now < end {
            try await Task.sleep(for: .milliseconds(4))
            if let drawn = Self.drawn(in: window) { frames.append(drawn) }
        }
        let after = try #require(frames.last)

        #expect(abs(after.top - before.top - Self.space) < 0.5, "\(sample): didn't move")
        let sliding = frames.filter {
            abs($0.top - before.top) > 0.5 && abs($0.top - after.top) > 0.5
        }
        #expect(
            sliding.isEmpty,
            "\(sample): slides to its place: \(frames.map { Int($0.top) })")

        #expect(after.differs(from: before), "\(sample): its look doesn't change")
        withKnownIssue("A checkbox's checked look comes at once, also when it doesn't move") {
            #expect(
                frames.contains { $0.differs(from: before) && $0.differs(from: after) },
                "\(sample): its look doesn't animate: \(before.look) to \(after.look)")
        } when: {
            sample.component == "checkbox" && sample.state == "checked"
        }
    }
}
