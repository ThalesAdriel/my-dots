pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property int barHeight: Settings.barHeight
    readonly property int radius: Math.round(Settings.panelRadius / 2)
    readonly property bool squareCorners: Settings.panelRadius <= 0

    function pill(size: real): real {
        return squareCorners ? 0 : size / 2;
    }

    readonly property int hoverRadius: Settings.hoverRadius
    readonly property int moduleSpacing: Settings.moduleSpacing
    readonly property int groupMargin: 8

    readonly property color barBaseColor: Settings.barColor
    readonly property color barBackground: Qt.rgba(barBaseColor.r, barBaseColor.g, barBaseColor.b, Settings.barOpacity)
    readonly property color barBorder: Qt.rgba(1, 1, 1, 0.2)

    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.55)
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.28)

    readonly property color fillHover: Qt.rgba(0.784, 0.784, 0.784, Settings.hoverOpacity)
    readonly property color fillPressed: Qt.rgba(0.784, 0.784, 0.784, Math.min(Settings.hoverOpacity + 0.15, 1))
    readonly property color fillTrack: Qt.rgba(1, 1, 1, 0.12)
    readonly property color skeletonFill: Qt.rgba(1, 1, 1, 0.09)

    readonly property color accent: Settings.accentColor
    readonly property color urgent: "#e01b24"

    readonly property color surfaceBase: Settings.surfaceColor
    readonly property color popupTint: Qt.lighter(surfaceBase, 1.35)
    readonly property color popupBackground: Qt.rgba(popupTint.r, popupTint.g, popupTint.b, Settings.panelOpacity)
    readonly property color popupBorder: Qt.rgba(1, 1, 1, 0.18)
    readonly property int panelBorderWidth: Settings.showPanelBorders ? 1 : 0

    readonly property color cardTint: Qt.lighter(surfaceBase, 1.55)
    readonly property color cardBackground: Qt.rgba(cardTint.r, cardTint.g, cardTint.b, Math.min(Settings.panelOpacity + 0.06, 1))

    // The settings sheet covers the control center rather than blending into it,
    // so it is the one surface that ignores the panel opacity: reading a wall of
    // sliders through the wallpaper is not worth the look.
    readonly property color settingsBackground: Qt.rgba(surfaceBase.r, surfaceBase.g, surfaceBase.b, 1)
    readonly property color settingsCard: Qt.rgba(cardTint.r, cardTint.g, cardTint.b, 1)
    readonly property string barLayerNamespace: {
        if (Settings.panelBlur)
            return "pesqBar-blur-popups";
        return Settings.barBlur ? "pesqBar-blur" : "pesqBar";
    }
    readonly property string panelLayerNamespace: Settings.panelBlur ? "pesqBar-blur" : "pesqBar"

    // The overview makes the settings sheet's argument and then some. A window
    // preview is a capture of a surface that carries its own alpha, and drawing
    // it over anything translucent lets the compositor blur the desktop up
    // through it: a dark window comes out washed to white. Everything under a
    // capture is opaque, and the layer it all sits on is not a blurred one.
    readonly property color overviewBackground: Qt.rgba(surfaceBase.r, surfaceBase.g, surfaceBase.b, 1)
    readonly property color overviewCard: Qt.rgba(cardTint.r, cardTint.g, cardTint.b, 1)
    readonly property string overviewLayerNamespace: "pesqBar"
    readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.18)
    readonly property int cardRadius: Settings.panelRadius


    // Enumerating every installed font is not cheap, and there are seven lists
    // below asking the same question. Asked once here instead of once each.
    readonly property var installedFamilies: Qt.fontFamilies()

    function resolveFamily(candidates: var): string {
        for (const candidate of candidates) {
            if (installedFamilies.indexOf(candidate) !== -1)
                return candidate;
        }
        return "";
    }

    readonly property string sansFamily: resolveFamily(["Segoe UI", "Ubuntu", "Cantarell", "Noto Sans", "DejaVu Sans"])
    readonly property string monoFamily: resolveFamily(["JetBrainsMono Nerd Font", "JetBrains Mono", "Ubuntu Mono", "Noto Sans Mono", "DejaVu Sans Mono"])
    readonly property string iconFamily: resolveFamily(["Font Awesome 7 Free Solid", "Font Awesome 6 Free Solid", "Font Awesome 7 Free", "Font Awesome 6 Free", "Font Awesome 5 Free", "Symbols Nerd Font", "JetBrainsMono Nerd Font"])
    readonly property string nerdFamily: resolveFamily(["Symbols Nerd Font", "JetBrainsMono Nerd Font", "NotoSans Nerd Font"])

    // Font Awesome Free splits Brands off into its own family, and the bluetooth
    // glyph only exists there. Nothing else in the shell needs it.
    readonly property string brandFamily: resolveFamily(["Font Awesome 7 Brands Regular", "Font Awesome 7 Brands", "Font Awesome 6 Brands Regular", "Font Awesome 6 Brands", "Font Awesome 5 Brands Regular", "Font Awesome 5 Brands", "Symbols Nerd Font"])
    readonly property string glyphFamily: resolveFamily(["Noto Sans CJK JP", "Noto Sans CJK SC", "Source Han Sans", "Noto Serif CJK JP"])

    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 11
    readonly property int fontWeightNormal: Font.DemiBold
    readonly property int fontWeightStrong: Font.Bold
    readonly property int iconSize: Settings.iconSize

    // The breathing room around every bar icon: the padding inside a bar button
    // and the slot each icon sits in. One slider drives both, so turning it down
    // pulls the whole icon side of the bar together.
    readonly property int iconPadding: Settings.iconPadding
    readonly property int iconSlot: Settings.iconSize + Settings.iconPadding + 2

    readonly property int glyphSize: Settings.iconSize + 1

    readonly property int durationFast: 120
    readonly property int durationBase: 260
    readonly property int durationSlow: 420
    readonly property int durationDrawer: 600

    readonly property var easingCurve: [0.165, 0.84, 0.44, 1.0, 1.0, 1.0]
}
