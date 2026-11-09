import Prism
import SwiftUI
import Testing
import UIKit

/// Each Typography names an emphasis; on iOS it is drawn in SF Pro at the weight the
/// family's iOS scale gives it, chosen to look as heavy as Nunito and Nunito Sans at the
/// web's weight (ADR 0013), at the default text size and at a large one.
struct EmphasisTests {
    /// SF Pro's weight of each emphasis: headlines are bold, not heavy; reading text stays light.
    static let sfPro: [(PrismEmphasis, Int, UIFont.Weight)] = [
        (.reading, 300, .light), (.data, 400, .regular), (.supporting, 400, .regular),
        (.subheading, 500, .medium), (.strong, 600, .semibold), (.headline, 700, .bold),
    ]

    static let typography: [(String, PrismTypography, PrismEmphasis)] = [
        ("title1", Prism.Typography.title1, .headline),
        ("title4", Prism.Typography.title4, .headline),
        ("title5", Prism.Typography.title5, .strong),
        ("title6", Prism.Typography.title6, .strong),
        ("subhead", Prism.Typography.subhead, .subheading),
        ("caption", Prism.Typography.caption, .supporting),
        ("tablerow", Prism.Typography.tablerow, .data),
        ("body", Prism.Typography.body, .reading),
        ("label", Prism.Typography.label, .strong),
        ("button", Prism.Typography.button, .strong),
        ("hint", Prism.Typography.hint, .reading),
    ]

    @Test func bothFamiliesHaveSFProsWeights() {
        for family in [Prism.Families.display, Prism.Families.text] {
            #expect(family.font == .system)
            for (emphasis, weight, _) in Self.sfPro {
                #expect(family.weight(emphasis) == weight, "\(emphasis)")
            }
        }
    }

    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraLarge])
    func aTypographyIsDrawnAtItsEmphasissWeight(category: UIContentSizeCategory) {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        for (name, typography, emphasis) in Self.typography {
            #expect(typography.emphasis == emphasis, "\(name)")
            let (_, weight, uiWeight) = Self.sfPro.first { $0.0 == emphasis }!
            #expect(typography.weight == weight, "\(name)")
            let font = typography.uiFont(compatibleWith: traits)
            let drawn = (font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight]
                as? CGFloat
            #expect(drawn == uiWeight.rawValue, "\(name) at \(category.rawValue): \(String(describing: drawn))")
        }
    }

    /// The link button's supporting on top of the button's strong: SF Pro's 400.
    @Test func aLooksEmphasisIsTheFamilysWeightToo() {
        let font = PrismButtonLooks(.link).root.font
        #expect(font?.emphasis == .supporting)
        #expect(font?.weight == 400)
        #expect(PrismButtonLooks(.primary).root.font?.weight == 600)
    }
}
