pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Services.Pam
import qs.config
import qs.services

// One login at a time, through greetd, or through PAM in a preview.
Singleton {
    id: root

    property string user: Sessions.lastUser
    property string buffer: ""
    property string message: ""
    property int attempts: 0
    property bool failed: false
    property bool busy: false
    property bool launching: false

    // A second question from PAM, a one-time code say, asked in the password field.
    property string prompt: ""
    property bool answered: false

    // What PAM said went wrong, if it said.
    property string reason: ""

    readonly property int length: root.buffer.length
    readonly property string login: root.user.trim()

    signal rejected

    function answer(response) {
        if (Config.preview)
            pam.respond(response);
        else
            Greetd.respond(response);
    }

    function submit() {
        if (root.busy || root.launching)
            return;

        if (root.prompt !== "") {
            root.prompt = "";
            root.busy = true;
            root.answer(root.buffer);
            return;
        }

        if (root.login === "") {
            root.fail("Type your login first");
            return;
        }
        if (root.buffer.length === 0)
            return;

        root.failed = false;
        root.message = "";
        root.reason = "";
        root.answered = false;
        root.busy = true;

        if (Config.preview) {
            // Without root PAM checks no password but the caller's own.
            const self = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
            if (self !== "" && root.login !== self) {
                root.fail("A preview can only check " + self + "'s password");
                return;
            }
            pam.user = root.login;
            if (!pam.start())
                root.fail("Authentication unavailable");
            return;
        }

        // Before greetd is asked anything.
        if (!Sessions.session) {
            root.fail("No session to start");
            return;
        }

        // Left over from a session that never finished, which greetd would refuse a second one over.
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        Greetd.createSession(root.login);
    }

    function fail(text) {
        root.buffer = "";
        root.prompt = "";
        root.busy = false;
        root.attempts += 1;
        root.failed = true;
        root.message = text;
        root.rejected();
    }

    function question(text, responseRequired, isError) {
        if (responseRequired) {
            if (!root.answered) {
                root.answered = true;
                root.answer(root.buffer);
            } else {
                root.buffer = "";
                root.prompt = text;
                root.busy = false;
            }
        } else if (text.length > 0) {
            root.message = text;
            if (isError)
                root.reason = text;
        }
    }

    function succeed() {
        root.buffer = "";
        root.busy = false;
        root.failed = false;
        root.launching = true;
        Sessions.remember(root.login);
        if (Config.preview)
            root.message = (Sessions.session ? Sessions.session.name : "The session") + " would start now";
        launch.start();
    }

    function handleKey(event) {
        event.accepted = true;

        if (root.launching)
            return;

        CapsLock.observe(event);

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
            // The one way out of a preview from the keyboard.
            if (Config.preview && root.buffer.length === 0)
                Qt.quit();
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

    // The fade out gets its moment before greetd takes over the screen, or in a preview before it closes.
    Timer {
        id: launch

        interval: Config.preview ? 1400 : Config.animNormal
        onTriggered: {
            if (Config.preview)
                Qt.quit();
            else
                Greetd.launch(Sessions.session.command, Sessions.session.environment, true);
        }
    }

    Connections {
        target: Greetd
        enabled: !Config.preview

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.question(message, responseRequired, error);
        }

        function onAuthFailure(message) {
            root.fail(root.reason || "Authentication failed");
        }

        function onError(error) {
            root.launching = false;
            root.fail(error);
        }

        function onReadyToLaunch() {
            root.succeed();
        }
    }

    PamContext {
        id: pam

        config: "login"

        onPamMessage: root.question(pam.message, pam.responseRequired, pam.messageIsError)

        onCompleted: result => {
            if (result === PamResult.Success)
                root.succeed();
            else if (result === PamResult.MaxTries)
                root.fail("Too many attempts");
            else if (result === PamResult.Error)
                root.fail("Authentication error");
            else
                root.fail(root.reason || "Authentication failed");
        }
    }
}
