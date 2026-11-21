pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    // Read on every visit, since installing an application or changing a default elsewhere does not tell the shell.
    Component.onCompleted: DefaultApps.refresh()

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
