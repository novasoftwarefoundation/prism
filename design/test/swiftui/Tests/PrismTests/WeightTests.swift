import Prism
import SwiftUI
import Testing
import UIKit

/// Each Typography names a weight; on iOS it is drawn in SF Pro at the number the
/// family's iOS scale gives it, chosen to look as heavy as Nunito and Nunito Sans at the
/// web's number (ADR 0013), at the default text size and at a large one.
struct WeightTests {
    /// SF Pro's number of each weight: titles are bold, not heavy, body text stays light.
    static let sfPro: [(PrismWeight, Int, UIFont.Weight)] = [
        (.light, 300, .light), (.regular, 400, .regular), (.medium, 400, .regular),
        (.semibold, 500, .medium), (.bold, 600, .semibold), (.extrabold, 700, .bold),
    ]

    static let typography: [(String, PrismTypography, PrismWeight)] = [
        ("title1", Prism.Typography.title1, .extrabold),
        ("title4", Prism.Typography.title4, .extrabold),
        ("title5", Prism.Typography.title5, .bold),
        ("title6", Prism.Typography.title6, .bold),
        ("subhead", Prism.Typography.subhead, .semibold),
        ("caption", Prism.Typography.caption, .medium),
        ("tablerow", Prism.Typography.tablerow, .regular),
        ("body", Prism.Typography.body, .light),
        ("label", Prism.Typography.label, .bold),
        ("button", Prism.Typography.button, .bold),
        ("hint", Prism.Typography.hint, .light),
    ]

    @Test func bothFamiliesHaveSFProsNumbers() {
        for family in [Prism.Families.display, Prism.Families.text] {
            #expect(family.font == .system)
            for (weight, number, _) in Self.sfPro {
                #expect(family.number(weight) == number, "\(weight)")
            }
        }
    }

    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraLarge])
    func aTypographyIsDrawnAtItsWeightsNumber(category: UIContentSizeCategory) {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        for (name, typography, weight) in Self.typography {
            #expect(typography.weight == weight, "\(name)")
            let (_, number, uiWeight) = Self.sfPro.first { $0.0 == weight }!
            #expect(typography.number == number, "\(name)")
            let font = typography.uiFont(compatibleWith: traits)
            let drawn = (font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight]
                as? CGFloat
            #expect(drawn == uiWeight.rawValue, "\(name) at \(category.rawValue): \(String(describing: drawn))")
        }
    }

    /// The link button's medium on top of the button's bold: SF Pro's 400.
    @Test func aLooksWeightIsTheFamilysNumberToo() {
        let font = PrismButtonLooks(.link).root.font
        #expect(font?.weight == .medium)
        #expect(font?.number == 400)
        #expect(PrismButtonLooks(.primary).root.font?.number == 600)
    }
}
