pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.services
import qs.config

Singleton {
    id: root

    property string buffer: ""
    property string message: ""
    property int attempts: 0
    property bool failed: false
    property bool unlocking: false

    readonly property bool busy: pam.active
    readonly property int length: root.buffer.length

    signal activity
    signal rejected
    signal unlocked

    readonly property string failText: "<i>" + root.sanitize(root.message) + " <b>(" + root.attempts + ")</b></i>"

    function sanitize(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function submit() {
        if (root.busy || root.unlocking || root.buffer.length === 0)
            return;

        root.failed = false;
        root.message = "";

        if (!pam.start()) {
            root.buffer = "";
            root.attempts += 1;
            root.failed = true;
            root.message = "Authentication unavailable";
            root.rejected();
        }
    }

    function handleKey(event) {
        event.accepted = true;

        if (root.unlocking)
            return;

        CapsLock.observe(event);
        root.activity();

        if (root.busy)
            return;

        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_KP_Enter:
            root.submit();
            return;
        case Qt.Key_Backspace:
            root.buffer = (event.modifiers & Qt.ControlModifier) ? "" : root.buffer.slice(0, -1);
            return;
        case Qt.Key_Escape:
            root.buffer = "";
            return;
        case Qt.Key_U:
        case Qt.Key_W:
            if (event.modifiers & Qt.ControlModifier) {
                root.buffer = "";
                return;
            }
            break;
        }

        const t = event.text;
        if (t.length === 0)
            return;

        const code = t.charCodeAt(0);
        if (code < 0x20 || code === 0x7f)
            return;

        root.failed = false;
        root.buffer += t;
    }

    PamContext {
        id: pam

        config: Config.pamConfig

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.buffer);
            else if (pam.messageIsError && pam.message.length > 0)
                root.message = pam.message;
        }

        onCompleted: result => {
            root.buffer = "";

            if (result === PamResult.Success) {
                root.failed = false;
                root.unlocking = true;
                root.unlocked();
                return;
            }

            root.attempts += 1;
            root.failed = true;

            if (result === PamResult.MaxTries)
                root.message = "Too many attempts";
            else if (result === PamResult.Error)
                root.message = "Authentication error";
            else if (root.message.length === 0)
                root.message = Config.failPrefix;

            root.rejected();
        }
    }
}
