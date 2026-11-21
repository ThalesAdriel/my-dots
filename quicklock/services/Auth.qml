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
    property string prompt: ""
    property bool answered: false

    readonly property bool busy: pam.active && root.prompt === ""
    readonly property int length: root.buffer.length

    signal activity
    signal rejected
    signal unlocked

    readonly property string failText: "<i>" + root.sanitize(root.message) + " <b>(" + root.attempts + ")</b></i>"

    function sanitize(value) {
        return value ? String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") : "";
    }

    function fail(text) {
        root.buffer = "";
        root.prompt = "";
        root.answered = false;
        root.attempts += 1;
        root.failed = true;
        root.message = text;
        root.rejected();
    }

    function submit() {
        if (root.busy || root.unlocking)
            return;

        if (root.prompt !== "") {
            if (!pam.active) {
                root.fail("Authentication session ended");
                return;
            }
            root.prompt = "";
            pam.respond(root.buffer);
            return;
        }

        if (root.buffer.length === 0)
            return;

        root.failed = false;
        root.message = "";
        root.answered = false;

        if (!pam.start())
            root.fail("Authentication unavailable");
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
            root.submit();
            return;
        case Qt.Key_Backspace:
            root.buffer = (event.modifiers & Qt.ControlModifier) ? "" : root.buffer.slice(0, -1);
            return;
        case Qt.Key_Escape:
            if (root.buffer.length === 0 && root.prompt !== "") {
                root.prompt = "";
                root.answered = false;
                if (pam.active)
                    pam.abort();
                return;
            }
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

        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;

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
            if (pam.responseRequired) {
                if (!root.answered) {
                    root.answered = true;
                    pam.respond(root.buffer);
                } else {
                    root.buffer = "";
                    root.prompt = (pam.message && pam.message.trim().length > 0) ? pam.message.trim() : "Response";
                }
            } else if (pam.messageIsError && pam.message.length > 0) {
                root.message = pam.message;
            }
        }

        onError: error => {
            root.fail(error === PamError.StartFailed ? "Authentication unavailable" : "Authentication error");
        }

        onCompleted: result => {
            root.buffer = "";
            root.prompt = "";
            root.answered = false;

            if (result === PamResult.Success) {
                root.failed = false;
                root.unlocking = true;
                root.unlocked();
                return;
            }

            let text = root.message;
            if (result === PamResult.MaxTries)
                text = "Too many attempts";
            else if (result === PamResult.Error)
                text = "Authentication error";
            else if (text.length === 0)
                text = Config.failPrefix;

            root.fail(text);
        }
    }
}
