/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Match the original HTML palette
        bg: "#111815",
        bg2: "#18231e",
        panel: "#202c26",
        panel2: "#24322b",
        panel3: "#1b2621",
        brand: "#467b69",
        brand2: "#3f6f5f",
        ok: "#7bc89a",
        warn: "#d8a64e",
        bad: "#d46a6a",
        info: "#9ecfbc",
        muted: "#c0cbc5",
        ring: "#3a5046"
      },
      fontFamily: {
        mono: [
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "Monaco",
          "Consolas",
          '"Liberation Mono"',
          '"Courier New"',
          "monospace"
        ]
      },
      boxShadow: {
        soft: "0 10px 24px rgba(0,0,0,.35)"
      }
    }
  },
  plugins: []
};
