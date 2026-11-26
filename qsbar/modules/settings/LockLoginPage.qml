pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: lockLoginPage

    property string tab: "lock"

    spacing: 18

    SubTabs {
        tabs: [
            {
                value: "lock",
                label: "Lock screen"
            },
            {
                value: "login",
                label: "Login screen"
            }
        ]
        current: lockLoginPage.tab
        onPicked: value => lockLoginPage.tab = value
    }

    LockPage {
        id: lockTab

        readonly property string searchTitle: "Lock screen quicklock"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(lockTab.children)

        width: parent.width
        visible: SettingsContext.searching ? lockTab.hit : lockLoginPage.tab === "lock"
    }

    GreeterPage {
        id: loginTab

        readonly property string searchTitle: "Login screen greeter quickgreet"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(loginTab.children)

        width: parent.width
        visible: SettingsContext.searching ? loginTab.hit : lockLoginPage.tab === "login"
    }
}
