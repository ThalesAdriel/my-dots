pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    PanelMessage {
        width: parent.width
        visible: InputConfig.lastError !== "" && !SettingsContext.searching
        warning: true
        text: InputConfig.lastError
    }

    Group {
        title: "Keyboard"

        FieldRow {
            label: "Layout"
            value: InputConfig.kbLayout
            placeholder: "br"
            onCommitted: text => {
                const cleaned = InputConfig.sanitizeKeymap(text, InputConfig.defaults.kb_layout);
                InputConfig.kbLayout = cleaned;
            }
        }

        FieldRow {
            label: "Variant"
            value: InputConfig.kbVariant
            placeholder: "abnt2"
            onCommitted: text => {
                InputConfig.kbVariant = InputConfig.sanitizeKeymap(text, "");
            }
        }

        ToggleRow {
            label: "NumLock on startup"
            checked: InputConfig.numlockByDefault
            onToggled: InputConfig.numlockByDefault = !InputConfig.numlockByDefault
        }

        SliderRow {
            label: "Repeat delay"
            value: InputConfig.repeatDelay
            minimum: 100
            maximum: 1000
            decimals: 0
            suffix: " ms"
            onAdjusted: newValue => InputConfig.repeatDelay = Math.round(newValue / 10) * 10
        }

        SliderRow {
            label: "Repeat rate"
            value: InputConfig.repeatRate
            minimum: 10
            maximum: 100
            decimals: 0
            suffix: "/s"
            onAdjusted: newValue => InputConfig.repeatRate = Math.round(newValue)
        }
    }

    Group {
        title: "Mouse"

        SliderRow {
            label: "Sensitivity"
            value: InputConfig.sensitivity
            minimum: -1.0
            maximum: 1.0
            decimals: 2
            onAdjusted: newValue => InputConfig.sensitivity = Math.round(newValue * 20) / 20
        }

        ChoiceRow {
            label: "Acceleration profile"
            current: InputConfig.accelProfile
            options: [
                {
                    label: "Flat",
                    value: "flat"
                },
                {
                    label: "Adaptive",
                    value: "adaptive"
                }
            ]
            onPicked: value => InputConfig.accelProfile = String(value)
        }
    }

    Group {
        title: "Touchpad"

        ToggleRow {
            label: "Natural scrolling"
            checked: InputConfig.touchpadNaturalScroll
            onToggled: InputConfig.touchpadNaturalScroll = !InputConfig.touchpadNaturalScroll
        }

        ToggleRow {
            label: "Disable while typing"
            checked: InputConfig.touchpadDisableWhileTyping
            onToggled: InputConfig.touchpadDisableWhileTyping = !InputConfig.touchpadDisableWhileTyping
        }

        ToggleRow {
            label: "Clickfinger behavior"
            checked: InputConfig.touchpadClickfingerBehavior
            onToggled: InputConfig.touchpadClickfingerBehavior = !InputConfig.touchpadClickfingerBehavior
        }

        SliderRow {
            label: "Scroll speed"
            value: InputConfig.touchpadScrollFactor
            minimum: 0.1
            maximum: 2.0
            decimals: 2
            suffix: "x"
            onAdjusted: newValue => InputConfig.touchpadScrollFactor = Math.round(newValue * 20) / 20
        }
    }

    ButtonRow {
        label: "Restore input defaults"
        onTriggered: InputConfig.restoreDefaults()
    }
}
