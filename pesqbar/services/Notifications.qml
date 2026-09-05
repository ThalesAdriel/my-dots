pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/services"

Singleton {
    id: root

    // Toasts on screen at once. Anything past this still lands in the control
    // center, it just does not pile up down the side of the display.
    readonly property int maxPopups: 4

    // What a screenshot notification calls itself. Anything with one of these in
    // its name or summary and a real file behind it gets the editor button.
    readonly property var screenshotWords: ["screenshot", "screen shot", "screencapture", "printscreen", "print screen", "captura", "grim", "hyprshot", "flameshot", "swappy", "satty", "shotman", "spectacle"]
    readonly property string screenshotEditor: "satty"

    readonly property int lowTimeout: 5000
    readonly property int normalTimeout: 10000
    readonly property int minimumTimeout: 1500
    readonly property int maximumTimeout: 120000

    property bool doNotDisturb: false
    property var popups: []
    property var arrivals: ({})

    readonly property var tracked: server.trackedNotifications ? server.trackedNotifications.values : []
    readonly property var history: root.tracked.slice().reverse()
    readonly property int count: root.tracked.length
    readonly property date now: clock.date

    onDoNotDisturbChanged: {
        if (root.doNotDisturb)
            root.clearPopups();
    }

    // expireTimeout arrives straight off the bus in milliseconds: -1 asks the
    // server to pick, and 0 means the notification never times out on its own.
    // Critical is held the same way, which is what swaync's timeout-critical = 0
    // did. A returned 0 means "no timer".
    function popupTimeout(notification: var): int {
        if (!notification)
            return 0;

        const requested = notification.expireTimeout;
        if (requested === 0)
            return 0;
        if (requested > 0)
            return Math.min(Math.max(requested, root.minimumTimeout), root.maximumTimeout);
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        if (notification.urgency === NotificationUrgency.Low)
            return root.lowTimeout;
        return root.normalTimeout;
    }

    function shouldPopup(): bool {
        // The control center lists everything already, so there is nothing to
        // gain from toasting over the top of it.
        return !root.doNotDisturb && !UiState.controlCenterOpen;
    }

    function pushPopup(notification: var): void {
        if (!notification || root.popups.indexOf(notification) !== -1)
            return;

        const next = root.popups.slice();
        next.push(notification);
        root.popups = next.length > root.maxPopups ? next.slice(next.length - root.maxPopups) : next;
    }

    function removePopup(notification: var): void {
        if (root.popups.indexOf(notification) === -1)
            return;
        root.popups = root.popups.filter(entry => entry !== notification);
    }

    function clearPopups(): void {
        if (root.popups.length > 0)
            root.popups = [];
    }

    // The toast ran out on its own. Transient notifications asked not to be kept
    // in a notification area, so they leave with it instead of filling the list.
    function releasePopup(notification: var): void {
        root.removePopup(notification);
        if (notification && notification.transient)
            notification.expire();
    }

    // The user closed the toast: the app should hear that it was dismissed
    // rather than that it timed out.
    function close(notification: var): void {
        root.removePopup(notification);
        if (notification)
            notification.dismiss();
    }

    function markArrival(notification: var): void {
        if (!notification)
            return;

        const times = Object.assign({}, root.arrivals);
        times[notification.id] = Date.now();
        root.arrivals = times;
    }

    // An app replacing a notification reuses the same object and the same id, so
    // the server never emits `notification` a second time. The text changing is
    // the only sign there is something new to show.
    function refresh(notification: var): void {
        root.markArrival(notification);
        if (root.shouldPopup())
            root.pushPopup(notification);
    }

    // Only the arrival time. A toast still on screen owns its own removal so it
    // can animate out first, and the lock it holds keeps the notification alive
    // until it has.
    function forget(notification: var): void {
        if (!notification)
            return;

        const times = Object.assign({}, root.arrivals);
        delete times[notification.id];
        root.arrivals = times;
    }

    function dismissAll(): void {
        for (const item of root.tracked.slice())
            item.dismiss();
    }

    function ageLabel(notification: var): string {
        if (!notification)
            return "";

        const stamp = root.arrivals[notification.id];
        if (stamp === undefined)
            return "now";

        const minutes = Math.floor((root.now.getTime() - stamp) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return minutes + " min";

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + " h";
        return Math.floor(hours / 24) + " d";
    }

    function imageSource(notification: var): string {
        return notification && notification.image !== "" ? notification.image : "";
    }

    function appIconSource(notification: var): string {
        if (!notification || notification.appIcon === "")
            return "";

        // Screenshot tools hand the saved file to notify-send with -i, so the app
        // icon is sometimes a path rather than the name of a theme icon.
        if (notification.appIcon.startsWith("/") || notification.appIcon.startsWith("file://"))
            return notification.appIcon;

        return Quickshell.iconPath(notification.appIcon, true);
    }

    function looksLikeScreenshot(notification: var): bool {
        if (!notification)
            return false;

        const haystack = (notification.appName + " " + notification.summary + " " + notification.desktopEntry).toLowerCase();
        return root.screenshotWords.some(word => haystack.indexOf(word) !== -1);
    }

    // The file a screenshot notification is pointing at, or "" if there is none
    // to point at. The tools all report it differently: grimblast and hyprshot
    // pass it to notify-send as the icon and name it again in the body, others
    // set the image-path hint, and some only ever hand over raw image data that
    // never reaches the disk and so cannot be reopened by anything.
    function screenshotPath(notification: var): string {
        if (!root.looksLikeScreenshot(notification))
            return "";

        const candidates = [notification.image, notification.appIcon, notification.body];
        for (const candidate of candidates) {
            if (!candidate)
                continue;

            const match = String(candidate).match(/(?:file:\/\/)?(\/[^\s"'<>]+\.(?:png|jpg|jpeg|webp))/i);
            if (match)
                return match[1];
        }

        return "";
    }

    function editScreenshot(notification: var): void {
        const path = root.screenshotPath(notification);
        if (path === "")
            return;

        // Satty disables saving entirely unless it is told where to save, so it
        // gets a name next to the original rather than an editor whose save
        // button does nothing. The timestamp is built here instead of with
        // Satty's own format specifiers, which only newer versions understand.
        const directory = path.slice(0, path.lastIndexOf("/") + 1);
        const output = directory + "satty-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png";

        console.log("pesqBar: opening", path, "in", root.screenshotEditor);

        // Through sh rather than straight at the binary: execDetached throws away
        // everything QProcess says about a failed start, so an editor that is not
        // installed fails without a word. This way "satty: not found" lands in the
        // shell's log. Paths go in as arguments, so spaces in them are fine.
        Quickshell.execDetached(["sh", "-c", 'exec "$0" --filename "$1" --output-filename "$2"', root.screenshotEditor, path, output]);
    }

    // Markup is advertised as supported, so bodies come in as a mix of real
    // markup and plain text carrying bare & and < characters. Either one makes
    // StyledText drop the rest of the body, so keep the handful of tags the spec
    // allows and turn everything else into literal text.
    function formatBody(text: string): string {
        if (!text)
            return "";

        return text.replace(/<img[^>]*>/gi, "").replace(/&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)/g, "&amp;").replace(/<(?!\/?(?:b|i|u|a|br)[\s\/>])/g, "&lt;");
    }

    SystemClock {
        id: clock

        // Only the age labels read this, and they are only on screen when there
        // is something in the list.
        enabled: root.count > 0
        precision: SystemClock.Minutes
    }

    // One watcher per tracked notification. Closing has to clean up after itself
    // or the arrival times grow for the life of the session, and a replacement
    // has to be noticed here because the server signal never fires twice.
    Instantiator {
        model: ScriptModel {
            values: root.tracked
        }

        delegate: QtObject {
            id: entry

            required property var modelData

            readonly property Connections watcher: Connections {
                target: entry.modelData

                function onClosed(): void {
                    root.forget(entry.modelData);
                }

                function onSummaryChanged(): void {
                    root.refresh(entry.modelData);
                }

                function onBodyChanged(): void {
                    root.refresh(entry.modelData);
                }
            }
        }
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            root.markArrival(notification);

            if (root.shouldPopup())
                root.pushPopup(notification);
        }
    }
}
