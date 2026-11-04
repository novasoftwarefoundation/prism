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

        func differs(from other: Drawn, by tolerance: CGFloat = 0.005) -> Bool {
            look.count != other.look.count
                || zip(look, other.look).contains { abs($0 - $1) > tolerance }
        }

        /// Whether this frame is on its way from `start` to `end`: a value that changes
        /// has come more than 1% and less than 99% of its way. By how far, not by how
        /// much, so a small change, such as white to a light grey, is on its way as long
        /// as a large one, and the last few milliseconds, when the move is already in
        /// its place, aren't.
        func between(_ start: Drawn, and end: Drawn) -> Bool {
            guard look.count == start.look.count, look.count == end.look.count else {
                return false
            }
            return look.indices.contains { i in
                let change = end.look[i] - start.look[i]
                guard abs(change) > 0.005 else { return false }
                let come = (look[i] - start.look[i]) / change
                return come > 0.01 && come < 0.99
            }
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

    /// A frame is on its way by how far its look has come, so the end of a transition,
    /// when the move is already in its place, doesn't count.
    @Test func onItsWayIsHowFarTheLookHasCome() {
        let start = Drawn(top: 0, look: [0])
        let end = Drawn(top: 0, look: [1])
        #expect(Drawn(top: 0, look: [0.5]).between(start, and: end))
        #expect(!Drawn(top: 0, look: [0.995]).between(start, and: end))
        #expect(!Drawn(top: 0, look: [0.005]).between(start, and: end))
        #expect(!Drawn(top: 0, look: [1]).between(start, and: end))
        #expect(!Drawn(top: 0, look: [0]).between(start, and: end))
    }

    /// How often the change is made before the test says the look doesn't animate.
    static let tries = 8

    /// How long what is drawn stays the same before it counts as settled: longer than
    /// any transition.
    static let quiet: Duration = .milliseconds(400)

    /// The frames that `settle` sampled, how long it took, and whether it settled.
    struct Sampled {
        var frames: [Drawn]
        var took: Duration
        var settled: Bool
    }

    /// Whether a try shows the look on its way: a frame of `change` between where
    /// `start`, the wait before the try, ended and where `change` ended.
    /// Both waits must have settled: the last frame of one that didn't is no look to
    /// start or end from.
    static func onItsWay(from start: Sampled, to change: Sampled) -> Bool {
        guard start.settled, change.settled, let first = start.frames.last,
            let end = change.frames.last
        else { return false }
        return change.frames.contains { $0.between(first, and: end) }
    }

    /// A try counts only when it starts and ends where what is drawn has settled: the
    /// last frame of a wait that didn't settle is no look to start or end from.
    @Test func aTryCountsOnlyBetweenSettledLooks() {
        func sampled(_ looks: [CGFloat], settled: Bool) -> Sampled {
            Sampled(frames: looks.map { Drawn(top: 0, look: [$0]) }, took: .zero, settled: settled)
        }
        // From 0 through 0.5 to 1: on its way.
        #expect(Self.onItsWay(from: sampled([0], settled: true), to: sampled([0.5, 1], settled: true)))
        // The same frames after a wait that didn't settle, or in one: not.
        #expect(!Self.onItsWay(from: sampled([0], settled: false), to: sampled([0.5, 1], settled: true)))
        #expect(!Self.onItsWay(from: sampled([0], settled: true), to: sampled([0.5, 1], settled: false)))
    }

    /// What is wrong with a try: `change`, the wait after the change, against `start`,
    /// the wait before it. A frame on its way between the two places is a slide.
    static func problems(in change: Sampled, from start: Sampled) -> [String] {
        guard let before = start.frames.last, let after = change.frames.last else {
            return ["nothing drawn"]
        }
        var problems: [String] = []
        if change.frames.contains(where: {
            abs($0.top - before.top) > 0.5 && abs($0.top - after.top) > 0.5
        }) {
            problems.append("slides to its place: \(change.frames.map { Int($0.top) })")
        }
        // The last frame of a wait that didn't settle is no look and no place: a try
        // with one is made again, and a look that never changes doesn't animate either.
        guard start.settled, change.settled else { return problems }
        if abs(after.top - before.top - space) >= 0.5 {
            problems.append("didn't move: \(describe(before)) to \(describe(after))")
        }
        if !after.differs(from: before) {
            problems.append("its look doesn't change: \(describe(before)) to \(describe(after))")
        }
        return problems
    }

    /// A try is judged only by waits that settled: the last frame of one that didn't
    /// is no look and no place. A frame between the two places is a slide all the same.
    @Test func aTryIsJudgedOnlyByWaitsThatSettled() {
        func sampled(_ frames: [(CGFloat, CGFloat)], settled: Bool) -> Sampled {
            Sampled(
                frames: frames.map { Drawn(top: $0.0, look: [$0.1]) }, took: .zero,
                settled: settled)
        }
        let start = sampled([(78, 0)], settled: true)
        // Moved, and its look changed: nothing wrong.
        #expect(Self.problems(in: sampled([(138, 1)], settled: true), from: start).isEmpty)
        // Its look didn't change, in a wait that settled: that is wrong.
        #expect(Self.problems(in: sampled([(138, 0)], settled: true), from: start).count == 1)
        // The same last frame of a wait that didn't settle (the simulator froze): no
        // look and no place to judge by.
        #expect(Self.problems(in: sampled([(138, 0)], settled: false), from: start).isEmpty)
        #expect(Self.problems(in: sampled([(78, 0)], settled: false), from: start).isEmpty)
        // A wait before the change that didn't settle: no look and no place to start from.
        #expect(
            Self.problems(in: sampled([(138, 0)], settled: true), from: sampled([(78, 0)], settled: false))
                .isEmpty)
        // A frame between the two places is a slide, settled or not.
        #expect(
            Self.problems(in: sampled([(108, 1), (138, 1)], settled: false), from: start).count
                == 1)
    }

    /// Whether a sample was judged at all: some try had its wait before the change and
    /// its wait after it settled.
    static func judged(_ tries: [(start: Sampled, change: Sampled)]) -> Bool {
        tries.contains { $0.start.settled && $0.change.settled }
    }

    /// A sample whose waits never settled wasn't judged: a look or a move that never
    /// comes leaves every wait unsettled, and that must fail, also for a known issue.
    @Test func aSampleIsJudgedOnlyWhenATrySettled() {
        let settled = Sampled(frames: [], took: .zero, settled: true)
        let unsettled = Sampled(frames: [], took: .zero, settled: false)
        #expect(!Self.judged([]))
        #expect(!Self.judged([(unsettled, unsettled), (settled, unsettled), (unsettled, settled)]))
        #expect(Self.judged([(unsettled, unsettled), (settled, settled)]))
    }

    /// What is drawn, sampled every 4 ms, from now until it has settled where `done`
    /// says or `limit` has passed.
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

    /// A window with the sample's screen, before its change.
    @MainActor static func show(_ sample: Sample, _ change: Change) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: Screen(sample: sample, change: change))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    @Test(arguments: samples)
    @MainActor func onlyTheLookAnimates(_ sample: Sample) async throws {
        // A loaded runner can stall the main thread for longer than a transition, and
        // then no frame shows the look on its way. So the change is made up to `tries`
        // times: a look that animates shows a frame on its way in one of them, a look
        // that doesn't in none. The first try stalls on purpose, as such a runner does.
        // A frame on its way also shows that the frames cover the transition, in which
        // a move that animates would slide. Each try has a window of its own, whose
        // look has settled before the change: the test says nothing about going back.
        var waits: [Sampled] = []
        var pairs: [(start: Sampled, change: Sampled)] = []
        var seen = ""
        var animated = false
        var tries = 0
        while tries < Self.tries {
            tries += 1
            let change = Change()
            let window = Self.show(sample, change)
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            let initial = try await Self.settle(in: window)
            waits.append(initial)
            let before = try #require(initial.frames.last, "\(sample): no box drawn")
            func moved(_ drawn: Drawn) -> Bool { abs(drawn.top - before.top - Self.space) < 0.5 }

            // One update, with no animation of its own: the space opens and the state
            // changes.
            change.on = true
            if tries == 1 {
                try await Task.sleep(for: .milliseconds(50))
                Self.stall()
            }
            let sampled = try await Self.settle(in: window) {
                moved($0) && $0.differs(from: before)
            }
            waits.append(sampled)
            pairs.append((initial, sampled))
            let frames = sampled.frames
            let after = try #require(frames.last)

            for problem in Self.problems(in: sampled, from: initial) {
                Issue.record("\(sample): \(problem)")
            }

            animated = Self.onItsWay(from: initial, to: sampled)
            if animated {
                // The frame that counts, between where the try started and ended.
                let on = frames.first { $0.between(before, and: after) }
                seen = "; on its way in try \(tries): \(Self.describe(before)) → "
                    + "\(on.map(Self.describe) ?? "?") → \(Self.describe(after))"
                break
            }
        }
        // A wait that didn't settle shows its last frames: where the box was and its look.
        let report = waits.map { wait in
            if wait.settled { return "\(wait.took)" }
            return "\(wait.took) (not settled; last frames: \(wait.frames.suffix(3).map(Self.describe)))"
        }
        print("AnimationTests \(sample): \(tries) tries; waits: \(report)\(seen)")
        // Outside the known issue: a look or a move that never comes leaves every wait
        // unsettled, and no try is judged.
        #expect(Self.judged(pairs), "\(sample): no try settled; waits: \(report)")
        withKnownIssue("A checkbox's checked look comes at once, also when it doesn't move") {
            #expect(
                animated,
                "\(sample): its look doesn't animate in \(tries) tries; waits: \(report)")
        } when: {
            sample.component == "checkbox" && sample.state == "checked"
        }
    }

    /// A frame as the log shows it: the box's top and its look, to three decimals.
    static func describe(_ frame: Drawn) -> String {
        "\(Int(frame.top)) \(frame.look.map { ($0 * 1000).rounded() / 1000 })"
    }
}
