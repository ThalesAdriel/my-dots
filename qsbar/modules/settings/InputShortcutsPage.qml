pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: inputShortcutsPage

    property string tab: "input"

    spacing: 18

    SubTabs {
        tabs: [
            {
                value: "input",
                label: "Input devices"
            },
            {
                value: "keybinds",
                label: "Keybinds"
            }
        ]
        current: inputShortcutsPage.tab
        onPicked: value => inputShortcutsPage.tab = value
    }

    InputPage {
        id: inputTab

        readonly property string searchTitle: "Input keyboard mouse touchpad"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(inputTab.children)

        width: parent.width
        visible: SettingsContext.searching ? inputTab.hit : inputShortcutsPage.tab === "input"
    }

    KeybindsPage {
        id: keybindsTab

        readonly property string searchTitle: "Keybinds shortcuts"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(keybindsTab.children)

        width: parent.width
        visible: SettingsContext.searching ? keybindsTab.hit : inputShortcutsPage.tab === "keybinds"
    }
}
