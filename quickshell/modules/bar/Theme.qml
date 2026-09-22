pragma Singleton
import QtQuick

QtObject {
    // Icons & Typography
    readonly property color iconColor: "#ffffff"     // Pure White
    readonly property color textColor: "#ffffff"     // Pure White
    readonly property color subtextColor: "#a6adc8"  // Muted Slate / Lavender Gray

    // Brand & Accent
    readonly property color accent: "#89b4fa"        // Cornflower Pastel Blue

    // Surfaces & Backgrounds
    readonly property color background: "#181825"    // Deep Dark Charcoal Violet (Mantle)
    readonly property color windowSurface: "#1e1e2e" // Deep Blue-Toned Charcoal (Base)
    readonly property color border: "#313244"        // Muted Slate Dark Gray (Surface 0)
}
