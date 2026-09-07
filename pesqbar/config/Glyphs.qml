pragma Singleton

import Quickshell

Singleton {
    readonly property string volumeOff: ""
    readonly property string volumeLow: ""
    readonly property string volumeHigh: ""
    readonly property string microphone: ""
    readonly property string microphoneMuted: ""

    // The backlight, on the control center slider and on the notification the
    // XF86MonBrightness keybinds send.
    readonly property string sun: ""

    readonly property string bell: ""
    readonly property string bellOff: ""
    readonly property string bellNerd: "󱨇"
    readonly property string bellOffNerd: "󰂛"
    readonly property string idleBlocked: ""
    readonly property string idleAllowed: ""
    readonly property string expand: ""
    readonly property string collapse: ""
    readonly property string angleLeft: ""
    readonly property string angleRight: ""
    readonly property string angleDown: ""
    readonly property string lock: ""
    readonly property string restart: ""
    readonly property string softRestart: ""
    readonly property string power: ""
    readonly property string xmark: ""
    readonly property string check: ""
    readonly property string gear: ""
    readonly property string comment: ""
    readonly property string play: ""
    readonly property string pause: ""
    readonly property string next: ""
    readonly property string previous: ""
    readonly property string shuffle: ""
    readonly property string repeat: ""

    // Network. One wifi glyph for every strength: the graded wifi-weak and
    // wifi-fair only exist in some builds of the free set, and a missing one
    // renders as a box rather than as a weaker signal. Strength is drawn as the
    // same hairline the volume module uses instead.
    readonly property string wifi: ""
    readonly property string networkWired: ""
    readonly property string rotate: ""
    readonly property string eye: ""
    readonly property string eyeSlash: ""

    // Font Awesome Free has no bluetooth glyph in Solid; it is in Brands, which
    // is a separate family. Drawn with Theme.brandFamily for that reason.
    readonly property string bluetooth: ""

    // Battery, from empty to full, with the badge that goes over it.
    readonly property var batteryLevels: ["", "", "", "", ""]
    readonly property string bolt: ""
    readonly property string plug: ""
    readonly property string triangleExclamation: ""

    // Power profiles.
    readonly property string gaugeHigh: ""
    readonly property string scaleBalanced: ""
    readonly property string leaf: ""

    // The screen capture dot.
    readonly property string circle: ""

    readonly property var workspaceNumerals: ({
        "1": "一",
        "2": "二",
        "3": "三",
        "4": "四",
        "5": "五",
        "6": "六",
        "7": "七",
        "8": "八",
        "9": "九",
        "10": "十"
    })

    function workspaceLabel(workspaceId: int): string {
        const mapped = workspaceNumerals[String(workspaceId)];
        return mapped !== undefined ? mapped : String(workspaceId);
    }
}
