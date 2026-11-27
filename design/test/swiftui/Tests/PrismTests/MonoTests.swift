import Prism
import SwiftUI
import Testing

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The code typography: `mono` at 0.1.7's 20/24, `monosmall` and `monomedium` at the sizes of
/// `bodysmall` and `bodymedium`, all in the system font's monospaced design (SF Mono) at the
/// reading emphasis, on iOS and on macOS. No other typography is monospaced.
struct MonoTests {
    static let mono: [(String, PrismTypography, CGFloat, CGFloat)] = [
        ("mono", Prism.Typography.mono, 20, 24),
        ("monosmall", Prism.Typography.monosmall, 16, 24),
        ("monomedium", Prism.Typography.monomedium, 20, 30),
    ]

    @Test func theMonoTypographiesAreMonospacedAtBodyTextsSizes() {
        for (name, typography, size, lineHeight) in Self.mono {
            #expect(typography.monospaced, "\(name)")
            #expect(typography.emphasis == .reading, "\(name)")
            #expect(typography.weight == 300, "\(name)")
            #expect(typography.size == size, "\(name)")
            #expect(typography.lineHeight == lineHeight, "\(name)")
        }
        #expect(Prism.Typography.monosmall.size == Prism.Typography.bodysmall.size)
        #expect(Prism.Typography.monosmall.lineHeight == Prism.Typography.bodysmall.lineHeight)
        #expect(Prism.Typography.monomedium.size == Prism.Typography.bodymedium.size)
        #expect(Prism.Typography.monomedium.lineHeight == Prism.Typography.bodymedium.lineHeight)
        #expect(!Prism.Typography.body.monospaced)
        #expect(!Prism.Typography.bodysmall.monospaced)
    }

#if os(iOS)
    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraLarge])
    func theFontIsSFMonoAtTheReadingWeight(category: UIContentSizeCategory) {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        for (name, typography, _, _) in Self.mono {
            let font = typography.uiFont(compatibleWith: traits)
            #expect(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace), "\(name)")
            let weight = (font.fontDescriptor.object(forKey: .traits)
                as? [UIFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat
            #expect(weight == UIFont.Weight.light.rawValue, "\(name): \(String(describing: weight))")
        }
        let body = Prism.Typography.bodysmall.uiFont(compatibleWith: traits)
        #expect(!body.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
    }
#else
    @Test func theFontIsSFMonoAtItsSizeAndTheReadingWeight() {
        for (name, typography, size, _) in Self.mono {
            let font = typography.nsFont()
            #expect(font.pointSize == size, "\(name)")
            #expect(font.fontDescriptor.symbolicTraits.contains(.monoSpace), "\(name)")
            #expect(font.isFixedPitch, "\(name)")
            let weight = (font.fontDescriptor.object(forKey: .traits)
                as? [NSFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat
            #expect(weight == NSFont.Weight.light.rawValue, "\(name): \(String(describing: weight))")
        }
        #expect(!Prism.Typography.bodysmall.nsFont().isFixedPitch)
    }
#endif
}
