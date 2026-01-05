/**
 * Prism UI - Tailwind CSS Preset
 *
 * A playful but professional design system for scientific software.
 * Uses Nunito (>20px) and Nunito Sans (≤20px) variable fonts.
 */

const plugin = require("tailwindcss/plugin");

module.exports = {
  theme: {
    colors: {
      // Brand colors
      primary: "#4272EF",
      primarylight: "#E3EAFD",
      secondary: "#FF5E5E",
      tertiary: "#FFCF60",

      // Status colors
      success: "#52BA12",
      successlight: "#EBFFDF",
      warning: "#F28D15",
      warninglight: "#FFEFDC",
      error: "#DB1E1E",
      errorlight: "#FFECEC",
      delete: "#DB1E1E",
      deletelight: "#FFECEC",

      // Neutral colors
      black: "#000000",
      grey1: "#222222",
      grey2: "#999999",
      grey3: "#CCCCCC",
      grey4: "#EEEEEE",
      grey5: "#F6F6F6",
      grey6: "#FAFAFA",
      white: "#FFFFFF",
    },
    extend: {
      boxShadow: {
        top4px: "inset 0 4px 0 0 rgba(0, 0, 0, 0.15)",
        top2px: "inset 0 2px 0 0 rgba(0, 0, 0, 0.15)",
        floating: "0px 5px 20px 0px rgba(0, 0, 0, 0.10)",
      },
      spacing: {
        "1px": "1px",
        "2px": "2px",
        "3px": "3px",
        "5px": "5px",
        "6px": "6px",
        "7px": "7px",
        "9px": "9px",
        "10px": "10px",
        "11px": "11px",
        "13px": "13px",
        "14px": "14px",
        "15px": "15px",
        "17px": "17px",
        "18px": "18px",
        "19px": "19px",
        "22px": "22px",
        "30px": "30px",
        "44px": "44px",
        "48px": "48px",
        "60px": "60px",
        "64px": "64px",
        15: "60px",
        30: "120px",
      },
      height: {
        "44px": "44px",
      },
      fontFamily: {
        // Nunito (> 20px sizes)
        title0: ["Nunito", "sans-serif"],
        title1: ["Nunito", "sans-serif"],
        title2: ["Nunito", "sans-serif"],
        title3: ["Nunito", "sans-serif"],
        title4: ["Nunito", "sans-serif"],
        title5: ["Nunito", "sans-serif"],
        bodylarge: ["Nunito", "sans-serif"],
        introdesktop: ["Nunito", "sans-serif"],
        quote: ["Nunito", "sans-serif"],
        // Nunito Sans (≤ 20px sizes)
        title6: ["Nunito Sans", "sans-serif"],
        title7: ["Nunito Sans", "sans-serif"],
        caption: ["Nunito Sans", "sans-serif"],
        link: ["Nunito Sans", "sans-serif"],
        subhead: ["Nunito Sans", "sans-serif"],
        button: ["Nunito Sans", "sans-serif"],
        footnote: ["Nunito Sans", "sans-serif"],
        intro: ["Nunito Sans", "sans-serif"],
        label: ["Nunito Sans", "sans-serif"],
        body: ["Nunito Sans", "sans-serif"],
        hint: ["Nunito Sans", "sans-serif"],
        tablehead: ["Nunito Sans", "sans-serif"],
        tablerow: ["Nunito Sans", "sans-serif"],
        bold: ["Nunito Sans", "sans-serif"],
        mono: ["Nunito Sans", "sans-serif"],
      },
      fontSize: {
        title0: ["64px", "68px"],
        title1: ["50px", "55px"],
        title2: ["40px", "44px"],
        title3: ["32px", "38px"],
        title4: ["28px", "32px"],
        title5: ["24px", "26px"],
        title6: ["20px", "22px"],
        title7: ["16px", "20px"],
        caption: ["14px", "18px"],
        captionsmall: ["12px", "14px"],
        subhead: ["20px", "20px"],
        label: ["16px", "16px"],
        labelsmall: ["14px", "14px"],
        button: ["18px", "18px"],
        buttonsmall: ["16px", "16px"],
        footnote: ["16px", "30px"],
        intro: ["20px", "30px"],
        introdesktop: ["24px", "36px"],
        bodylarge: ["24px", "36px"],
        bodymedium: ["20px", "30px"],
        bodysmall: ["16px", "24px"],
        bodylinklarge: ["24px", "36px"],
        bodylinkmedium: ["30px", "30px"],
        link: ["16px", "24px"],
        hint: ["20px", "24px"],
        tablehead: ["14px", "16px"],
        tablerow: ["14px", "16px"],
        mono: ["20px", "24px"],
        quote: ["24px", "30px"],
      },
      maxHeight: {
        dropdown: "317px",
      },
    },
  },
  plugins: [
    plugin(function ({ addUtilities, addComponents }) {
      // Utility classes
      addUtilities({
        ".h-viewport": {
          height: "calc(var(--vh, 1vh) * 100)",
        },
        ".safe-top": {
          paddingTop: "env(safe-area-inset-top)",
        },
        ".safe-left": {
          paddingLeft: "env(safe-area-inset-left)",
        },
        ".safe-right": {
          paddingRight: "env(safe-area-inset-right)",
        },
        ".safe-bottom": {
          paddingBottom: "env(safe-area-inset-bottom)",
        },
        ".scrollbar-hidden": {
          "-ms-overflow-style": "none",
          "scrollbar-width": "none",
        },
        ".scrollbar-hidden::-webkit-scrollbar": {
          display: "none",
        },
      });

      // Font weight overrides for Nunito/Nunito Sans variable fonts
      addComponents({
        // Nunito (> 20px sizes)
        ".font-title0": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "800",
        },
        ".font-title1": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "800",
        },
        ".font-title2": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "800",
        },
        ".font-title3": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "800",
        },
        ".font-title4": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "800",
        },
        ".font-title5": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "700",
        },
        ".font-bodylarge": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "300",
        },
        ".font-introdesktop": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "500",
        },
        ".font-quote": {
          "font-family": "Nunito, sans-serif",
          "font-weight": "700",
        },
        // Nunito Sans (≤ 20px sizes)
        ".font-title6": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-title7": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-caption": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "500",
        },
        ".font-link": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "500",
        },
        ".font-subhead": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "600",
        },
        ".font-button": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-footnote": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "500",
        },
        ".font-intro": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "500",
        },
        ".font-label": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-body": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "300",
        },
        ".font-hint": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "300",
          "font-style": "italic",
        },
        ".font-tablehead": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-tablerow": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "400",
        },
        ".font-bold": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "700",
        },
        ".font-mono": {
          "font-family": "Nunito Sans, sans-serif",
          "font-weight": "300",
        },
      });
    }),
  ],
};
