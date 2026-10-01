pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import "../common"
import "../services"
import "lyricsProfiles.js" as LyricsProfiles

// Lyric-edit mode: one line at a time, words landing on their sung timestamps,
// each line leaving as the next arrives, and the typographic look changing with
// the song. Looks follow the song's structure rather than a random cycle — a new
// section (an instrumental gap) brings a new look, and a repeated line such as a
// chorus comes back in the look it first had.
Item {
    id: kin
    clip: true

    // PlayerLyrics, for its bundled fonts and colour helpers.
    required property var host
    // Reel's looks can be switched off one by one in the settings; if every
    // look is off, all of them play rather than none.
    readonly property var looks: {
        const all = kin.host.style.looks ?? [];
        const off = Config.options?.media?.reelDisabledLooks ?? [];
        const on = all.filter(look => !look.id || !off.includes(look.id));
        return on.length > 0 ? on : all;
    }
    readonly property int index: LyricsService.activeIndex
    readonly property real pos: LyricsService.currentPosition

    // Seconds between line starts that count as a section break.
    readonly property real sectionGap: host.style.sectionGap ?? 6.0
    // Within one long section, move to the next look every this many lines.
    // Reel takes this from the settings; 0 there means only at section breaks.
    readonly property int linesPerLook: {
        if (!kin.host.style.camera)
            return kin.host.style.linesPerLook ?? 4;
        const lines = Config.options?.media?.reelLookChange ?? 4;
        return lines > 0 ? lines : 100000;
    }

    function normalize(text: string): string {
        return (text ?? "").toLowerCase().replace(/[.,!?;:'"“”‘’()\[\]\-]+/g, " ").replace(/\s+/g, " ").trim();
    }

    // Looks come in a shuffled order, different for every song, so no style —
    // the follow-cam included — turns up at a predictable point.

    function shuffledOrder(count: int, key: string): var {
        // FNV-1a hash of the song, then a small seeded PRNG (mulberry32).
        let h = 2166136261;
        for (let i = 0; i < key.length; i++)
            h = Math.imul(h ^ key.charCodeAt(i), 16777619);
        let state = h >>> 0;
        function next() {
            state = (state + 0x6D2B79F5) >>> 0;
            let t = state;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        }
        const order = [];
        for (let i = 0; i < count; i++)
            order.push(i);
        for (let i = count - 1; i > 0; i--) {
            const j = Math.floor(next() * (i + 1));
            const swap = order[i];
            order[i] = order[j];
            order[j] = swap;
        }
        return order;
    }

    // Look for every line, worked out once per song.
    readonly property var lineLooks: {
        const lines = LyricsService.lyricsLines;
        const count = Math.max(1, kin.looks.length);
        const order = kin.shuffledOrder(count, lines.length + ":" + (lines[0]?.text ?? "") + (lines[1]?.text ?? ""));
        const out = [];
        const firstLook = {};
        let section = 0;
        let look = order[0];
        let sinceChange = 0;
        for (let i = 0; i < lines.length; i++) {
            if (i > 0) {
                const gap = lines[i].time - lines[i - 1].time;
                sinceChange++;
                if (gap >= kin.sectionGap || sinceChange >= kin.linesPerLook) {
                    section++;
                    look = order[section % count];
                    sinceChange = 0;
                }
            }
            const key = kin.normalize(lines[i].text);
            if (key.length > 0 && firstLook[key] !== undefined) {
                out.push(firstLook[key]);
                continue;
            }
            if (key.length > 0)
                firstLook[key] = look;
            out.push(look);
        }
        return out;
    }

    function lookAt(lineIndex: int): var {
        const n = kin.looks.length;
        if (n === 0)
            return {};
        const slot = (lineIndex >= 0 && lineIndex < kin.lineLooks.length) ? kin.lineLooks[lineIndex] : 0;
        return kin.looks[((slot % n) + n) % n];
    }

    // Words with start and duration. Word-timed lyrics give them exactly; for
    // line-timed ones the line's time is shared out by word length.
    function wordsFor(lineIndex: int): var {
        const lines = LyricsService.lyricsLines;
        if (lineIndex < 0 || lineIndex >= lines.length)
            return [];
        const line = lines[lineIndex];
        const next = lineIndex + 1 < lines.length ? lines[lineIndex + 1].time : line.time + 4;

        if (line.words && line.words.length > 0) {
            const out = [];
            let current = null;
            for (let i = 0; i < line.words.length; i++) {
                const part = line.words[i];
                if (!current)
                    current = { t: part.t, end: part.t + (part.d ?? 0), text: "" };
                current.text += part.text ?? "";
                current.end = Math.max(current.end, part.t + (part.d ?? 0));
                if (part.sp || i === line.words.length - 1) {
                    out.push({ t: current.t, d: Math.max(0.05, current.end - current.t), text: current.text });
                    current = null;
                }
            }
            return out;
        }

        const parts = (line.text ?? "").split(/\s+/).filter(part => part.length > 0);
        if (parts.length === 0)
            return [];
        // Leave the tail of the gap as breathing room before the next line.
        const span = Math.max(0.6, Math.min(next - line.time, 8)) * 0.8;
        let total = 0;
        for (const part of parts)
            total += part.length + 1;
        const out = [];
        let at = line.time;
        for (const part of parts) {
            const share = span * (part.length + 1) / total;
            out.push({ t: at, d: share, text: part });
            at += share;
        }
        return out;
    }

    // ── Colour field ─────────────────────────────────────────────────────
    // The one piece of scenery: a soft wash of the current look's tint that
    // drifts to the next look's colour when the look changes.
    readonly property color tint: kin.host.styleColor(kin.lookAt(kin.index).tint ?? "theme")
    GE.RadialGradient {
        anchors.fill: parent
        // Filmed views keep the backdrop to the album art and the text's own glow.
        visible: !kin.filmed
        opacity: kin.index >= 0 ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: kin.tint
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            }
            GradientStop { position: 0.62; color: "transparent" }
        }
    }

    // ── Camera ───────────────────────────────────────────────────────────
    // Profiles with a camera treat the stage as a filmed shot: a slow push-in
    // across each line, and a punch-zoom and jolt when a word lands.
    // Camera strength from the settings scales the profile's push, punch and shake.
    readonly property var cam: {
        const base = kin.host.style.camera;
        if (!base)
            return null;
        const strength = ({ off: 0, subtle: 0.5, normal: 1, strong: 1.7 })[Config.options?.media?.reelCamera ?? "normal"] ?? 1;
        return { push: base.push * strength, punch: base.punch * strength, shake: base.shake * strength };
    }
    readonly property bool filmed: !!kin.cam && Appearance.animationsEnabled

    // Hit envelope, 0..1: snaps up when a word lands and decays.
    property real kick: 0
    property real kickPeak: 0
    // Direction of the current jolt, in radians.
    property real jolt: 0

    function punch(strength: real): void {
        if (!kin.filmed || strength <= 0)
            return;
        // A weaker hit landing while a bigger one decays doesn't cut it short.
        if (punchAnimation.running && strength < kin.kick)
            return;
        kin.kickPeak = Math.min(1, strength);
        kin.jolt = Math.random() * Math.PI * 2;
        punchAnimation.restart();
    }

    SequentialAnimation {
        id: punchAnimation
        NumberAnimation { target: kin; property: "kick"; to: kin.kickPeak; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: kin; property: "kick"; to: 0; duration: 460; easing.type: Easing.OutCubic }
    }

    // ── Beats ────────────────────────────────────────────────────────────
    // Reel listens to the music as well as the lyric timing: the shared Cava
    // spectrum gives the bass level, and a kick is a sudden jump above its
    // recent average. Each one punches the camera, bounces the word being
    // sung and pulses the glow. "Beats" in the settings scales or stops it.
    readonly property real beatStrength: !kin.cam ? 0
        : (({ off: 0, light: 0.55, strong: 1 })[Config.options?.media?.reelBeats ?? "light"] ?? 0.55)
    readonly property bool beatsOn: Appearance.animationsEnabled && kin.beatStrength > 0
    // 0..1, snaps up on a beat and decays.
    property real beatPulse: 0
    property real _bassAverage: 0
    property double _lastBeat: 0

    CavaProcess {
        id: beatSource
        active: kin.beatsOn
    }

    Connections {
        target: beatSource
        enabled: kin.beatsOn
        function onPointsChanged(): void {
            kin.readBeat(beatSource.points);
        }
    }

    function readBeat(points: var): void {
        const count = points.length;
        if (count < 4)
            return;
        // Stereo output mirrors the left channel, so the lowest bands meet in
        // the middle; in mono they lead the list.
        const stereo = Config.options?.appearance?.cava?.stereo ?? true;
        const from = stereo ? Math.floor(count / 2) - 2 : 0;
        let sum = 0;
        for (let i = from; i < from + 4; i++)
            sum += points[Math.max(0, Math.min(count - 1, i))];
        const bass = sum / 4 / 1000;
        const average = kin._bassAverage;
        kin._bassAverage = average * 0.94 + bass * 0.06;
        const now = Date.now();
        // A real kick, well over the running level, and no faster than ~300 bpm.
        if (bass > 0.16 && bass > average * 1.3 + 0.04 && now - kin._lastBeat > 200) {
            kin._lastBeat = now;
            const hit = Math.min(1, (bass - average) * 2.5) * kin.beatStrength;
            kin.punch(hit * 0.8);
            beatAnimation.stop();
            beatAnimation.peak = hit;
            beatAnimation.start();
        }
    }

    SequentialAnimation {
        id: beatAnimation
        property real peak: 1
        NumberAnimation { target: kin; property: "beatPulse"; to: beatAnimation.peak; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: kin; property: "beatPulse"; to: 0; duration: 280; easing.type: Easing.OutCubic }
    }

    // How far through the current line we are, for the push-in.
    readonly property real lineProgress: {
        if (!kin.filmed || kin.resting)
            return 0;
        const lines = LyricsService.lyricsLines;
        const i = kin.index;
        if (i < 0 || i >= lines.length)
            return 0;
        const start = lines[i].time;
        const end = i + 1 < lines.length ? lines[i + 1].time : start + 4;
        return Math.max(0, Math.min(1, (kin.pos - start) / Math.max(0.5, end - start)));
    }

    function easingFor(name: string): int {
        switch (name) {
        case "OutQuad": return Easing.OutQuad;
        case "OutBack": return Easing.OutBack;
        case "OutExpo": return Easing.OutExpo;
        case "Linear": return Easing.Linear;
        case "OutBounce": return Easing.OutBounce;
        case "OutElastic": return Easing.OutElastic;
        default: return Easing.OutCubic;
        }
    }

    // Everything "Mixed" transitions draw from.
    readonly property var exitPool: ["through", "blur", "glitch", "shatter", "whip", "fall", "split",
        "dissolve", "flip", "explode", "evaporate", "squash", "spinout", "rewind", "wipe", "iris",
        "melt", "implode", "drift", "scrambleOut"]
    readonly property var cutPool: ["none", "wipe", "iris", "push", "zoomIn", "tilt", "drop"]

    // Characters a scrambling letter flips through before it settles.
    readonly property string scrambleGlyphs: "ABCDEFGHJKLMNPQRSTUVWXYZ#%&*+=?/$@<>"
    function scrambleGlyph(seed: real, step: int): string {
        const v = Math.sin(seed * 997.3 + step * 17.31) * 43758.5453;
        return kin.scrambleGlyphs[Math.floor((v - Math.floor(v)) * kin.scrambleGlyphs.length)];
    }

    function letterMotion(name: string): var {
        return LyricsProfiles.letterMotion[name] ?? LyricsProfiles.letterMotion["rise"];
    }

    // ── Lines ────────────────────────────────────────────────────────────
    // Each line gets its own short-lived slot: it builds up, then leaves while
    // the next one comes in on top, and removes itself once it is gone.
    property var front: null

    // A musical pause: before the first line, an empty "instrumental" line, or
    // the stretch after a line has been sung when the next is still a way off.
    // The panel shows a note there instead of an empty stage or a stale line.
    readonly property bool resting: {
        const lines = LyricsService.lyricsLines;
        const i = kin.index;
        if (i < 0 || i >= lines.length)
            return true;
        if (!(lines[i].text ?? "").trim())
            return true;
        const words = kin.wordsFor(i);
        if (words.length === 0)
            return true;
        const last = words[words.length - 1];
        const next = i + 1 < lines.length ? lines[i + 1].time : Number.POSITIVE_INFINITY;
        return kin.pos > last.t + last.d + 4 && next - kin.pos > 2;
    }

    // One place decides what is on stage, so an index change and a pause
    // starting or ending at the same moment can't create the line twice.
    function sync(): void {
        const want = kin.resting ? -1 : kin.index;
        if (kin.front && !kin.front.leaving && kin.front.lineIndex === want)
            return;
        if (kin.front)
            kin.front.leave();
        kin.front = want >= 0 ? slotComponent.createObject(stage, { lineIndex: want }) : null;
    }

    onIndexChanged: kin.sync()
    onRestingChanged: kin.sync()
    Component.onCompleted: kin.sync()

    // ── Rest note ────────────────────────────────────────────────────────
    Item {
        id: restNote
        anchors.centerIn: parent
        width: noteIcon.implicitWidth
        height: noteIcon.implicitHeight
        z: 1
        readonly property var look: kin.lookAt(Math.max(0, kin.index))
        opacity: kin.resting && LyricsService.lyricsLines.length > 0 ? 0.9 : 0
        scale: kin.resting ? 1 : 0.6
        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        // A slow sway while it waits, the note keeping time with nothing.
        property real sway: 0
        SequentialAnimation on sway {
            running: kin.resting && Appearance.animationsEnabled
            loops: Animation.Infinite
            NumberAnimation { from: -1; to: 1; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: -1; duration: 1100; easing.type: Easing.InOutSine }
        }

        MaterialSymbol {
            id: noteIcon
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(restNote.sway * kin.height * 0.02 - kin.beatPulse * kin.height * 0.04)
            // Between verses the note keeps time with the music.
            scale: 1 + kin.beatPulse * 0.25
            rotation: restNote.sway * 6
            text: "music_note"
            fill: 1
            iconSize: Math.round(Math.min(kin.height, kin.width) * 0.3)
            color: kin.host.styleColor(restNote.look.color ?? "#ffffff")

            layer.enabled: !!restNote.look.glow && Appearance.effectsEnabled
            layer.effect: GE.Glow {
                radius: restNote.look.glow?.radius ?? 12
                samples: 1 + 2 * Math.ceil(restNote.look.glow?.radius ?? 12)
                spread: 0.0
                color: kin.host.styleColor(restNote.look.glow?.color ?? "theme")
                transparentBorder: true
            }
        }
    }

    Item {
        id: camera
        anchors.fill: parent
        transformOrigin: Item.Center

        // Eased so the 50 ms position steps don't show as a stutter, and so a
        // new line pulls the shot back out instead of jumping.
        property real drift: kin.lineProgress
        Behavior on drift {
            enabled: kin.filmed
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        // The line is laid out as big as the panel allows, so the camera only
        // zooms as far as the line on stage has room for: a short line gets the
        // full push and punch, a frame-filling one barely moves.
        readonly property real shake: kin.cam?.shake ?? 0
        readonly property real headroom: {
            const f = kin.front;
            if (!f || f.blockWidth <= 0 || f.blockHeight <= 0)
                return 0;
            // A follow-cam line is bigger than the frame on purpose.
            if (f.follow)
                return 0.06;
            // The glow spreads past the letters, so it needs room too.
            const glow = 2 * (f.look.glow?.radius ?? 0);
            const w = (f.blockWidth + glow + (f.stagger ? kin.width * 0.14 : 0)) * 1.06;
            const h = (f.blockHeight + glow) * 1.06;
            const room = Math.min((kin.width - 2 * camera.shake - 8) / w, (kin.height - 2 * camera.shake - 8) / h);
            return Math.max(0, room - 1);
        }
        scale: 1 + Math.min(camera.headroom,
            (kin.cam?.push ?? 0) * camera.drift + (kin.cam?.punch ?? 0) * kin.kick)
        transform: Translate {
            x: kin.kick * (kin.cam?.shake ?? 0) * Math.cos(kin.jolt)
            y: kin.kick * (kin.cam?.shake ?? 0) * Math.sin(kin.jolt)
        }

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    Component {
        id: slotComponent

        Item {
            id: slot
            anchors.fill: parent

            property int lineIndex: -1
            property bool leaving: false
            readonly property var look: kin.lookAt(slot.lineIndex)
            // Second style in the line: one hero word set in a contrasting face,
            // on its own row and bigger — "Make you / Forget", "BUT I'M / COMPLETE".
            readonly property var accent: slot.look.accent ?? null
            readonly property var rawWords: kin.wordsFor(slot.lineIndex)
            // The word the singer leans on: the longest-held one, ignoring little
            // words, so the accent lands where the voice does rather than at random.
            readonly property int heroIndex: {
                const list = slot.rawWords;
                if (!slot.accent || list.length < 2)
                    return -1;
                let best = -1;
                let bestScore = -1;
                for (let i = 0; i < list.length; i++) {
                    const letters = (list[i].text ?? "").replace(/[.,!?;:'"“”‘’()\[\]\-]/g, "");
                    if (letters.length < 3)
                        continue;
                    // Hold time first; a later word wins ties, since lines tend
                    // to resolve on their last strong word.
                    const score = list[i].d * 2 + letters.length * 0.04 + i * 0.001;
                    if (score > bestScore) {
                        bestScore = score;
                        best = i;
                    }
                }
                return best;
            }
            readonly property var words: slot.rawWords.map((word, i) =>
                ({ t: word.t, d: word.d, text: word.text, hero: i === slot.heroIndex, i: i }))

            // Style for a word: the look's own, or the accent's for the hero.
            function part(hero: bool): var {
                return hero && slot.accent ? slot.accent : slot.look;
            }
            readonly property string heroFont: kin.host.styleFont(slot.accent?.font ?? slot.look.font ?? "heavy")
            readonly property bool heroUpper: slot.accent?.uppercase ?? false
            readonly property real heroScale: slot.accent?.size ?? 1.4
            readonly property string fullText: slot.words.map(word => word.text).join(" ")

            readonly property string fontFamily: kin.host.styleFont(slot.look.font ?? "heavy")
            readonly property bool upper: slot.look.uppercase ?? false
            readonly property color ink: kin.host.styleColor(slot.look.color ?? "#ffffff")
            readonly property var glow: slot.look.glow ?? null
            readonly property string enter: slot.look.enter ?? "pop"
            // "Mixed" transitions (Reel setting) draw each line's exit and cut-in
            // from the whole pool, keyed on the line so a replay matches.
            readonly property bool mixed: !!kin.cam
                && (Config.options?.media?.reelTransitions ?? "look") === "mixed"
            function pick(pool: var, salt: int): string {
                const v = Math.sin((slot.lineIndex + 1) * 91.17 + salt * 13.7) * 43758.5453;
                return pool[Math.floor((v - Math.floor(v)) * pool.length)];
            }
            readonly property string exit: slot.mixed && slot.letters
                ? slot.pick(kin.exitPool, 1) : (slot.look.exit ?? "fade")
            // How the whole line arrives, on top of its letters landing:
            //   wipe  revealed left to right      iris  opens from the middle
            //   push  slides in from the right    zoomIn  pulls back into focus
            //   tilt  tips up from lying flat     drop  falls into place
            readonly property string cut: slot.mixed && slot.letters
                ? slot.pick(kin.cutPool, 2) : (slot.look.cut ?? "none")
            property real enterT: slot.cut === "none" ? 1 : 0
            NumberAnimation on enterT {
                running: slot.cut !== "none" && Appearance.animationsEnabled
                from: 0; to: 1
                duration: slot.cut === "drop" ? 520 : slot.cut === "iris" || slot.cut === "wipe" ? 460 : 400
                easing.type: slot.cut === "drop" ? Easing.OutBack : Easing.OutCubic
            }
            Component.onCompleted: if (!Appearance.animationsEnabled) slot.enterT = 1
            // Reel looks build words out of letters instead of whole words.
            readonly property bool letters: slot.look.letters ?? false
            readonly property bool stagger: slot.look.layout === "stagger"
            // Follow-cam: the line is set bigger than the frame and the camera
            // pans to each word as it lands.
            readonly property bool follow: slot.look.follow ?? false
            // The word the camera is on: the latest one to land, or the first
            // word before any has, so the shot opens already locked on. Worked
            // out from the playback time, so seeks and fast lines stay locked.
            readonly property int focusIndex: {
                const list = slot.words;
                let found = 0;
                for (let i = 0; i < list.length; i++) {
                    if (kin.pos >= list[i].t - 0.03)
                        found = i;
                }
                return found;
            }
            // Set by the word in focus (see the word delegate).
            property Item focusItem: null
            // Where in the line the camera is looking, in the line's coordinates.
            // Re-read whenever the word or its row moves, so a layout change
            // can't leave the camera aimed at where the word used to be.
            readonly property point focusPoint: {
                const item = slot.focusItem;
                if (!item || !item.parent)
                    return Qt.point(block.width / 2, block.height / 2);
                void (item.x + item.width + item.height + item.parent.x + item.parent.y
                      + block.width + block.height);
                return item.mapToItem(block, item.width / 2, item.height / 2);
            }
            // 0..1 through the exit; shattered letters fly out along it.
            property real exitT: 0
            // Blur over the whole line, for the cuts that smear it out.
            property real blurAmount: 0

            // Size follows the letter count, the way an edit sets it: start as big
            // as the panel allows and let the fit below shrink longer lines. A
            // two-word shout fills the panel; a long verse line settles smaller.
            readonly property real baseSize: kin.height * (slot.letters ? 0.5 : 0.42) * (slot.look.size ?? 1.0)
            // Size of the laid-out line, for the camera's headroom.
            readonly property real blockWidth: Math.max(block.width, slot.layout.width)
            readonly property real blockHeight: Math.max(block.height, slot.layout.height)
            FontMetrics {
                id: heroMetrics
                font.family: slot.heroFont
                font.pixelSize: slot.baseSize * slot.heroScale
            }
            FontMetrics {
                id: fullMetrics
                font.family: slot.fontFamily
                font.pixelSize: slot.baseSize
            }
            // Fit to the panel: measure each word once at the base size, then
            // shrink in steps until the wrapped line fits both ways. Widths
            // scale linearly with pixel size, so no re-measuring is needed.
            readonly property var layout: {
                void (fullMetrics.height + fullMetrics.averageCharacterWidth
                      + heroMetrics.height + heroMetrics.averageCharacterWidth);
                const base = slot.baseSize;
                const list = slot.words;
                // Measure the ink, not just the advance: script faces swing their
                // swashes well past the advance width, and those were the words
                // spilling off the panel. The pad covers the glow and the
                // held-word swell.
                function inkWidth(metrics, text) {
                    const r = metrics.tightBoundingRect(text);
                    return Math.max(metrics.advanceWidth(text), r.x + r.width) - Math.min(0, r.x);
                }
                // Letter-built words are drawn one glyph at a time, so a script
                // face can't join them up and they come out wider than the word
                // set whole (the blue neon looks overflowed this way). Add up the
                // separate letters, plus how far the end letters' swashes reach.
                function lettersWidth(metrics, text) {
                    const chars = Array.from(text);
                    if (chars.length === 0)
                        return 0;
                    let width = 0;
                    for (const c of chars)
                        width += metrics.advanceWidth(c);
                    const first = metrics.tightBoundingRect(chars[0]);
                    const lastChar = chars[chars.length - 1];
                    const last = metrics.tightBoundingRect(lastChar);
                    return width + Math.max(0, -first.x)
                        + Math.max(0, last.x + last.width - metrics.advanceWidth(lastChar));
                }
                function wordWidth(metrics, text) {
                    return slot.letters ? Math.max(inkWidth(metrics, text), lettersWidth(metrics, text))
                                        : inkWidth(metrics, text);
                }
                // Script capitals and descenders reach past the line height too.
                function wordHeight(metrics, text) {
                    return Math.max(metrics.height, metrics.tightBoundingRect(text).height);
                }
                const widths = list.map(word => word.hero
                    ? wordWidth(heroMetrics, slot.heroUpper ? word.text.toUpperCase() : word.text) * 1.1
                    : wordWidth(fullMetrics, slot.upper ? word.text.toUpperCase() : word.text) * 1.1);
                const heights = list.map(word => word.hero
                    ? wordHeight(heroMetrics, slot.heroUpper ? word.text.toUpperCase() : word.text) * 1.08
                    : wordHeight(fullMetrics, slot.upper ? word.text.toUpperCase() : word.text) * 1.08);
                // The glow spreads past the letters on every side.
                const glowPad = 2 * Math.max(slot.look.glow?.radius ?? 0, slot.accent?.glow?.radius ?? 0);
                // Staggered rows step sideways and get less width; a follow-cam
                // line is set bigger than the frame, for the camera to pan across.
                // The camera keeps its zoom within what is left (camera.headroom).
                const maxW = kin.width * (slot.follow ? 1.5 : slot.stagger ? 0.76 : 0.9) - glowPad;
                const maxH = kin.height * (slot.follow ? 1.3 : 0.84) - glowPad;
                let size = base;
                let rows = [];
                let inkRow = 0;
                let inkHeight = 0;
                for (let attempt = 0; attempt < 30; attempt++) {
                    const k = size / base;
                    const gap = size * 0.28;
                    rows = [];
                    let row = [];
                    let used = 0;
                    let widest = 0;
                    for (let i = 0; i < widths.length; i++) {
                        const w = widths[i] * k;
                        widest = Math.max(widest, w);
                        // The hero word always gets a row to itself.
                        if (list[i].hero) {
                            if (row.length > 0)
                                rows.push(row);
                            rows.push([list[i]]);
                            row = [];
                            used = 0;
                            continue;
                        }
                        if (row.length > 0 && used + gap + w > maxW) {
                            rows.push(row);
                            row = [];
                            used = 0;
                        }
                        used += (row.length > 0 ? gap : 0) + w;
                        row.push(list[i]);
                    }
                    if (row.length > 0)
                        rows.push(row);
                    // Widest row as drawn, for the camera's headroom.
                    inkRow = 0;
                    for (const r of rows) {
                        let w = 0;
                        for (const word of r)
                            w += widths[list.indexOf(word)] * k;
                        inkRow = Math.max(inkRow, w + gap * (r.length - 1));
                    }
                    let height = 0;
                    for (const r of rows) {
                        let tallest = 0;
                        for (const word of r)
                            tallest = Math.max(tallest, heights[list.indexOf(word)]);
                        height += tallest * k;
                    }
                    inkHeight = height;
                    // A follow-cam line may run past the frame, but every word on
                    // its own must fit, or the camera can't show it whole.
                    const widestAllowed = slot.follow ? kin.width * 0.8 - glowPad : maxW;
                    if (height <= maxH && widest <= widestAllowed)
                        break;
                    size *= 0.92;
                }
                // Never below reading size, whatever the line length.
                return { size: Math.max(16, Math.round(size)), rows: rows, width: inkRow, height: inkHeight };
            }
            readonly property real fontSize: slot.layout.size
            readonly property var rows: slot.layout.rows
            readonly property real gap: Math.round(slot.fontSize * 0.28)

            function leave(): void {
                slot.leaving = true;
                if (!Appearance.animationsEnabled) {
                    slot.destroy();
                    return;
                }
                if (slot.exit === "glitch")
                    glitchAnimation.start();
                else
                    exitAnimation.start();
            }

            transformOrigin: Item.Center

            // Exits are cuts, quicker than the entrances:
            //   through  the camera flies through the line
            //   blur     it sinks out of focus
            //   shatter  letters blow apart
            //   whip     whip-pan off the left of frame
            readonly property int exitDuration: slot.exit === "through" ? 360
                : slot.exit === "shatter" ? 460
                : slot.exit === "fall" ? 560
                : slot.exit === "split" ? 400
                : slot.exit === "dissolve" ? 480
                : slot.exit === "flip" ? 380
                : slot.exit === "explode" ? 520
                : slot.exit === "evaporate" ? 640
                : slot.exit === "squash" ? 300
                : slot.exit === "spinout" ? 520
                : slot.exit === "rewind" ? 260
                : slot.exit === "wipe" ? 380
                : slot.exit === "iris" ? 420
                : slot.exit === "melt" ? 700
                : slot.exit === "implode" ? 420
                : slot.exit === "drift" ? 720
                : slot.exit === "scrambleOut" ? 560
                : slot.exit === "whip" ? 240
                : slot.exit === "blur" ? 340
                : slot.exit === "flicker" ? 380 : 300

            ParallelAnimation {
                id: exitAnimation
                onFinished: slot.destroy()
                NumberAnimation {
                    target: slot; property: "opacity"; to: 0
                    duration: slot.exitDuration
                    easing.type: slot.exit === "flicker" ? Easing.OutBounce
                        : ["shatter", "fall", "split", "dissolve", "explode", "evaporate", "spinout",
                           "melt", "scrambleOut"].includes(slot.exit) ? Easing.InQuart
                        // Wipes and irises are carried by the mask; fade only at the very end.
                        : slot.exit === "wipe" || slot.exit === "iris" ? Easing.InExpo
                        : Easing.InCubic
                }
                NumberAnimation {
                    target: slot; property: "scale"
                    to: slot.exit === "zoom" ? 1.4 : slot.exit === "spin" ? 0.78
                        : slot.exit === "through" ? 3.2 : slot.exit === "blur" ? 0.9
                        : slot.exit === "implode" ? 0.04 : 1.0
                    duration: slot.exitDuration
                    // "implode" swells a touch before it collapses.
                    easing.type: slot.exit === "through" ? Easing.InQuad
                        : slot.exit === "implode" ? Easing.InBack : Easing.InCubic
                }
                NumberAnimation {
                    target: slot; property: "rotation"
                    to: slot.exit === "spin" ? 9 : slot.exit === "implode" ? -35 : 0
                    duration: slot.exitDuration; easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: slotShift; property: "y"
                    to: slot.exit === "lift" ? -kin.height * 0.18 : slot.exit === "drift" ? -kin.height * 0.3 : 0
                    duration: slot.exitDuration
                    easing.type: slot.exit === "drift" ? Easing.OutCubic : Easing.InCubic
                }
                NumberAnimation {
                    target: slotShift; property: "x"
                    to: slot.exit === "whip" ? -kin.width * 0.75 : slot.exit === "rewind" ? kin.width * 0.75 : 0
                    duration: slot.exitDuration; easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: slot; property: "blurAmount"
                    to: ["whip", "rewind", "blur", "through"].includes(slot.exit) ? 1
                        : slot.exit === "drift" ? 0.5 : 0
                    duration: slot.exitDuration; easing.type: Easing.InQuad
                }
                NumberAnimation {
                    target: slot; property: "exitT"; to: 1
                    duration: slot.exitDuration
                    // Falling letters accelerate; everything else bursts out and slows.
                    easing.type: slot.exit === "fall" || slot.exit === "melt" ? Easing.InQuad
                        : ["flip", "squash", "wipe", "iris"].includes(slot.exit) ? Easing.InCubic : Easing.OutCubic
                }
            }

            // A sign losing power: the line jumps sideways and flickers out.
            SequentialAnimation {
                id: glitchAnimation
                onFinished: slot.destroy()
                PropertyAction { target: slotShift; property: "x"; value: kin.width * 0.025 }
                PropertyAction { target: slot; property: "opacity"; value: 0.35 }
                PauseAnimation { duration: 45 }
                PropertyAction { target: slotShift; property: "x"; value: -kin.width * 0.04 }
                PropertyAction { target: slot; property: "opacity"; value: 0.9 }
                PauseAnimation { duration: 40 }
                PropertyAction { target: slotShift; property: "x"; value: kin.width * 0.012 }
                PropertyAction { target: slot; property: "opacity"; value: 0.15 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: slotShift; property: "x"; value: -kin.width * 0.008 }
                PropertyAction { target: slot; property: "opacity"; value: 0.6 }
                PauseAnimation { duration: 35 }
                NumberAnimation { target: slot; property: "opacity"; to: 0; duration: 90 }
            }
            transform: [
                Translate { id: slotShift },
                // Cut-ins: "push" from the right, "drop" from above.
                Translate {
                    x: slot.cut === "push" ? (1 - slot.enterT) * kin.width * 0.7 : 0
                    y: slot.cut === "drop" ? -(1 - slot.enterT) * kin.height * 0.55 : 0
                },
                // "zoomIn": starts close and pulls back into place.
                Scale {
                    origin.x: slot.width / 2
                    origin.y: slot.height / 2
                    xScale: slot.cut === "zoomIn" ? 1 + (1 - slot.enterT) * 0.7 : 1
                    yScale: xScale
                },
                // "tilt": tips up from lying flat.
                Rotation {
                    origin.x: slot.width / 2
                    origin.y: slot.height
                    axis { x: 1; y: 0; z: 0 }
                    angle: slot.cut === "tilt" ? -(1 - slot.enterT) * 75 : 0
                },
                // "flip": the line tips back away from the camera like a card.
                Rotation {
                    origin.x: slot.width / 2
                    origin.y: slot.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: slot.exit === "flip" ? slot.exitT * 88 : 0
                },
                // "squash": the line is crushed flat as it leaves.
                Scale {
                    origin.x: slot.width / 2
                    origin.y: slot.height / 2
                    xScale: slot.exit === "squash" ? 1 + slot.exitT * 0.35 : 1
                    yScale: slot.exit === "squash" ? 1 - slot.exitT * 0.95 : 1
                }
            ]

            // Wipes and irises, in or out, are a mask over the whole line.
            readonly property string maskShape: (slot.leaving && (slot.exit === "wipe" || slot.exit === "iris")) ? slot.exit
                : (!slot.leaving && slot.enterT < 1 && (slot.cut === "wipe" || slot.cut === "iris")) ? slot.cut : ""
            readonly property real maskOpen: slot.leaving ? 1 - slot.exitT : slot.enterT
            readonly property real effectBlur: Math.max(slot.blurAmount, slot.cut === "zoomIn" ? (1 - slot.enterT) * 0.8 : 0)

            Item {
                id: revealMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                // Wipe: a soft-edged band, growing from the left on the way in
                // and closing towards the right on the way out.
                Rectangle {
                    visible: slot.maskShape === "wipe"
                    height: parent.height
                    width: parent.width * 1.3 * slot.maskOpen
                    x: slot.leaving ? parent.width * 1.3 * (1 - slot.maskOpen) - parent.width * 0.3 : -parent.width * 0.3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: slot.leaving ? "transparent" : "white" }
                        GradientStop { position: 0.2; color: "white" }
                        GradientStop { position: 0.8; color: "white" }
                        GradientStop { position: 1.0; color: slot.leaving ? "white" : "transparent" }
                    }
                }
                // Iris: a circle opening from, or closing on, the middle of the line.
                Rectangle {
                    visible: slot.maskShape === "iris"
                    readonly property real reach: Math.hypot(parent.width, parent.height)
                    width: reach * slot.maskOpen
                    height: width
                    radius: width / 2
                    x: block.x + block.width / 2 - width / 2
                    y: block.y + block.height / 2 - height / 2
                    color: "white"
                }
            }

            // Blur for the cuts that smear the line (whip, rewind, fly-through,
            // blur, drift, zoom-in) and the wipe/iris mask, only while in use.
            layer.enabled: (slot.effectBlur > 0.01 || slot.maskShape.length > 0) && Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: slot.effectBlur > 0.01
                blur: slot.effectBlur
                blurMax: 48
                maskEnabled: slot.maskShape.length > 0
                maskSource: revealMask
                maskThresholdMin: 0.0
                maskSpreadAtMin: 1.0
            }

            // A soft halo of the line's own colour behind it. Sized to the text
            // rather than the panel and faded to nothing at its rim, so it lifts
            // the words without outlining the lyric area. Hits warm it slightly.
            GE.RadialGradient {
                visible: slot.letters
                // Never larger than the panel and kept inside it: a halo cut off by
                // the panel's clip reads as a box.
                // A follow-cam keeps the word in focus at the centre of the frame.
                readonly property real cx: slot.follow ? kin.width / 2 : block.x + block.width / 2
                readonly property real cy: slot.follow ? kin.height / 2 : block.y + block.height / 2
                width: Math.min(kin.width * (slot.follow ? 0.7 : 0.96), block.width * 1.3 + slot.fontSize * 2)
                height: Math.min(kin.height * (slot.follow ? 0.7 : 0.96), block.height * 1.4 + slot.fontSize * 2)
                x: Math.max(0, Math.min(kin.width - width, cx - width / 2))
                y: Math.max(0, Math.min(kin.height - height, cy - height / 2))
                horizontalRadius: width / 2
                verticalRadius: height / 2
                opacity: 0.18 + kin.kick * 0.06 + kin.beatPulse * 0.12
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: kin.host.styleColor(slot.look.glow?.color ?? slot.look.color ?? "theme")
                    }
                    // Most of the falloff happens early, so the rim is already clear.
                    GradientStop { position: 0.85; color: "transparent" }
                }
            }

            Column {
                id: block
                anchors.centerIn: slot.follow ? undefined : parent
                spacing: Math.round(slot.fontSize * 0.05)

                // Follow-cam: slide the line so the word in focus sits at the
                // centre of the frame. The ease is the camera operator catching up.
                x: kin.width / 2 - slot.focusPoint.x
                y: kin.height / 2 - slot.focusPoint.y
                Behavior on x {
                    enabled: slot.follow && Appearance.animationsEnabled
                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: slot.follow && Appearance.animationsEnabled
                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: slot.rows

                    delegate: Row {
                        id: rowItem
                        required property var modelData
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Staggered layouts step each row off centre, alternating sides.
                        anchors.horizontalCenterOffset: slot.stagger && slot.rows.length > 1
                            ? (rowItem.index % 2 === 0 ? -1 : 1) * kin.width * 0.07 : 0
                        spacing: slot.gap

                        Repeater {
                            model: rowItem.modelData

                            delegate: Item {
                                id: word
                                required property var modelData

                                // A word stays up once sung; seeking back hides it again.
                                readonly property bool shown: kin.pos >= word.modelData.t - 0.03
                                    || slot.lineIndex < LyricsService.activeIndex
                                readonly property bool singing: kin.pos >= word.modelData.t
                                    && kin.pos < word.modelData.t + word.modelData.d
                                // Held words hit harder — the emphasis comes from the timing.
                                readonly property bool held: word.modelData.d >= 0.6
                                readonly property bool hero: !!word.modelData.hero
                                readonly property var style: slot.part(word.hero)
                                readonly property string enter: word.style.enter ?? slot.enter
                                readonly property var glowStyle: word.style.glow ?? null

                                implicitWidth: slot.letters ? letterRow.implicitWidth : label.implicitWidth
                                implicitHeight: slot.letters ? letterRow.implicitHeight : label.implicitHeight
                                width: implicitWidth
                                height: implicitHeight
                                transformOrigin: Item.Bottom

                                readonly property real startScale: word.enter === "slam" ? 1.9
                                    : word.enter === "pop" ? 0.3
                                    : word.enter === "swing" ? 0.7 : 1.0
                                readonly property real startY: word.enter === "rise" ? slot.fontSize * 0.5
                                    : word.enter === "drop" ? -slot.fontSize * 0.8 : 0
                                readonly property real startRotation: word.enter === "swing" ? -14 : 0
                                // Script accents sit at a slight angle, like a hand-set flourish.
                                readonly property real restRotation: word.hero ? (slot.accent?.tilt ?? 0) : 0

                                // Letter-built words animate their letters, so the word itself
                                // only keeps the held-note swell and the accent's tilt.
                                opacity: word.shown || slot.letters ? 1 : 0
                                scale: word.shown ? (word.singing && word.held ? 1.1 : 1.0)
                                    : slot.letters ? 1.0 : word.startScale
                                rotation: word.shown || slot.letters ? word.restRotation : word.startRotation
                                transform: [
                                    Translate {
                                        y: word.shown || slot.letters ? 0 : word.startY
                                        Behavior on y {
                                            enabled: Appearance.animationsEnabled
                                            NumberAnimation {
                                                duration: word.enter === "drop" ? 520 : 360
                                                easing.type: word.enter === "drop" ? Easing.OutBounce : Easing.OutCubic
                                            }
                                        }
                                    },
                                    // The word being sung bounces on the beat.
                                    Scale {
                                        origin.x: word.width / 2
                                        origin.y: word.height
                                        xScale: word.singing ? 1 + kin.beatPulse * 0.09 : 1
                                        yScale: word.singing ? 1 + kin.beatPulse * 0.12 : 1
                                    }
                                ]

                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: word.enter === "slam" ? 90 : 180 }
                                }
                                Behavior on scale {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: word.enter === "slam" ? 220 : 340
                                        easing.type: word.enter === "slam" ? Easing.OutCubic : Easing.OutBack
                                        easing.overshoot: word.enter === "pop" ? 2.6 : 1.8
                                    }
                                }
                                Behavior on rotation {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                                }

                                // The hit drives the camera: heavier for held words and the hero.
                                onShownChanged: {
                                    if (word.shown && slot.letters && !slot.leaving)
                                        kin.punch((slot.look.punch ?? 1) * (word.hero ? 1.0 : word.held ? 0.6 : 0.3));
                                }

                                // Hand the follow-cam this word while it is the one in focus.
                                Binding {
                                    // By position in the line: the Repeater hands each word a
                                    // copy of its entry, so object identity never matches.
                                    when: slot.follow && word.modelData.i === slot.focusIndex
                                    target: slot
                                    property: "focusItem"
                                    value: word
                                    restoreMode: Binding.RestoreNone
                                }

                                readonly property var motion: kin.letterMotion(word.enter)
                                readonly property real em: slot.fontSize * (word.hero ? slot.heroScale : 1.0)
                                readonly property color ink: kin.host.styleColor(word.style.color ?? "#ffffff")
                                readonly property color highlight: kin.host.styleColor(word.style.highlight
                                    ?? slot.look.highlight ?? word.style.color ?? "#ffffff")
                                // Focus-pull entrances start the word out of focus.
                                property real focusBlur: slot.letters && word.motion.blur && !word.shown ? 1 : 0
                                Behavior on focusBlur {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                                }

                                Row {
                                    id: letterRow
                                    visible: slot.letters
                                    readonly property var chars: slot.letters ? Array.from(word.modelData.text ?? "") : []

                                    layer.enabled: slot.letters && Appearance.effectsEnabled
                                        && (!!word.glowStyle || word.focusBlur > 0.01)
                                    layer.effect: MultiEffect {
                                        blurEnabled: word.focusBlur > 0.01
                                        blur: word.focusBlur
                                        blurMax: 40
                                        shadowEnabled: !!word.glowStyle
                                        shadowColor: kin.host.styleColor(word.glowStyle?.color ?? "theme")
                                        shadowBlur: Math.min(1, (word.glowStyle?.radius ?? 12) / 18)
                                        shadowHorizontalOffset: 0
                                        shadowVerticalOffset: 0
                                        shadowScale: 1.03
                                    }

                                    Repeater {
                                        model: letterRow.chars

                                        delegate: Text {
                                            id: letter
                                            required property string modelData
                                            required property int index
                                            readonly property int count: letterRow.chars.length

                                            // Stable per-letter randomness, so a line scatters the
                                            // same way every time it plays.
                                            function noise(salt: real): real {
                                                const v = Math.sin((slot.lineIndex + 1) * 12.9898
                                                    + word.modelData.t * 78.233 + letter.index * 37.719 + salt) * 43758.5453;
                                                return v - Math.floor(v) - 0.5;
                                            }
                                            readonly property real nx: letter.noise(1.3)
                                            readonly property real ny: letter.noise(7.1)

                                            // 0 before the letter lands, 1 once it has (overshoots on OutBack).
                                            property real p: word.shown ? 1 : 0
                                            readonly property real q: 1 - letter.p

                                            text: letter.modelData
                                            renderType: Text.QtRendering
                                            font.family: word.hero ? slot.heroFont : slot.fontFamily
                                            font.pixelSize: Math.round(word.em)
                                            font.weight: (word.style.font ?? "heavy") === "theme" ? Font.Bold : Font.Normal
                                            font.capitalization: (word.hero ? slot.heroUpper : slot.upper) ? Font.AllUppercase : Font.MixedCase
                                            style: word.style.outline ? Text.Outline : Text.Normal
                                            styleColor: kin.host.styleColor(word.style.outline ?? "#000000")

                                            // The highlight sweeps through the word at the speed it is
                                            // sung, then the word settles back to its ink.
                                            readonly property bool lit: word.singing
                                                && kin.pos >= word.modelData.t + word.modelData.d * letter.index / Math.max(1, letter.count)
                                            // While scrambling, the real letter only holds its place in the row.
                                            color: letter.scrambling ? "transparent" : letter.lit ? word.highlight : word.ink
                                            Behavior on color {
                                                enabled: Appearance.animationsEnabled && !letter.scrambling
                                                ColorAnimation { duration: 140 }
                                            }

                                            // Odd/even letters, and which half of the word a letter is in.
                                            readonly property real parity: letter.index % 2 === 0 ? -1 : 1
                                            readonly property real side: letter.index < letter.count / 2 ? -1 : 1
                                            readonly property real sy: word.motion.sy ?? 1
                                            // "elastic" sets its own start width; "stretch" keeps volume.
                                            readonly property real sx: word.motion.sx ?? (1 / letter.sy)
                                            readonly property string out: slot.exit
                                            // A fixed direction per letter, for orbits and bursts.
                                            readonly property real angle: (letter.nx + 0.5) * Math.PI * 2

                                            // "dissolve" and "evaporate" switch letters off one by one in a
                                            // random order. Each letter has its own moment in the exit
                                            // (0.2..1); at rest exitT is 0, so every letter is fully on.
                                            readonly property real dissolve: ["dissolve", "evaporate", "scrambleOut"].includes(letter.out)
                                                ? Math.max(0, Math.min(1, (0.2 + (letter.nx + 0.5) * 0.8 - slot.exitT) * 6)) : 1
                                            // "strobe" flickers the letter on and off while it lands.
                                            readonly property real strobe: word.motion.strobe && letter.p < 1
                                                ? (Math.floor(letter.p * 10) % 2 === 0 ? 0.12 : 1) : 1
                                            // "scramble" flips through random characters before it settles,
                                            // and "scrambleOut" does it in reverse on the way out.
                                            readonly property bool scrambling: (word.motion.scramble && letter.p > 0 && letter.p < 0.98)
                                                || (letter.out === "scrambleOut" && slot.exitT > 0.02)
                                            opacity: Math.max(0, Math.min(1, letter.p * 2.2)) * letter.dissolve * letter.strobe
                                            scale: (word.motion.scale + (1 - word.motion.scale) * letter.p)
                                                * (letter.out === "explode" ? 1 + slot.exitT * 0.6
                                                    : letter.out === "spinout" ? 1 - slot.exitT : 1)
                                            // "pendulum" letters hang from their top edge.
                                            transformOrigin: word.motion.hang ? Item.Top : Item.Bottom
                                            rotation: (word.motion.rot * 2 * (word.motion.hang ? 1 : letter.nx)) * letter.q
                                                + (letter.out === "shatter" ? slot.exitT * 160 * letter.nx
                                                    : letter.out === "fall" ? slot.exitT * 70 * letter.nx
                                                    : letter.out === "explode" ? slot.exitT * 220 * letter.nx
                                                    : letter.out === "spinout" ? slot.exitT * 540 * letter.parity : 0)
                                            // "jitter": a shake that dies away as the letter lands.
                                            readonly property real shake: (word.motion.jitter ?? 0) * word.em * letter.q
                                            transform: [
                                                Translate {
                                                    x: (word.motion.x + word.motion.spread * 2 * letter.nx
                                                            + (word.motion.alt ?? 0) * letter.parity
                                                            + (word.motion.orbit ?? 0) * Math.cos(letter.angle + letter.q * 2.5)) * word.em * letter.q
                                                        + letter.shake * Math.sin(letter.p * 47 + letter.nx * 9)
                                                        + (letter.out === "shatter" ? slot.exitT * 6 * letter.nx * word.em
                                                            : letter.out === "split" ? slot.exitT * 2.6 * letter.side * word.em
                                                            : letter.out === "fall" ? slot.exitT * letter.nx * word.em
                                                            : letter.out === "explode" ? slot.exitT * 4 * Math.cos(letter.angle) * word.em : 0)
                                                    y: (word.motion.y + word.motion.spread * 2 * letter.ny
                                                            + (word.motion.altY ?? 0) * letter.parity
                                                            + (word.motion.orbit ?? 0) * Math.sin(letter.angle + letter.q * 2.5)) * word.em * letter.q
                                                        + letter.shake * Math.sin(letter.p * 61 + letter.ny * 7) * 0.6
                                                        + (letter.out === "shatter" ? slot.exitT * 5 * letter.ny * word.em
                                                            : letter.out === "fall" ? slot.exitT * (3 + 2 * letter.ny) * word.em
                                                            : letter.out === "melt" ? slot.exitT * (1.2 + 1.6 * (letter.ny + 0.5)) * word.em
                                                            : letter.out === "explode" ? slot.exitT * 4 * Math.sin(letter.angle) * word.em
                                                            : letter.out === "evaporate" ? -slot.exitT * (1.5 + 2 * (letter.ny + 0.5)) * word.em : 0)
                                                },
                                                // "stretch", "elastic" and "unfold": squeezed, springing out
                                                // to shape; "melt" drips the letter out long and thin.
                                                Scale {
                                                    origin.x: letter.width / 2
                                                    origin.y: word.motion.unfold || letter.out === "melt" ? 0 : letter.height
                                                    xScale: (1 + (letter.sx - 1) * letter.q)
                                                        * (letter.out === "melt" ? 1 - slot.exitT * 0.35 : 1)
                                                    yScale: (1 + (letter.sy - 1) * letter.q)
                                                        * (letter.out === "melt" ? 1 + slot.exitT * 1.4 : 1)
                                                },
                                                // "lean": sheared over like a fast italic, snapping upright.
                                                Matrix4x4 {
                                                    readonly property real k: (word.motion.lean ?? 0) * letter.q
                                                    matrix: Qt.matrix4x4(1, -k, 0, k * letter.height,
                                                                         0, 1, 0, 0,
                                                                         0, 0, 1, 0,
                                                                         0, 0, 0, 1)
                                                },
                                                // "tumble": flipped over the horizontal axis, like a split-flap board.
                                                Rotation {
                                                    origin.x: letter.width / 2
                                                    origin.y: letter.height / 2
                                                    axis { x: 1; y: 0; z: 0 }
                                                    angle: (word.motion.flipX ?? 0) * letter.q
                                                },
                                                // "flip": turned edge-on, rolling round to face front.
                                                Rotation {
                                                    origin.x: letter.width / 2
                                                    origin.y: letter.height / 2
                                                    axis { x: 0; y: 1; z: 0 }
                                                    angle: (word.motion.flip ?? 0) * letter.q
                                                }
                                            ]

                                            Text {
                                                anchors.centerIn: parent
                                                visible: letter.scrambling
                                                text: kin.scrambleGlyph(letter.nx * 31 + letter.index,
                                                    Math.floor((letter.p + slot.exitT) * 16))
                                                renderType: Text.QtRendering
                                                font: letter.font
                                                color: word.highlight
                                            }

                                            SequentialAnimation {
                                                id: letterIn
                                                // "rain" lands its letters in a scattered order.
                                                PauseAnimation {
                                                    duration: letter.index * word.motion.stagger
                                                        + (letter.nx + 0.5) * (word.motion.scatterDelay ?? 0)
                                                }
                                                NumberAnimation {
                                                    target: letter; property: "p"; to: 1
                                                    duration: word.motion.dur
                                                    easing.type: kin.easingFor(word.motion.ease)
                                                    easing.overshoot: 1.7
                                                }
                                            }

                                            Connections {
                                                target: word
                                                function onShownChanged(): void {
                                                    letterIn.stop();
                                                    // Break the initial binding: from here the animation owns p.
                                                    letter.p = 0;
                                                    if (word.shown && Appearance.animationsEnabled)
                                                        letterIn.start();
                                                    else
                                                        letter.p = word.shown ? 1 : 0;
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    id: label
                                    visible: !slot.letters
                                    text: word.modelData.text
                                    renderType: Text.QtRendering
                                    font.family: word.hero ? slot.heroFont : slot.fontFamily
                                    font.pixelSize: Math.round(slot.fontSize * (word.hero ? slot.heroScale : 1.0))
                                    font.weight: (word.style.font ?? "heavy") === "theme" ? Font.Bold : Font.Normal
                                    font.capitalization: (word.hero ? slot.heroUpper : slot.upper) ? Font.AllUppercase : Font.MixedCase
                                    color: kin.host.styleColor(word.style.color ?? "#ffffff")
                                    style: word.style.outline ? Text.Outline : Text.Normal
                                    styleColor: kin.host.styleColor(word.style.outline ?? "#000000")

                                    layer.enabled: !slot.letters && !!word.glowStyle && Appearance.effectsEnabled
                                    layer.effect: GE.Glow {
                                        radius: word.glowStyle?.radius ?? 12
                                        samples: 1 + 2 * Math.ceil(word.glowStyle?.radius ?? 12)
                                        spread: 0.0
                                        color: kin.host.styleColor(word.glowStyle?.color ?? "theme")
                                        transparentBorder: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
