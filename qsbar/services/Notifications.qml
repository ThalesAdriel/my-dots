pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/config"
import "root:/services"

Singleton {
    id: root

    // Toasts on screen at once; anything past this still lands in the control center, it just does not pile up down the side of the display.
    readonly property int maxPopups: 4

    // What a screenshot notification calls itself: anything with one of these in its name or summary and a real file behind it gets the editor button.
    readonly property var screenshotWords: ["screenshot", "screen shot", "screencapture", "printscreen", "print screen", "captura", "grim", "hyprshot", "flameshot", "swappy", "satty", "shotman", "spectacle"]
    readonly property string screenshotEditor: "satty"

    // What a link in a notification body may be. Everything else ends up at xdg-open, which runs a .desktop file and hands any other path to whatever claims the type, so an unfiltered href turns one click into arbitrary execution — and any process on the session bus can send a body.
    readonly property var linkSchemes: ["http", "https", "mailto"]

    // A body arrives over the session bus where one message may be megabytes long, and the markup parser walks all of it before maximumLineCount gets a say, so the text is cut to more than a card can show and less than a parser will choke on.
    readonly property int maximumTextLength: 4096

    // Low urgency is not worth as much of the screen's time as normal, so it keeps its half of whatever the setting says.
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

    // expireTimeout arrives off the bus in milliseconds: -1 asks the server to pick, 0 means it never times out on its own, and critical is held the same way swaync's timeout-critical = 0 did. A returned 0 means "no timer".
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
        // The control center lists everything already, so there is nothing to gain from toasting over the top of it.
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

    // The toast ran out on its own; transient notifications asked not to be kept in a notification area, so they leave with it rather than filling the list.
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

    // An app replacing a notification reuses the same object and id, so the server never emits `notification` twice and the text changing is the only sign there is something new.
    function refresh(notification: var): void {
        root.markArrival(notification);
        if (root.shouldPopup())
            root.pushPopup(notification);
    }

    // Only the arrival time: a toast still on screen owns its own removal so it can animate out first, and the lock it holds keeps the notification alive until it has.
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

    // Everything here goes into a QML Image, which fetches a remote URL as readily as it opens a file, and a notification names its own icon — so without this any app on the bus could point the shell at a server it controls and learn the machine is awake. image:// covers Quickshell's own handles.
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

    // Nothing in the shell is drawn out of an icon theme, so a name like `audio-volume-high` from the volume and brightness keybinds resolved to the icon provider's placeholder square; the names the spec settled on are drawn as glyphs here instead, so they render like the bar.
    readonly property var iconGlyphs: ({
        "audio-volume-muted": Glyphs.volumeOff,
        "audio-volume-low": Glyphs.volumeLow,
        "audio-volume-medium": Glyphs.volumeLow,
        "audio-volume-high": Glyphs.volumeHigh,
        "audio-input-microphone": Glyphs.microphone,
        "microphone-sensitivity-muted": Glyphs.microphoneMuted,
        "display-brightness": Glyphs.sun
    })

    // The name behind whatever a notification points at, or "" for a picture rather than a name: an app_icon reaches the card both as the bare name the sender wrote and already wrapped in the handle Quickshell resolved it to, which is why matching the name alone was not enough.
    function iconName(source: string): string {
        if (!source)
            return "";

        const value = String(source);
        const handle = "image://icon/";
        if (value.startsWith(handle))
            return value.slice(handle.length).split("?")[0];

        // A path, inline image data, or any other handle: a real picture, and nothing a glyph should be standing in for.
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

            // Themes ship half of these under a -symbolic name as well, and the two are the same icon as far as a glyph is concerned.
            const glyph = root.iconGlyphs[name.replace(/-symbolic$/, "")];
            if (glyph !== undefined)
                return glyph;
        }

        return "";
    }

    function appIconSource(notification: var): string {
        if (!notification || notification.appIcon === "")
            return "";

        // Screenshot tools hand the saved file to notify-send with -i, so the app icon is sometimes a path rather than the name of a theme icon.
        if (notification.appIcon.startsWith("/") || notification.appIcon.startsWith("file://"))
            return root.localImage(notification.appIcon);

        return root.localImage(Quickshell.iconPath(notification.appIcon, true));
    }

    // The scheme is the whole check: a link with no scheme is a bare path that xdg-open would resolve against the filesystem, so it is refused too.
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
            console.warn("pesqBar: refused a notification link with a scheme that is not allowed:", link);
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

    // The file a screenshot notification points at, or "" if there is none: grimblast and hyprshot pass it as the icon and name it again in the body, others set the image-path hint, and some only hand over raw image data that never reaches disk.
    function screenshotPath(notification: var): string {
        if (!root.looksLikeScreenshot(notification))
            return "";

        const candidates = [notification.image, notification.appIcon, notification.body];
        for (const candidate of candidates) {
            if (!candidate)
                continue;

            const match = root.clampText(candidate).match(/(?:file:\/\/)?(\/[^\s"'<>]+\.(?:png|jpg|jpeg|webp))/i);
            if (!match)
                continue;

            // The editor is handed this path and writes its result next to it, so a body that walks back up out of the directory it named would pick where that file lands; an honest screenshot tool never sends one.
            if (match[1].indexOf("/../") !== -1)
                continue;

            return match[1];
        }

        return "";
    }

    function editScreenshot(notification: var): void {
        const path = root.screenshotPath(notification);
        if (path === "")
            return;

        // Satty disables saving entirely unless told where to save, so it gets a name next to the original; the timestamp is built here rather than with Satty's own format specifiers, which only newer versions understand.
        const directory = path.slice(0, path.lastIndexOf("/") + 1);
        const output = directory + "satty-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png";

        console.log("pesqBar: opening", path, "in", root.screenshotEditor);

        // Through sh rather than straight at the binary: execDetached throws away everything QProcess says about a failed start, so this way "satty: not found" lands in the log. Paths go in as arguments, so spaces are fine.
        Quickshell.execDetached(["sh", "-c", 'exec "$0" --filename "$1" --output-filename "$2"', root.screenshotEditor, path, output]);
    }

    // The cut may not land inside a tag: half of one would leave the escaping below with an opening bracket it never sees the end of.
    function clampText(text: string): string {
        const value = String(text);
        if (value.length <= root.maximumTextLength)
            return value;
        return value.slice(0, root.maximumTextLength).replace(/<[^>]*$/, "");
    }

    // Every <a> is rewritten to one that either points somewhere openLink would open or points nowhere at all; a refused link keeps its text but loses the anchor, and the closing tag is left alone since an empty <a> still matches it.
    function sanitizeAnchors(text: string): string {
        return text.replace(/<a\b[^>]*>/gi, tag => {
            const attribute = tag.match(/href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
            if (!attribute)
                return "<a>";

            const value = attribute[1] !== undefined ? attribute[1] : attribute[2] !== undefined ? attribute[2] : attribute[3];
            const safe = root.safeLink(value);
            if (safe === "")
                return "<a>";

            // The quote is the only character that could end the attribute early and start another one; & is left for the escaping pass below.
            return '<a href="' + safe.replace(/"/g, "%22") + '">';
        });
    }

    // Markup is advertised as supported, so bodies mix real markup with plain text carrying bare & and < that make StyledText drop the rest: keep the tags the spec allows, literalise the rest, and clean the anchors first so surviving hrefs get escaped with everything else.
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

    // One watcher per tracked notification: closing has to clean up after itself or the arrival times grow for the life of the session, and a replacement has to be noticed here because the server signal never fires twice.
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
