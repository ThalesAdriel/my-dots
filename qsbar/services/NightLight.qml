pragma Singleton

import QtQuick
import Quickshell
import "root:/config"

// Blue-light filter driven by hyprsunset, debounced and with zero polling.
Singleton {
    id: root

    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6500

    readonly property bool enabled: Settings.nightLightEnabled
    readonly property int temperature: root.clampTemperature(Settings.nightLightTemperature)

    function clampTemperature(value: real): int {
        return Math.min(Math.max(Math.round(value), root.minTemperature), root.maxTemperature);
    }

    function setEnabled(value: bool): void {
        if (Settings.nightLightEnabled === value)
            return;

        Settings.nightLightEnabled = value;
        applyTimer.restart();
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }

    function setTemperature(value: real): void {
        const clamped = root.clampTemperature(value);
        if (Settings.nightLightTemperature === clamped)
            return;

        Settings.nightLightTemperature = clamped;
        if (root.enabled)
            applyTimer.restart();
    }

    function apply(): void {
        if (root.enabled)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
        else
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    }

    onEnabledChanged: applyTimer.restart()

    onTemperatureChanged: {
        if (root.enabled)
            applyTimer.restart();
    }

    Timer {
        id: applyTimer

        interval: 150
        repeat: false
        onTriggered: root.apply()
    }
}
