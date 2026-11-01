import Prism
import SwiftUI
import Testing
import UIKit

/// Every component at the default text size and at the largest accessibility size: a box
/// that holds text is never smaller than its text, so nothing is cut off, and it grows
/// as its text grows.
struct DynamicTypeTests {
    /// A component, its text, and the look its text is drawn in (`nil` for the system's).
    struct Sample {
        var name: String
        var text: String
        var look: PrismLook?
        var view: AnyView
    }

    static let message = "A message of more than one line at the largest text size"

    @MainActor static var samples: [Sample] {
        [
            Sample(
                name: "button", text: "Save", look: PrismButtonLooks(.primary).root,
                view: AnyView(Button("Save") {}.buttonStyle(.prism(.primary)))),
            Sample(
                name: "text field", text: "someone@example.org", look: PrismTextFieldLooks().root,
                view: AnyView(TextField("", text: .constant("someone@example.org")).prismTextField())),
            Sample(
                name: "text area", text: "A note", look: PrismTextAreaLooks().root,
                view: AnyView(TextEditor(text: .constant("A note")).prismTextArea())),
            Sample(
                name: "field", text: "Email", look: PrismFieldLooks().label,
                view: AnyView(PrismField(label: Text("Email")) { Color.clear.frame(height: 1) })),
            Sample(
                name: "radio group", text: "Yes", look: PrismRadioLooks().label,
                view: AnyView(PrismRadioGroup { PrismRadio(checked: true) { Text("Yes") } })),
            Sample(
                name: "radio", text: "Yes", look: PrismRadioLooks().label,
                view: AnyView(PrismRadio(checked: true) { Text("Yes") })),
            Sample(
                name: "select", text: "Choose one", look: PrismSelectLooks().field,
                view: AnyView(PrismSelect { Button("One") {} } label: { Text("Choose one") })),
            Sample(
                name: "spinner", text: "", look: nil,
                view: AnyView(ProgressView(value: 0.4).progressViewStyle(.prism(.accent)))),
            Sample(
                name: "checkbox", text: "Remember me", look: nil,
                view: AnyView(Toggle("Remember me", isOn: .constant(true)).toggleStyle(.prism()))),
            Sample(
                name: "tag", text: "Done", look: PrismTagLooks(tone: .success).label,
                view: AnyView(PrismTag(tone: .success) { Text("Done") })),
            Sample(
                name: "message bar", text: message, look: PrismMessageBarLooks().root,
                view: AnyView(PrismMessageBar { Text(message) })),
            Sample(
                name: "step indicator", text: "3", look: PrismStepIndicatorLooks().root,
                view: AnyView(PrismStepIndicator { Text("3") })),
        ]
    }

    /// The size a view takes in a phone's width at `size`.
    @MainActor func measure(
        _ view: some View, at size: DynamicTypeSize,
        height: CGFloat = .greatestFiniteMagnitude
    ) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: 390, height: height))
    }

    /// The components whose box has a height of the design's: they keep their text's
    /// height also where a stack offers them less.
    static let boxes = ["text field", "select", "message bar"]

    static let names = [
        "button", "text field", "text area", "field", "radio group", "radio", "select",
        "spinner", "checkbox", "tag", "message bar", "step indicator",
    ]

    @Test @MainActor func everyComponent() {
        #expect(Self.samples.map(\.name) == Self.names)
    }

    @Test(arguments: names)
    @MainActor func holdsItsText(_ name: String) throws {
        let sample = try #require(Self.samples.first { $0.name == name })
        let large = measure(sample.view, at: .large)
        let largest = measure(sample.view, at: .accessibility5)

        #expect(largest.width > 0 && largest.height > 0, "\(name) renders nothing")
        if sample.text.isEmpty { return }

        #expect(largest.height > large.height, "\(name) doesn't grow with its text")

        if let look = sample.look {
            // A text field keeps its text on one line and scrolls it.
            let line = Text(sample.text).prismText(look)
            let text = measure(
                name == "text field" ? AnyView(line.fixedSize()) : AnyView(line), at: .accessibility5)
            #expect(
                largest.height >= text.height,
                "\(name) is \(largest.height) high, its text \(text.height): the text is cut off")
            if Self.boxes.contains(name) {
                let squeezed = measure(sample.view, at: .accessibility5, height: 10)
                #expect(
                    squeezed.height >= text.height,
                    "\(name) offered less is \(squeezed.height) high, its text \(text.height)")
            }
            if sample.text.count == 1 {
                #expect(
                    largest.width >= text.width,
                    "\(name) is \(largest.width) wide, its text \(text.width): the text is cut off")
            }
        }
    }
}
