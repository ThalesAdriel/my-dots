pragma Singleton

import Quickshell

Singleton {
    readonly property string volumeOff: ""
    readonly property string volumeLow: ""
    readonly property string volumeHigh: ""
    readonly property string microphone: ""
    readonly property string microphoneMuted: ""
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
    readonly property string brightness: ""
    readonly property string xmark: ""
    readonly property string check: ""
    readonly property string trash: ""
    readonly property string gear: ""
    readonly property string comment: ""
    readonly property string play: ""
    readonly property string pause: ""
    readonly property string next: ""
    readonly property string previous: ""
    readonly property string shuffle: ""
    readonly property string repeat: ""
    readonly property string calendar: ""

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
