#if os(macOS)
import AppKit
import Prism
import SwiftUI
import Testing

/// Prism's components on macOS, where there is no Dynamic Type: each holds its text at the
/// typography's size in an AppKit view, and draws something in light and in dark, on the
/// window background of that appearance. With `PRISM_SNAPSHOTS` set to a folder, each
/// drawing is written there as a PNG (`swift test` in design/test/swiftui).
struct MacOSTests {
    struct Sample {
        var name: String
        var look: PrismLook?
        var view: AnyView
    }

    @MainActor static var samples: [Sample] {
        [
            Sample(
                name: "button", look: PrismButtonLooks(.primary).root,
                view: AnyView(
                    HStack {
                        Button("Save") {}.buttonStyle(.prism(.primary))
                        Button("Cancel") {}.buttonStyle(.prism(.secondary))
                        Button("Delete") {}.buttonStyle(.prism(.primary, tone: .danger))
                        Button("Saving") {}.buttonStyle(.prism(.primary, loading: true))
                    })),
            Sample(
                name: "tag", look: PrismTagLooks(tone: .success).label,
                view: AnyView(
                    HStack {
                        ForEach(PrismTagTone.allCases, id: \.self) { tone in
                            PrismTag(tone: tone) { Text("\(tone)".capitalized) }
                        }
                    })),
            Sample(
                name: "step indicator", look: PrismStepIndicatorLooks().root,
                view: AnyView(
                    HStack {
                        PrismStepIndicator(status: .complete) { Text("1") }
                        PrismStepIndicator(status: .current) { Text("2") }
                        PrismStepIndicator(status: .incomplete) { Text("3") }
                    })),
            Sample(
                name: "radio group", look: PrismRadioLooks().label,
                view: AnyView(
                    PrismRadioGroup {
                        PrismRadio(checked: true) { Text("Yes") }
                        PrismRadio { Text("No") }
                        PrismRadio { Text("Maybe") }.disabled(true)
                    })),
            Sample(
                name: "message bar", look: PrismMessageBarLooks().root,
                view: AnyView(
                    VStack {
                        ForEach(PrismMessageBarTone.allCases, id: \.self) { tone in
                            PrismMessageBar(tone: tone) { Text(verbatim: "A message: \(tone)") }
                        }
                    })),
            Sample(
                name: "spinner", look: nil,
                view: AnyView(
                    HStack {
                        ForEach(PrismSpinnerSize.allCases, id: \.self) { size in
                            ProgressView().progressViewStyle(.prism(.accent, size: size))
                        }
                        ProgressView(value: 0.4).progressViewStyle(.prism(.accent, size: .size32))
                    })),
        ]
    }

    static let names = [
        "button", "tag", "step indicator", "radio group", "message bar", "spinner",
    ]

    /// The view 480pt wide on the window background of `scheme`, drawn at 2x. SwiftUI's
    /// ImageRenderer, not AppKit's cacheDisplay, which flattens curves into polygons.
    @MainActor func draw(_ view: some View, _ scheme: ColorScheme) throws -> NSBitmapImageRep {
        let appearance = try #require(NSAppearance(named: scheme == .dark ? .darkAqua : .aqua))
        var background = NSColor.windowBackgroundColor
        appearance.performAsCurrentDrawingAppearance {
            background = NSColor(cgColor: NSColor.windowBackgroundColor.cgColor) ?? background
        }
        let content = view.padding(16).frame(width: 480)
            .background(Color(nsColor: background))
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    @Test(arguments: names, [ColorScheme.light, .dark])
    @MainActor func drawsAndHoldsItsText(_ name: String, _ scheme: ColorScheme) throws {
        let sample = try #require(Self.samples.first { $0.name == name })

        // A box that holds text is at least the typography's line high.
        if let line = sample.look?.font?.lineHeight {
            let fitting = NSHostingView(rootView: sample.view).fittingSize
            #expect(fitting.height >= line, "\(name): \(fitting.height) < \(line)")
        }

        // It draws: more than the window's background.
        let bitmap = try draw(sample.view, scheme)
        #expect(bitmap.pixelsWide == 960 && bitmap.pixelsHigh > 64, "\(name): \(bitmap.size)")
        var colors = Set<UInt32>()
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
                guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                colors.insert(
                    UInt32(c.redComponent * 255) << 16 | UInt32(c.greenComponent * 255) << 8
                        | UInt32(c.blueComponent * 255))
            }
        }
        #expect(colors.count > 2, "\(name) draws nothing in \(scheme)")

        if let folder = ProcessInfo.processInfo.environment["PRISM_SNAPSHOTS"] {
            let file = "\(name.replacingOccurrences(of: " ", with: "-"))-\(scheme).png"
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(file))
        }
    }

    /// The text field and the select are Prism's box, not AppKit's bordered text field
    /// inside it or its grey pull-down button: across the middle of the box, from its
    /// leading border to its middle and from its top border to its bottom one, there is
    /// only the field's background. Empty, so no text is in the way. Drawn through AppKit,
    /// since ImageRenderer leaves AppKit's controls out.
    @Test(arguments: ["text field", "text field with prefix", "select"], [ColorScheme.light, .dark])
    @MainActor func anInputIsPrismsBox(_ name: String, _ scheme: ColorScheme) throws {
        let (look, view): (PrismLook, AnyView) =
            switch name {
            case "text field":
                (PrismTextFieldLooks().root,
                 AnyView(TextField("", text: .constant("")).prismTextField()))
            case "text field with prefix":
                (PrismTextFieldLooks().root,
                 AnyView(TextField("", text: .constant("")).prismTextField { Text("€") }))
            default:
                (PrismSelectLooks().field,
                 AnyView(PrismSelect(icon: Image(systemName: "chevron.down")) {
                     Button("Netherlands") {}
                 } label: {
                     Text(verbatim: "")
                 }))
            }
        let width: CGFloat = 240
        let host = NSHostingView(rootView: view.frame(width: width))
        host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(
            contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)

        if let folder = ProcessInfo.processInfo.environment["PRISM_SNAPSHOTS"] {
            let file = "\(name.replacingOccurrences(of: " ", with: "-"))-box-\(scheme).png"
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(file))
        }

        let background = try #require(
            look.background.flatMap { NSColor($0).usingColorSpace(.sRGB) })
        let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
        let inside = Int(((look.borderWidth ?? 0) + 1) * scale)
        let (w, h) = (bitmap.pixelsWide, bitmap.pixelsHigh)
        #expect(w == Int(width * scale), "\(name): \(w) pixels wide")
        // A prefix has a background of its own at the leading side, a select's icon is at
        // the trailing side; the column is between them.
        let row =
            switch name {
            case "text field with prefix": (w / 2)..<(w - inside)
            case "select": inside..<(w / 2)
            default: inside..<(w - inside)
            }
        let points = row.map { ($0, h / 2) } + (inside..<(h - inside)).map { (w * 3 / 4, $0) }
        let other = points.first { x, y in
            guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return true }
            return abs(c.redComponent - background.redComponent) > 0.02
                || abs(c.greenComponent - background.greenComponent) > 0.02
                || abs(c.blueComponent - background.blueComponent) > 0.02
        }
        #expect(
            other == nil, "\(name) in \(scheme): not its background at \(String(describing: other))")
    }

    /// A typography's font is SF Pro at the token's size (no Dynamic Type) and at the
    /// weight its emphasis has in the family, as on iOS.
    @Test(arguments: [
        (Prism.Typography.title1, NSFont.Weight.bold), (Prism.Typography.title5, .semibold),
        (Prism.Typography.subhead, .medium), (Prism.Typography.tablerow, .regular),
        (Prism.Typography.body, .light),
    ])
    func aTypographyIsItsSizeAndWeight(_ typography: PrismTypography, _ weight: NSFont.Weight) {
        let font = typography.nsFont()
        #expect(font.pointSize == typography.size)
        let drawn = (font.fontDescriptor.object(forKey: .traits)
            as? [NSFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat
        #expect(drawn == weight.rawValue, "\(typography.size): \(String(describing: drawn))")
    }
}
#endif
