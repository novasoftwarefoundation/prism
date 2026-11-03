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
        // DIAGNOSTIC: the views behind the box and its background.
        var source = ""

        func differs(from other: Drawn) -> Bool {
            look.count != other.look.count
                || zip(look, other.look).contains { abs($0 - $1) > 0.005 }
        }
    }

    /// The component's box, the first layer with a border, as it is on screen now.
    @MainActor static func drawn(in window: UIWindow) -> Drawn? {
        let screen = window.layer.presentation() ?? window.layer
        var layers: [CALayer] = []
        var models: [ObjectIdentifier: CALayer] = [:]
        func walk(_ layer: CALayer) {
            let shown = layer.presentation() ?? layer
            layers.append(shown)
            models[ObjectIdentifier(shown)] = layer
            layer.sublayers?.forEach(walk)
        }
        walk(window.layer)
        func view(_ layer: CALayer?) -> String {
            guard let layer else { return "none" }
            let model = models[ObjectIdentifier(layer)] ?? layer
            return "\(type(of: model))/\(model.delegate.map { "\(type(of: $0))" } ?? "no view")"
        }
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
                + [opacity],
            source: "box \(view(box)), background \(view(background))")
    }

    /// Blocks the calling thread for longer than any transition, as a loaded runner can.
    static func stall() {
        Thread.sleep(forTimeInterval: 0.5)
    }

    static func components(_ color: CGColor?) -> [CGFloat] {
        guard let color,
            let srgb = CGColorSpace(name: CGColorSpace.extendedSRGB),
            let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?
                .components
        else { return [0, 0, 0, 0] }
        return components
    }

    /// How often the change is made before the test says the look doesn't animate.
    static let tries = 5

    /// How long what is drawn stays the same before it counts as settled: longer than
    /// any transition.
    static let quiet: Duration = .milliseconds(400)

    /// What was drawn, sampled every 4 ms, from now until it has settled where `done`
    /// says or `limit` has passed.
    struct Sampled {
        var frames: [Drawn]
        /// How long it took, and whether it settled.
        var took: Duration
        var settled: Bool
    }

    @MainActor static func settle(
        in window: UIWindow, limit: Duration = .seconds(10),
        until done: (Drawn) -> Bool = { _ in true }
    ) async throws -> Sampled {
        let clock = ContinuousClock()
        let start = clock.now
        var sampled = Sampled(frames: [], took: .zero, settled: false)
        var anchor: Drawn?
        var changed = start
        while clock.now - start < limit {
            try await Task.sleep(for: .milliseconds(4))
            guard let drawn = drawn(in: window) else { continue }
            sampled.frames.append(drawn)
            // Compared with the frame where it last changed, not the previous one, so a
            // slow end of an easing still counts as a change.
            if let anchor, !anchor.differs(from: drawn), abs(anchor.top - drawn.top) <= 0.5 {
                if done(drawn) && clock.now - changed >= quiet {
                    sampled.settled = true
                    break
                }
            } else {
                anchor = drawn
                changed = clock.now
            }
        }
        sampled.took = clock.now - start
        return sampled
    }

    @Test(arguments: samples)
    @MainActor func onlyTheLookAnimates(_ sample: Sample) async throws {
        let change = Change()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: Screen(sample: sample, change: change))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        var waits = [Sampled]()
        waits.append(try await Self.settle(in: window))
        let before = try #require(Self.drawn(in: window), "\(sample): no box drawn")
        func moved(_ drawn: Drawn) -> Bool { abs(drawn.top - before.top - Self.space) < 0.5 }

        // A loaded runner can stall the main thread for longer than a transition, and
        // then no frame shows the look on its way. So the change is made up to `tries`
        // times: a look that animates shows a frame on its way in one of them, a look
        // that doesn't in none. The first try stalls on purpose, as such a runner does.
        // A frame on its way also shows that the frames cover the transition, in which
        // a move that animates would slide.
        var start = before
        var animated = false
        var tries = 0
        while tries < Self.tries {
            tries += 1
            // One update, with no animation of its own: the space opens and the state
            // changes.
            change.on = true
            if tries == 1 {
                try await Task.sleep(for: .milliseconds(50))
                Self.stall()
            }
            let sampled = try await Self.settle(in: window) {
                moved($0) && $0.differs(from: start)
            }
            waits.append(sampled)
            let frames = sampled.frames
            let after = try #require(frames.last)

            #expect(moved(after), "\(sample): didn't move")
            let sliding = frames.filter {
                abs($0.top - before.top) > 0.5 && abs($0.top - after.top) > 0.5
            }
            #expect(
                sliding.isEmpty,
                "\(sample): slides to its place: \(frames.map { Int($0.top) })")
            #expect(after.differs(from: start), "\(sample): its look doesn't change")

            animated = frames.contains { $0.differs(from: start) && $0.differs(from: after) }
            // DIAGNOSTIC
            let partway = frames.filter { $0.differs(from: start) && $0.differs(from: after) }
            print(
                "AnimationTests \(sample) try \(tries): \(frames.count) frames, \(partway.count) partway; start \(start.look.map { ($0 * 1000).rounded() / 1000 }) after \(after.look.map { ($0 * 1000).rounded() / 1000 }); first partway \(partway.first?.look.map { ($0 * 1000).rounded() / 1000 } ?? []); \(after.source)"
            )
            if animated || tries == Self.tries { break }
            // Back, for the next try, which starts from where this one ends.
            change.on = false
            let back = try await Self.settle(in: window) { abs($0.top - before.top) < 0.5 }
            waits.append(back)
            start = try #require(back.frames.last)
        }
        let report = waits.map { "\($0.took)\($0.settled ? "" : " (not settled)")" }
        print("AnimationTests \(sample): \(tries) tries; waits: \(report)")
        withKnownIssue("A checkbox's checked look comes at once, also when it doesn't move") {
            #expect(
                animated,
                "\(sample): its look doesn't animate in \(tries) tries; waits: \(report)")
        } when: {
            sample.component == "checkbox" && sample.state == "checked"
        }
    }
}
