pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/config"
import "root:/services"

Singleton {
    id: root

    // Toasts on screen at once.
    readonly property int maxPopups: 4

    // What the control center keeps; older ones expire as new ones arrive.
    readonly property int maxHistory: 100

    // What a screenshot notification calls itself.
    readonly property var screenshotWords: ["screenshot", "screen shot", "screencapture", "printscreen", "print screen", "captura", "grim", "hyprshot", "flameshot", "swappy", "satty", "shotman", "spectacle"]
    readonly property string screenshotEditor: "satty"

    // How Quickshell hands over an icon or a picture it resolved.
    readonly property string iconHandle: "image://icon/"

    // What a link in a notification body may be.
    readonly property var linkSchemes: ["http", "https", "mailto"]

    // A body arrives over the session bus where one message may be megabytes long.
    readonly property int maximumTextLength: 4096

    // Low urgency is not worth as much of the screen's time as normal.
    readonly property int normalTimeout: Math.max(Settings.notificationSeconds, 1) * 1000
    readonly property int lowTimeout: Math.round(root.normalTimeout / 2)
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

    // expireTimeout arrives off the bus in milliseconds.
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
        // The control center lists everything already.
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

    // The toast ran out on its own.
    function releasePopup(notification: var): void {
        root.removePopup(notification);
        if (notification && notification.transient)
            notification.expire();
    }

    // The user closed the toast, so the app should hear that it was dismissed rather than that it timed out.
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

    // An app replacing a notification reuses the same object and id.
    function refresh(notification: var): void {
        root.markArrival(notification);
        if (root.shouldPopup())
            root.pushPopup(notification);
    }

    // Only the arrival time.
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

    // Everything here goes into a QML Image.
    function localImage(source: string): string {
        if (!source)
            return "";

        const value = String(source);
        if (value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://"))
            return value;

        return "";
    }

    function imageSource(notification: var): string {
        return notification ? root.localImage(notification.image) : "";
    }

    // Nothing in the shell is drawn out of an icon theme.
    readonly property var iconGlyphs: ({
        "audio-volume-muted": Glyphs.volumeOff,
        "audio-volume-low": Glyphs.volumeLow,
        "audio-volume-medium": Glyphs.volumeLow,
        "audio-volume-high": Glyphs.volumeHigh,
        "audio-input-microphone": Glyphs.microphone,
        "microphone-sensitivity-muted": Glyphs.microphoneMuted,
        "display-brightness": Glyphs.sun
    })

    // The name behind whatever a notification points at, or "" for a picture rather than a name.
    function iconName(source: string): string {
        if (!source)
            return "";

        const value = String(source);
        if (value.startsWith(root.iconHandle))
            return value.slice(root.iconHandle.length).split("?")[0];

        // A path, inline image data, or any other handle.
        if (value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://"))
            return "";

        return value;
    }

    function iconGlyph(notification: var): string {
        if (!notification)
            return "";

        for (const candidate of [notification.appIcon, notification.image]) {
            const name = root.iconName(candidate);
            if (name === "")
                continue;

            // Themes ship half of these under a -symbolic name as well.
            const glyph = root.iconGlyphs[name.replace(/-symbolic$/, "")];
            if (glyph !== undefined)
                return glyph;
        }

        return "";
    }

    function appIconSource(notification: var): string {
        if (!notification || notification.appIcon === "")
            return "";

        // Screenshot tools hand the saved file to notify-send with -i.
        if (notification.appIcon.startsWith("/") || notification.appIcon.startsWith("file://"))
            return root.localImage(notification.appIcon);

        return root.localImage(Quickshell.iconPath(notification.appIcon, true));
    }

    // The scheme is the whole check.
    function safeLink(link: string): string {
        if (!link)
            return "";

        const value = String(link);
        const scheme = value.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):/);
        if (!scheme)
            return "";

        return root.linkSchemes.indexOf(scheme[1].toLowerCase()) !== -1 ? value : "";
    }

    function openLink(link: string): void {
        const safe = root.safeLink(link);
        if (safe === "") {
            console.warn("qsbar: refused a notification link with a scheme that is not allowed:", link);
            return;
        }

        Qt.openUrlExternally(safe);
    }

    function looksLikeScreenshot(notification: var): bool {
        if (!notification)
            return false;

        const haystack = (root.clampText(notification.appName) + " " + root.clampText(notification.summary) + " " + root.clampText(notification.desktopEntry)).toLowerCase();
        return root.screenshotWords.some(word => haystack.indexOf(word) !== -1);
    }

    // A picture a notification names as a file, or "".
    function picturePath(source: string): string {
        let value = source ? root.clampText(source) : "";
        if (value.startsWith(root.iconHandle)) {
            value = value.slice(root.iconHandle.length).split("?")[0];
        } else if (value.startsWith("file://")) {
            try {
                value = decodeURIComponent(value.slice(7));
            } catch (error) {
                return "";
            }
        }
        return /^\/[^\n]*\.(?:png|jpe?g|webp)$/i.test(value) ? value : "";
    }

    // The file a screenshot notification points at, or "" if there is none.
    function screenshotPath(notification: var): string {
        if (!root.looksLikeScreenshot(notification))
            return "";

        const candidates = [root.picturePath(notification.image), root.picturePath(notification.appIcon)];

        // The body is prose around the path, so it is picked out of it, up to the first space.
        const match = notification.body ? root.clampText(notification.body).match(/(?:file:\/\/)?(\/[^\s"'<>]+\.(?:png|jpg|jpeg|webp))/i) : null;
        if (match)
            candidates.push(match[1]);

        for (const path of candidates) {
            // The editor is handed this path and writes its result next to it.
            if (path !== "" && path.indexOf("/../") === -1)
                return path;
        }

        return "";
    }

    function editScreenshot(notification: var): void {
        const path = root.screenshotPath(notification);
        if (path === "")
            return;

        // Satty disables saving entirely unless told where to save, so it gets a name next to the original.
        const directory = path.slice(0, path.lastIndexOf("/") + 1);
        const output = directory + "satty-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png";

        console.log("qsbar: opening", path, "in", root.screenshotEditor);

        // Through sh rather than straight at the binary.
        Quickshell.execDetached(["sh", "-c", 'exec "$0" --filename "$1" --output-filename "$2"', root.screenshotEditor, path, output]);
    }

    // The cut may not land inside a tag.
    function clampText(text: string): string {
        const value = String(text);
        if (value.length <= root.maximumTextLength)
            return value;
        return value.slice(0, root.maximumTextLength).replace(/<[^>]*$/, "");
    }

    // Every <a> is rewritten to one that either points somewhere openLink would open or points nowhere at all.
    function sanitizeAnchors(text: string): string {
        return text.replace(/<a\b[^>]*>/gi, tag => {
            const attribute = tag.match(/href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
            if (!attribute)
                return "<a>";

            const value = attribute[1] !== undefined ? attribute[1] : attribute[2] !== undefined ? attribute[2] : attribute[3];
            const safe = root.safeLink(value);
            if (safe === "")
                return "<a>";

            // The quote is the only character that could end the attribute early and start another one.
            return '<a href="' + safe.replace(/"/g, "%22") + '">';
        });
    }

    // Markup is advertised as supported.
    function formatBody(text: string): string {
        if (!text)
            return "";

        return root.sanitizeAnchors(root.clampText(text).replace(/<img[^>]*>/gi, "")).replace(/&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)/g, "&amp;").replace(/<(?!\/?(?:b|i|u|a|br)[\s\/>])/g, "&lt;");
    }

    SystemClock {
        id: clock

        // Only the age labels read this, and they are only on screen when there is something in the list.
        enabled: root.count > 0
        precision: SystemClock.Minutes
    }

    // One watcher per tracked notification.
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

            // Oldest first, and never one still up as a toast, which holds on to it until it has animated out.
            const kept = server.trackedNotifications.values;
            for (const old of kept.slice(0, Math.max(kept.length - root.maxHistory, 0))) {
                if (root.popups.indexOf(old) === -1)
                    old.expire();
            }

            if (root.shouldPopup())
                root.pushPopup(notification);
        }
    }
}
