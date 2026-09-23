import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// What the media and volume keys talk to, the same way the overview keybind already talks to the shell: qs ipc call audio sinkUp. The bar owns PipeWire and MPRIS already, so routing the keys through here drops pamixer and playerctl and makes a key press light the bar's own level bar rather than a second, separate indicator.
// One scope at the root rather than inside Bar, which Variants builds once per screen: two windows registering the same IPC target is one too many.
Scope {
    id: root

    // Five percent a press, and a ceiling of one: the same step pamixer used and the same cap it applied without --allow-boost. Scrolling the bar icon still goes past it.
    readonly property real step: 0.05
    readonly property real maximum: 1.0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    function audioOf(node: var): var {
        return node !== null && node.ready && node.audio !== null ? node.audio : null;
    }

    // "42%", or "muted", which is the shape pamixer --get-volume-human answered in and what the notify wrapper still reads.
    function describe(node: var): string {
        const audio = root.audioOf(node);
        if (audio === null)
            return "";
        if (audio.muted)
            return "muted";
        return Math.round(audio.volume * 100) + "%";
    }

    // Raising the volume unmutes, which is what pamixer -u before every step was doing.
    function nudge(node: var, steps: int): string {
        const audio = root.audioOf(node);
        if (audio === null)
            return "";

        audio.muted = false;
        audio.volume = Math.min(Math.max(audio.volume + steps * root.step, 0), root.maximum);
        return root.describe(node);
    }

    function toggleMute(node: var): string {
        const audio = root.audioOf(node);
        if (audio === null)
            return "";

        audio.muted = !audio.muted;
        return root.describe(node);
    }

    // The player the bar itself would be showing: whatever is playing, else the first one there is.
    readonly property MprisPlayer player: {
        const players = Mpris.players ? Mpris.players.values : [];
        for (const candidate of players) {
            if (candidate && candidate.playbackState === MprisPlaybackState.Playing)
                return candidate;
        }
        return players.length > 0 ? players[0] : null;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    IpcHandler {
        target: "audio"

        function sinkUp(): string {
            return root.nudge(root.sink, 1);
        }

        function sinkDown(): string {
            return root.nudge(root.sink, -1);
        }

        function sinkToggle(): string {
            return root.toggleMute(root.sink);
        }

        function sinkStatus(): string {
            return root.describe(root.sink);
        }

        function sourceUp(): string {
            return root.nudge(root.source, 1);
        }

        function sourceDown(): string {
            return root.nudge(root.source, -1);
        }

        function sourceToggle(): string {
            return root.toggleMute(root.source);
        }

        function sourceStatus(): string {
            return root.describe(root.source);
        }
    }

    IpcHandler {
        target: "media"

        // canTogglePlaying and friends are the player saying whether it will listen; calling anyway is how a dead binding looks like a broken key.
        function playPause(): void {
            if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying();
        }

        function next(): void {
            if (root.player && root.player.canGoNext)
                root.player.next();
        }

        function previous(): void {
            if (root.player && root.player.canGoPrevious)
                root.player.previous();
        }

        // Every player the bar can see, what each will accept, and which one a key goes to (marked *): what a media key that does nothing comes down to.
        function status(): string {
            const players = Mpris.players ? Mpris.players.values : [];
            if (players.length === 0)
                return "no players";

            return players.map(player => {
                const accepts = [player.canTogglePlaying ? "toggle" : "", player.canGoNext ? "next" : "", player.canGoPrevious ? "previous" : ""].filter(flag => flag !== "").join(" ");
                const mark = player === root.player ? "*" : " ";
                return mark + " " + player.identity + " (" + player.dbusName + ") " + (player.isPlaying ? "playing" : "not playing") + " | accepts: " + (accepts || "nothing");
            }).join("\n");
        }
    }
}
