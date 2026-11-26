pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: appsPage

    property string tab: "defaults"

    spacing: 18

    // Read on every visit, since installing an application or changing a default elsewhere does not tell the shell.
    Component.onCompleted: DefaultApps.refresh()

    SubTabs {
        tabs: [
            {
                value: "defaults",
                label: "Default apps"
            },
            {
                value: "startup",
                label: "Startup apps"
            }
        ]
        current: appsPage.tab
        onPicked: value => appsPage.tab = value
    }

    Column {
        id: defaultsTab

        readonly property string searchTitle: "Default applications"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(defaultsTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? defaultsTab.hit : appsPage.tab === "defaults"

        PanelMessage {
            width: parent.width
            visible: DefaultApps.lastError !== "" && !SettingsContext.searching
            warning: true
            text: DefaultApps.lastError
        }

        Group {
            title: "Default applications"

            Repeater {
                model: DefaultApps.categories

                delegate: PickerRow {
                    required property var modelData

                    label: modelData.label
                    options: DefaultApps.candidates(modelData.key)
                    current: DefaultApps.current[modelData.key] || ""
                    labelOf: id => DefaultApps.nameOf(id)
                    applies: DefaultApps.available
                    onPicked: value => DefaultApps.set(modelData.key, value)
                }
            }
        }
    }

    StartupPage {
        id: startupTab

        readonly property string searchTitle: "Startup apps autostart"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(startupTab.children)

        width: parent.width
        visible: SettingsContext.searching ? startupTab.hit : appsPage.tab === "startup"
    }
}
