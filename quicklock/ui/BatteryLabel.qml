import Quickshell.Services.UPower
import qs.config
// O proprio diretorio, explicito: carregado por URL pelo Loader do StatusLine,
// este arquivo nao ganha a resolucao implicita de tipos irmaos, e TextLabel
// abaixo e' um deles.
import qs.ui

// The one file that needs Quickshell.Services.UPower, loaded rather than imported from a singleton so a build without it costs this label and nothing else. UPower says when the battery moved; the old service hunted for it under /sys/class/power_supply and read it back with three blocking file loads on the clock's minute tick.
TextLabel {
    id: root

    readonly property var device: UPower.displayDevice

    // The percentage is the second half of the test rather than trusting the laptop flag alone: a desktop's display device is ready and reports 0, so a machine with no battery still comes out empty handed while a real battery is not lost.
    readonly property bool present: !!root.device && root.device.ready === true && (root.device.isLaptopBattery === true || root.device.percentage > 0)

    readonly property int percent: root.present ? Math.round(root.device.percentage * 100) : 0

    readonly property bool charging: root.present && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.PendingCharge)

    visible: root.present
    font.pixelSize: Config.statusSize

    text: {
        if (!root.present)
            return "";
        return root.charging ? "(+) " + root.percent + "%" : root.percent + "% remaining";
    }
}
