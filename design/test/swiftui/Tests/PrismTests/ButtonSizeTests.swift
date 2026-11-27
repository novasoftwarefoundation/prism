import Prism
import Testing

/// A button's sizes on iOS and macOS (ADR 0006): regular, the default, is the look a
/// button has always had; small has every variant and tone, the buttonsmall typography,
/// less padding and a 16pt icon.
struct ButtonSizeTests {
    static let variants: [PrismButtonVariant?] = [nil] + PrismButtonVariant.allCases

    @Test func regularIsTheDefault() {
        #expect(PrismButtonStyle().size == .regular)
        for variant in Self.variants {
            for tone in PrismButtonTone.allCases {
                for pressed in [false, true] {
                    for padded in [false, true] {
                        for withIcon in [false, true] {
                            #expect(
                                PrismButtonLooks(
                                    variant, tone: tone, padded: padded, withIcon: withIcon,
                                    pressed: pressed)
                                    == PrismButtonLooks(
                                        variant, tone: tone, size: .regular, padded: padded,
                                        withIcon: withIcon, pressed: pressed))
                        }
                    }
                }
            }
        }
    }

    @Test func regular() {
        let primary = PrismButtonLooks(.primary).root
        #expect(primary.typography == Prism.Typography.button)
        #expect(primary.typography?.size == 18 && primary.typography?.lineHeight == 18)
        #expect(primary.padding == PrismInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
        #expect(
            PrismButtonLooks(.secondary).root.padding
                == PrismInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
        #expect(PrismButtonLooks(.primary, withIcon: true).icon.size == nil)
    }

    @Test(arguments: variants)
    func smallTypography(_ variant: PrismButtonVariant?) {
        for tone in PrismButtonTone.allCases {
            let root = PrismButtonLooks(variant, tone: tone, size: .small).root
            #expect(root.typography == Prism.Typography.buttonsmall)
            #expect(root.typography?.size == 16 && root.typography?.lineHeight == 16)
            // A tone colors a small button as a regular one.
            let regular = PrismButtonLooks(variant, tone: tone).root
            #expect(root.foreground == regular.foreground)
            #expect(root.background == regular.background)
            #expect(root.borderColor == regular.borderColor)
            #expect(root.borderWidth == regular.borderWidth)
        }
    }

    @Test func smallPadding() {
        let small = PrismInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let pressed = PrismInsets(top: 9, leading: 12, bottom: 7, trailing: 12)
        for variant in [PrismButtonVariant.primary, .soft, .plain, .text] {
            #expect(PrismButtonLooks(variant, size: .small).root.padding == small, "\(variant)")
            #expect(
                PrismButtonLooks(variant, size: .small, pressed: true).root.padding == pressed,
                "\(variant) pressed")
            #expect(
                PrismButtonLooks(variant, size: .small, withIcon: true).root.padding == small,
                "\(variant) with an icon")
        }

        // The secondary's 2pt border inside the same outer size.
        #expect(
            PrismButtonLooks(.secondary, size: .small).root.padding
                == PrismInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        #expect(
            PrismButtonLooks(.secondary, size: .small, pressed: true).root.padding
                == PrismInsets(top: 7, leading: 12, bottom: 5, trailing: 12))

        // Unpadded, a plain or text button keeps fitting its text.
        #expect(
            PrismButtonLooks(.plain, size: .small, padded: false).root.padding
                == PrismButtonLooks(.plain, padded: false).root.padding)
        #expect(
            PrismButtonLooks(.text, size: .small, padded: false).root.padding
                == PrismButtonLooks(.text, padded: false).root.padding)
    }

    @Test func smallIcon() {
        #expect(PrismButtonLooks(.primary, size: .small, withIcon: true).icon.size == 16)
        #expect(PrismButtonLooks(.icon, size: .small).root.size == 16)
        #expect(PrismButtonLooks(.icon).root.size == 24)
    }
}
