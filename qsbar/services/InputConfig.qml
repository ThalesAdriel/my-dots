pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland input settings persisted to hypr/hyprland/input.lua and applied live via hyprctl.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/input.lua"

    readonly property var defaults: ({
        kb_layout: "br",
        kb_variant: "abnt2",
        numlock_by_default: true,
        repeat_delay: 250,
        repeat_rate: 35,
        sensitivity: 0.3,
        accel_profile: "flat",
        touchpad: {
            natural_scroll: true,
            disable_while_typing: true,
            clickfinger_behavior: true,
            scroll_factor: 0.5
        }
    })

    property string kbLayout: root.defaults.kb_layout
    property string kbVariant: root.defaults.kb_variant
    property bool numlockByDefault: root.defaults.numlock_by_default
    property int repeatDelay: root.defaults.repeat_delay
    property int repeatRate: root.defaults.repeat_rate
    property real sensitivity: root.defaults.sensitivity
    property string accelProfile: root.defaults.accel_profile
    property bool touchpadNaturalScroll: root.defaults.touchpad.natural_scroll
    property bool touchpadDisableWhileTyping: root.defaults.touchpad.disable_while_typing
    property bool touchpadClickfingerBehavior: root.defaults.touchpad.clickfinger_behavior
    property real touchpadScrollFactor: root.defaults.touchpad.scroll_factor

    property bool loaded: false
    property string lastError: ""

    property bool _syncing: false
    property string _lastWritten: ""

    function sanitizeKeymap(value: var, fallback: string): string {
        const cleaned = String(value === undefined || value === null ? "" : value).trim().replace(/[^A-Za-z0-9_,-]/g, "");
        return cleaned !== "" ? cleaned : fallback;
    }

    function clampInt(value: var, minVal: int, maxVal: int, fallback: int): int {
        const n = Number(value);
        if (!isFinite(n))
            return fallback;
        return Math.max(minVal, Math.min(maxVal, Math.round(n)));
    }

    function clampReal(value: var, minVal: real, maxVal: real, fallback: real, decimals: int): real {
        const n = Number(value);
        if (!isFinite(n))
            return fallback;
        const clamped = Math.max(minVal, Math.min(maxVal, n));
        const factor = Math.pow(10, decimals);
        return Math.round(clamped * factor) / factor;
    }

    function sanitizeAccel(value: var): string {
        return value === "adaptive" ? "adaptive" : "flat";
    }

    function escapeLua(value: string): string {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\r?\n/g, "");
    }

    function currentState(): var {
        return {
            kb_layout: root.sanitizeKeymap(root.kbLayout, root.defaults.kb_layout),
            kb_variant: root.sanitizeKeymap(root.kbVariant, ""),
            numlock_by_default: root.numlockByDefault === true,
            repeat_delay: root.clampInt(root.repeatDelay, 100, 1000, root.defaults.repeat_delay),
            repeat_rate: root.clampInt(root.repeatRate, 10, 100, root.defaults.repeat_rate),
            sensitivity: root.clampReal(root.sensitivity, -1.0, 1.0, root.defaults.sensitivity, 2),
            accel_profile: root.sanitizeAccel(root.accelProfile),
            touchpad: {
                natural_scroll: root.touchpadNaturalScroll === true,
                disable_while_typing: root.touchpadDisableWhileTyping === true,
                clickfinger_behavior: root.touchpadClickfingerBehavior === true,
                scroll_factor: root.clampReal(root.touchpadScrollFactor, 0.1, 2.0, root.defaults.touchpad.scroll_factor, 2)
            }
        };
    }

    function luaBodyFor(state: var): string {
        const tp = state.touchpad;
        return [
            "hl.config({",
            "\tinput = {",
            '\t\tkb_layout = "' + root.escapeLua(state.kb_layout) + '",',
            '\t\tkb_variant = "' + root.escapeLua(state.kb_variant) + '",',
            "\t\tnumlock_by_default = " + (state.numlock_by_default ? "true" : "false") + ",",
            "\t\trepeat_delay = " + state.repeat_delay + ",",
            "\t\trepeat_rate = " + state.repeat_rate + ",",
            "\t\tsensitivity = " + state.sensitivity + ",",
            '\t\taccel_profile = "' + root.escapeLua(state.accel_profile) + '",',
            "\t\ttouchpad = {",
            "\t\t\tnatural_scroll = " + (tp.natural_scroll ? "true" : "false") + ",",
            "\t\t\tdisable_while_typing = " + (tp.disable_while_typing ? "true" : "false") + ",",
            "\t\t\tclickfinger_behavior = " + (tp.clickfinger_behavior ? "true" : "false") + ",",
            "\t\t\tscroll_factor = " + tp.scroll_factor + ",",
            "\t\t},",
            "\t},",
            "})"
        ].join("\n");
    }

    function batchCommandFor(state: var): string {
        const tp = state.touchpad;
        const variant = state.kb_variant !== "" ? state.kb_variant : "EMPTY";
        return [
            "keyword input:kb_layout " + state.kb_layout,
            "keyword input:kb_variant " + variant,
            "keyword input:numlock_by_default " + (state.numlock_by_default ? "true" : "false"),
            "keyword input:repeat_delay " + state.repeat_delay,
            "keyword input:repeat_rate " + state.repeat_rate,
            "keyword input:sensitivity " + state.sensitivity,
            "keyword input:accel_profile " + state.accel_profile,
            "keyword input:touchpad:natural_scroll " + (tp.natural_scroll ? "true" : "false"),
            "keyword input:touchpad:disable_while_typing " + (tp.disable_while_typing ? "true" : "false"),
            "keyword input:touchpad:clickfinger_behavior " + (tp.clickfinger_behavior ? "true" : "false"),
            "keyword input:touchpad:scroll_factor " + tp.scroll_factor
        ].join(" ; ");
    }

    function serialise(state: var): string {
        return [
            "-- Managed by qsbar Settings -> Input.",
            "-- qsbar-input: " + JSON.stringify(state),
            "",
            root.luaBodyFor(state)
        ].join("\n") + "\n";
    }

    function parse(text: string): var {
        const match = /^--\s*qsbar-input:\s*(\{.*\})\s*$/m.exec(text || "");
        if (!match)
            return null;
        try {
            const parsed = JSON.parse(match[1]);
            if (!parsed || typeof parsed !== "object")
                return null;
            return parsed;
        } catch (e) {
            return null;
        }
    }

    function applyState(parsed: var): void {
        const d = root.defaults;
        const src = parsed || {};
        const tp = (src.touchpad && typeof src.touchpad === "object") ? src.touchpad : {};

        root._syncing = true;
        root.kbLayout = root.sanitizeKeymap(src.kb_layout, d.kb_layout);
        root.kbVariant = src.kb_variant !== undefined ? root.sanitizeKeymap(src.kb_variant, "") : d.kb_variant;
        root.numlockByDefault = typeof src.numlock_by_default === "boolean" ? src.numlock_by_default : d.numlock_by_default;
        root.repeatDelay = root.clampInt(src.repeat_delay, 100, 1000, d.repeat_delay);
        root.repeatRate = root.clampInt(src.repeat_rate, 10, 100, d.repeat_rate);
        root.sensitivity = root.clampReal(src.sensitivity, -1.0, 1.0, d.sensitivity, 2);
        root.accelProfile = src.accel_profile !== undefined ? root.sanitizeAccel(src.accel_profile) : d.accel_profile;
        root.touchpadNaturalScroll = typeof tp.natural_scroll === "boolean" ? tp.natural_scroll : d.touchpad.natural_scroll;
        root.touchpadDisableWhileTyping = typeof tp.disable_while_typing === "boolean" ? tp.disable_while_typing : d.touchpad.disable_while_typing;
        root.touchpadClickfingerBehavior = typeof tp.clickfinger_behavior === "boolean" ? tp.clickfinger_behavior : d.touchpad.clickfinger_behavior;
        root.touchpadScrollFactor = root.clampReal(tp.scroll_factor, 0.1, 2.0, d.touchpad.scroll_factor, 2);
        root._syncing = false;
    }

    function scheduleSave(): void {
        if (!root.loaded || root._syncing)
            return;
        saveTimer.restart();
    }

    function persistAndApply(): void {
        const state = root.currentState();
        const text = root.serialise(state);
        root.lastError = "";
        root._lastWritten = text;
        file.setText(text);

        const luaBody = root.luaBodyFor(state);
        Quickshell.execDetached(
            Hyprland.usingLua
                ? ["hyprctl", "eval", luaBody]
                : ["hyprctl", "--batch", root.batchCommandFor(state)]
        );
    }

    function restoreDefaults(): void {
        root.applyState(root.defaults);
        if (root.loaded)
            saveTimer.restart();
    }

    onKbLayoutChanged: root.scheduleSave()
    onKbVariantChanged: root.scheduleSave()
    onNumlockByDefaultChanged: root.scheduleSave()
    onRepeatDelayChanged: root.scheduleSave()
    onRepeatRateChanged: root.scheduleSave()
    onSensitivityChanged: root.scheduleSave()
    onAccelProfileChanged: root.scheduleSave()
    onTouchpadNaturalScrollChanged: root.scheduleSave()
    onTouchpadDisableWhileTypingChanged: root.scheduleSave()
    onTouchpadClickfingerBehaviorChanged: root.scheduleSave()
    onTouchpadScrollFactorChanged: root.scheduleSave()

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: root.persistAndApply()
    }

    FileView {
        id: file

        path: root.path
        blockLoading: true
        atomicWrites: false
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()

        onLoaded: {
            const text = file.text();
            if (text === root._lastWritten && root.loaded)
                return;
            root.applyState(root.parse(text));
            root.loaded = true;
        }

        onLoadFailed: {
            root.applyState(root.defaults);
            root.loaded = true;
        }
    }
}
