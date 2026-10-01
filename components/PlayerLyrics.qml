pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import "../common"
import "../common"
import "../common"
import "../services"
import "lyricsProfiles.js" as LyricsProfiles

Item {
    id: root

    property color textColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    property color activeColor: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property int textAlignment: Text.AlignHCenter
    property int lineSpacing: 12

    property int baseSize: Appearance.font.pixelSize.normal
    property real activeScale: 1.18

    // ── Style profile ───────────────────────────────────────────────────────
    // The look of the sheet comes from a named profile (lyricsProfiles.js), so
    // restyling is a matter of picking another one — or describing a "custom"
    // one in the config. The theme profile reproduces the original look.
    readonly property var style: LyricsProfiles.resolve(
        Config.options?.media?.lyricsStyle ?? "default",
        Config.options?.media?.lyricsCustomStyle ?? ({}))

    // Display faces ship with the shell, so a profile never silently falls back
    // to whatever serif or script the system happens to have.
    readonly property string _fontDir: Qt.resolvedUrl("../assets/fonts/lyrics/")
    FontLoader { id: fontHeavy; source: root._fontDir + "ArchivoBlack-Regular.ttf" }
    FontLoader { id: fontSerif; source: root._fontDir + "PlayfairDisplay.ttf" }
    FontLoader { id: fontScript; source: root._fontDir + "GreatVibes-Regular.ttf" }
    FontLoader { id: fontBrush; source: root._fontDir + "KaushanScript-Regular.ttf" }
    FontLoader { id: fontSignature; source: root._fontDir + "Yellowtail-Regular.ttf" }
    FontLoader { id: fontPoster; source: root._fontDir + "Anton-Regular.ttf" }
    FontLoader { id: fontGothic; source: root._fontDir + "PirataOne-Regular.ttf" }
    FontLoader { id: fontRetro; source: root._fontDir + "Monoton-Regular.ttf" }

    function styleFont(key: string): string {
        const loader = key === "heavy" ? fontHeavy
            : key === "serif" ? fontSerif
            : key === "script" ? fontScript
            : key === "brush" ? fontBrush
            : key === "signature" ? fontSignature
            : key === "poster" ? fontPoster
            : key === "gothic" ? fontGothic
            : key === "retro" ? fontRetro
            : null;
        return (loader && loader.status === FontLoader.Ready) ? loader.name : Appearance.font.family.main;
    }
    function styleColor(value: var): color {
        if (!value || value === "theme")
            return root.activeColor;
        if (value === "themeText")
            return root.textColor;
        return value;
    }

    readonly property string lineFont: root.styleFont(root.style.line?.font ?? "theme")
    readonly property bool lineUppercase: root.style.line?.uppercase ?? false
    readonly property real lineLetterSpacing: root.style.line?.spacing ?? 0
    readonly property int lineWeight: root.style.line?.weight ?? 700
    readonly property color sungColor: root.styleColor(root.style.fill)
    readonly property color restColor: root.styleColor(root.style.rest ?? "themeText")
    readonly property real restAlpha: root.style.restAlpha ?? 0.28
    // Upcoming words on the line being sung. Glow-heavy profiles need these far
    // brighter than the resting lines, or the halo drowns them.
    readonly property real activeRestAlpha: root.style.activeRestAlpha ?? -1
    readonly property color singingColor: root.styleColor(root.style.singing?.color ?? "#ffffff")
    readonly property var glowStyle: root.style.glow ?? null
    readonly property color glowColor: root.styleColor(root.glowStyle?.color ?? "theme")
    readonly property bool outlineEcho: root.style.echo === "outline"
    // Lyric-edit mode swaps the scrolling sheet for KineticLyrics.
    readonly property bool kinetic: root.style.mode === "kinetic"
    readonly property var lineGlowStyle: root.style.lineGlow ?? null
    // Display faces read smaller than the UI font at the same pixel size (script
    // x-heights are tiny, poster capitals want room), so a profile sets its scale.
    readonly property real styleSize: root.style.size ?? 1.0
    readonly property color lineGlowColor: {
        const c = root.styleColor(root.lineGlowStyle?.color ?? "theme");
        return Qt.rgba(c.r, c.g, c.b, root.lineGlowStyle?.strength ?? 0.6);
    }
    readonly property var stageStyle: root.style.stage ?? null
    // Script faces ship a single weight; asking for Bold makes Qt fake it, which
    // smears calligraphy. Only the theme font gets the active/rest weight swing.
    // The word being sung right now: exact from syllable timings when the lyrics
    // carry them, otherwise estimated from how far through the line we are.
    readonly property string stageWord: {
        if (!root.stageStyle)
            return "";
        const lines = LyricsService.lyricsLines;
        const index = LyricsService.activeIndex;
        if (index < 0 || index >= lines.length)
            return "";
        const line = lines[index];
        const pos = LyricsService.currentPosition;
        let word = "";
        if (line.words && line.words.length > 0) {
            let current = null;
            const groups = [];
            for (let i = 0; i < line.words.length; i++) {
                const syllable = line.words[i];
                if (!current)
                    current = { t: syllable.t, text: "" };
                current.text += syllable.text ?? "";
                if (syllable.sp) {
                    groups.push(current);
                    current = null;
                }
            }
            if (current)
                groups.push(current);
            word = groups.length > 0 ? groups[0].text : "";
            for (let i = 0; i < groups.length; i++) {
                if (groups[i].t <= pos)
                    word = groups[i].text;
                else
                    break;
            }
        } else {
            const parts = (line.text ?? "").split(/\s+/).filter(part => part.length > 0);
            if (parts.length === 0)
                return "";
            const next = index + 1 < lines.length ? lines[index + 1].time : line.time + 4;
            const span = Math.max(0.5, next - line.time);
            const at = Math.floor(((pos - line.time) / span) * parts.length);
            word = parts[Math.max(0, Math.min(parts.length - 1, at))];
        }
        return word.replace(/[.,!?;:"“”()\[\]]/g, "").trim();
    }

    readonly property bool themeFont: (root.style.line?.font ?? "theme") === "theme"
    function lineWeightFor(active: bool): int {
        return root.themeFont ? (active ? Font.Bold : Font.DemiBold) : root.lineWeight;
    }
    property int falloff: 5
    property bool showPlaceholder: true

    implicitWidth: 160
    implicitHeight: 72

    readonly property int activeIndex: LyricsService.activeIndex
    readonly property bool hasLyrics: LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    property bool _subscribed: false

    function syncSubscription(): void {
        const shouldSubscribe = root.visible;
        if (shouldSubscribe === root._subscribed)
            return;

        root._subscribed = shouldSubscribe;
        if (shouldSubscribe)
            LyricsService.subscribe();
        else
            LyricsService.unsubscribe();
    }

    onVisibleChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root._subscribed) {
            root._subscribed = false;
            LyricsService.unsubscribe();
        }
    }

    Item {
        id: placeholder
        anchors.fill: parent
        opacity: (root.hasLyrics || !root.showPlaceholder) ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        readonly property bool isLoading: LyricsService.status === "loading" || LyricsService.status === "idle"
        readonly property bool isNoTrack: LyricsService.status === "no_info"

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 260)
            spacing: 10

            MaterialLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: placeholder.isLoading
                loading: visible
                color: root.indicatorColor
                implicitSize: 30
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                visible: !placeholder.isLoading
                text: placeholder.isNoTrack ? "music_off" : "lyrics"
                iconSize: 28
                color: ColorUtils.applyAlpha(root.restColor, 0.55)
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(root.restColor, 0.85)
                text: placeholder.isLoading ? Translation.tr("Looking for lyrics")
                    : placeholder.isNoTrack ? Translation.tr("Nothing playing")
                    : Translation.tr("No synced lyrics for this track")
            }
        }
    }

    function splitIntoLines(str: string, maxW: real, pixelSz: real, measure: var): var {
        if (!str || str.length === 0)
            return ["♪"];
        const words = str.split(/\s+/);
        if (words.length <= 1)
            return [str];

        // Safe width per character for bold/demibold proportional typography
        const charW = Math.max(7.5, pixelSz * 0.64);
        const maxCharsPerLine = Math.max(12, Math.floor(maxW / charW));

        const lines = [];
        let currentLine = words[0];

        for (let i = 1; i < words.length; i++) {
            const word = words[i];
            const candidate = currentLine + " " + word;
            // Measured width when the caller can measure; the character estimate
            // otherwise.
            const fits = typeof measure === "function"
                ? measure(candidate) <= maxW
                : candidate.length <= maxCharsPerLine;
            if (fits) {
                currentLine = candidate;
            } else {
                lines.push(currentLine);
                currentLine = word;
            }
        }
        if (currentLine.length > 0)
            lines.push(currentLine);
        return lines;
    }

    function getSublineWeights(lines: var): var {
        if (!lines || lines.length === 0)
            return [];
        let totalChars = 0;
        for (let i = 0; i < lines.length; i++) {
            totalChars += Math.max(1, lines[i].length);
        }
        const ranges = [];
        let accum = 0;
        for (let i = 0; i < lines.length; i++) {
            const len = Math.max(1, lines[i].length);
            const start = accum / totalChars;
            accum += len;
            const end = accum / totalChars;
            ranges.push({ start: start, end: end });
        }
        return ranges;
    }

    Loader {
        anchors.fill: parent
        active: root.kinetic && root.hasLyrics
        visible: active
        sourceComponent: KineticLyrics {
            host: root
        }
    }

    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        opacity: root.hasLyrics && !root.kinetic ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Apple Music top and bottom edge gradient fade mask
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: viewport.width
                height: viewport.height
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.16; color: "black" }
                    GradientStop { position: 0.84; color: "black" }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }
        }

        property bool isUserScrolling: false
        property real manualScrollY: 0

        Timer {
            id: resyncTimer
            interval: 2000
            repeat: false
            onTriggered: {
                viewport.isUserScrolling = false;
            }
        }

        function handleUserScroll(deltaY: real): void {
            if (!root.hasLyrics)
                return;
            if (!viewport.isUserScrolling) {
                viewport.isUserScrolling = true;
                viewport.manualScrollY = lyricColumn.y;
            }
            const maxAllowedY = Math.round(viewport.height / 2 + 30);
            const minAllowedY = Math.min(maxAllowedY, Math.round(viewport.height / 2 - lyricColumn.height - 30));
            viewport.manualScrollY = Math.max(minAllowedY, Math.min(maxAllowedY, viewport.manualScrollY + deltaY * 0.7));
            resyncTimer.restart();
        }

        // ── Stage ─────────────────────────────────────────────────────────
        // Poster-style decorations built from the word being sung: a giant faded
        // copy behind everything, and a calligraphic copy over it. Both sit
        // behind the lines, so they colour the sheet without covering a lyric.
        Item {
            id: stage
            anchors.fill: parent
            z: -1
            visible: !!root.stageStyle && shownWord.length > 0

            property string shownWord: ""
            readonly property var giantStyle: root.stageStyle?.giant ?? null
            readonly property var accentStyle: root.stageStyle?.accent ?? null

            // Words change by dipping out and swelling back in, not by snapping.
            Connections {
                target: root
                function onStageWordChanged(): void {
                    if (!Appearance.animationsEnabled) {
                        stage.shownWord = root.stageWord;
                        return;
                    }
                    wordSwap.restart();
                }
            }
            SequentialAnimation {
                id: wordSwap
                NumberAnimation { target: stageWords; property: "opacity"; to: 0; duration: 90; easing.type: Easing.InQuad }
                ScriptAction { script: stage.shownWord = root.stageWord }
                ParallelAnimation {
                    NumberAnimation { target: stageWords; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                    NumberAnimation { target: stageWords; property: "scale"; from: 0.92; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }
            }

            Item {
                id: stageWords
                anchors.fill: parent

                StyledText {
                    visible: !!stage.giantStyle
                    anchors.centerIn: parent
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    text: stage.shownWord
                    renderType: Text.QtRendering
                    font.family: root.styleFont(stage.giantStyle?.font ?? "serif")
                    font.weight: stage.giantStyle?.weight ?? 800
                    font.capitalization: (stage.giantStyle?.uppercase ?? true) ? Font.AllUppercase : Font.MixedCase
                    fontSizeMode: Text.HorizontalFit
                    font.pixelSize: Math.round(parent.height * 0.6)
                    minimumPixelSize: 24
                    color: root.styleColor(stage.giantStyle?.color ?? "theme")
                    opacity: stage.giantStyle?.opacity ?? 0.1
                }

                StyledText {
                    visible: !!stage.accentStyle
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Math.round(parent.height * (stage.accentStyle?.offset ?? 0.12))
                    width: parent.width * 0.8
                    horizontalAlignment: Text.AlignHCenter
                    // Script reads as handwriting in lower case, the way the
                    // "baby" over "BABY" reference is set.
                    text: stage.shownWord.toLowerCase()
                    renderType: Text.QtRendering
                    font.family: root.styleFont(stage.accentStyle?.font ?? "script")
                    font.weight: Font.Normal
                    fontSizeMode: Text.HorizontalFit
                    font.pixelSize: Math.round(parent.height * (stage.accentStyle?.size ?? 0.3))
                    minimumPixelSize: 18
                    rotation: -6
                    color: root.styleColor(stage.accentStyle?.color ?? "theme")
                    opacity: stage.accentStyle?.opacity ?? 0.8
                    layer.enabled: !!stage.accentStyle?.glow && Appearance.effectsEnabled
                    layer.effect: GE.Glow {
                        radius: stage.accentStyle?.glow?.radius ?? 12
                        samples: 1 + 2 * Math.ceil(stage.accentStyle?.glow?.radius ?? 12)
                        spread: 0.0
                        color: root.styleColor(stage.accentStyle?.glow?.color ?? "theme")
                        transparentBorder: true
                    }
                }
            }
        }

        WheelHandler {
            target: null
            onWheel: event => {
                viewport.handleUserScroll(event.angleDelta.y);
            }
        }

        Column {
            id: lyricColumn
            width: Math.max(120, Math.floor((viewport.width - 24) / Math.max(1, root.activeScale)))
            x: root.textAlignment === Text.AlignHCenter
                ? Math.round((viewport.width - width) / 2)
                : root.textAlignment === Text.AlignRight
                    ? viewport.width - width - 12
                    : 12
            spacing: root.lineSpacing

            readonly property real syncedTargetY: {
                const count = lyricRepeater.count;
                if (count === 0)
                    return 0;
                const item = lyricRepeater.itemAt(Math.max(0, Math.min(root.activeIndex, count - 1)));
                if (!item)
                    return 0;
                return Math.round(viewport.height / 2 - (item.y + item.height / 2));
            }

            y: viewport.isUserScrolling ? viewport.manualScrollY : lyricColumn.syncedTargetY

            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                id: lyricRepeater
                model: LyricsService.lyricsLines

                delegate: Item {
                    id: lyricLineItem
                    required property int index
                    required property var modelData

                    readonly property int distance: Math.abs(index - root.activeIndex)
                    readonly property bool isActive: index === root.activeIndex
                    readonly property bool isPast: index < root.activeIndex

                    readonly property string rawText: (modelData.text && modelData.text.length > 0) ? modelData.text : "♪"
                    readonly property real lineStart: modelData.time ?? 0
                    readonly property real lineEnd: {
                        if (index + 1 < LyricsService.lyricsLines.length) {
                            const nextTime = LyricsService.lyricsLines[index + 1].time;
                            if (typeof nextTime === "number" && nextTime > lineStart)
                                return nextTime;
                        }
                        return lineStart + Math.max(2.0, rawText.length * 0.075 + 0.6);
                    }
                    readonly property real rawGap: Math.max(0.3, lineEnd - lineStart)
                    readonly property real estimatedVocalTime: Math.max(1.1, rawText.length * 0.065 + 0.45)
                    readonly property real lineDuration: rawGap <= 3.5
                        ? Math.max(0.3, Math.min(rawGap, Math.max(rawGap * 0.88, estimatedVocalTime * 0.95)))
                        : Math.min(rawGap, Math.max(estimatedVocalTime, rawGap * 0.60))
                    // Word-level providers give each word its own start and
                    // duration. Convert the word being sung into the fraction of
                    // the line's characters already passed, which is the same
                    // 0..1 the gradient sweep below already consumes — so real
                    // karaoke timing needs no change to the rendering at all.
                    readonly property var words: modelData.words ?? null
                    function wordProgress(pos: real): real {
                        const list = lyricLineItem.words;
                        let total = 0;
                        for (let i = 0; i < list.length; i++)
                            total += Math.max(1, (list[i].text ?? "").length);
                        if (total <= 0)
                            return 0.0;

                        let passed = 0;
                        for (let i = 0; i < list.length; i++) {
                            const word = list[i];
                            const length = Math.max(1, (word.text ?? "").length);
                            const start = word.t;
                            const span = Math.max(0.001, word.d > 0 ? word.d
                                : ((i + 1 < list.length ? list[i + 1].t : start + 0.35) - start));
                            if (pos < start)
                                break;
                            if (pos >= start + span) {
                                passed += length;
                                continue;
                            }
                            passed += length * ((pos - start) / span);
                            break;
                        }
                        return Math.max(0.0, Math.min(1.0, passed / total));
                    }

                    readonly property real lineProgress: isActive
                        ? (lyricLineItem.words && lyricLineItem.words.length > 0
                            ? lyricLineItem.wordProgress(LyricsService.currentPosition)
                            : Math.max(0.0, Math.min(1.0, (LyricsService.currentPosition - lineStart) / Math.max(0.05, lineDuration))))
                        : (isPast ? 1.0 : 0.0)

                    readonly property bool wordMode: lyricLineItem.words && lyricLineItem.words.length > 0

                    // Syllables joined into words ("cup"+"boards"), so a row can
                    // only ever wrap where the singer actually leaves a gap.
                    readonly property var wordGroups: {
                        if (!lyricLineItem.wordMode)
                            return [];
                        const groups = [];
                        let current = [];
                        const list = lyricLineItem.words;
                        for (let i = 0; i < list.length; i++) {
                            current.push(list[i]);
                            if (list[i].sp || i === list.length - 1) {
                                groups.push(current);
                                current = [];
                            }
                        }
                        return groups;
                    }

                    // Rows filled by measured width, so every profile wraps where
                    // its own glyphs actually run out of room.
                    readonly property var wordRows: {
                        if (!lyricLineItem.wordMode)
                            return [];
                        // Re-wrap when the metrics change, same reason as subLines.
                        void (lineMetrics.averageCharacterWidth + lineMetrics.height);
                        const maxW = lyricColumn.width;
                        const gap = Math.round(lyricLineItem.autoFontSize * 0.3);
                        const rows = [];
                        let row = [];
                        let used = 0;
                        const groups = lyricLineItem.wordGroups;
                        for (let i = 0; i < groups.length; i++) {
                            let text = "";
                            for (let j = 0; j < groups[i].length; j++)
                                text += groups[i][j].text ?? "";
                            const width = lyricLineItem.measure(text);
                            if (row.length > 0 && used + gap + width > maxW) {
                                rows.push(row);
                                row = [];
                                used = 0;
                            }
                            used += (row.length > 0 ? gap : 0) + width;
                            row.push(groups[i]);
                        }
                        if (row.length > 0)
                            rows.push(row);
                        return rows;
                    }

                    readonly property real autoFontSize: {
                        const base = root.baseSize;
                        const len = rawText.length;
                        let size = base;
                        if (len > 50)
                            size = Math.max(12, base - 2);
                        else if (len > 34)
                            size = Math.max(13, base - 1);
                        return Math.round(size * root.styleSize);
                    }

                    // Real glyph widths for wrapping. A character-count estimate
                    // was fine for the UI font but overflows wide poster capitals
                    // and underfills narrow scripts.
                    FontMetrics {
                        id: lineMetrics
                        font.family: root.lineFont
                        font.pixelSize: lyricLineItem.autoFontSize
                        font.weight: root.lineWeightFor(true)
                        font.letterSpacing: root.lineLetterSpacing
                    }
                    function measure(text: string): real {
                        // Measure what is drawn: capitals when the profile shouts.
                        return lineMetrics.advanceWidth(root.lineUppercase ? text.toUpperCase() : text) * 1.04;
                    }

                    readonly property var subLines: {
                        // measure() is a function call, which QML does not track, so
                        // depend on the metrics directly — otherwise a profile switch
                        // (or a font finishing loading) keeps the old font's wrap.
                        void (lineMetrics.averageCharacterWidth + lineMetrics.height);
                        return root.splitIntoLines(rawText, lyricColumn.width, autoFontSize,
                            text => lyricLineItem.measure(text));
                    }
                    readonly property var subWeights: root.getSublineWeights(subLines)

                    width: lyricColumn.width
                    height: (lyricLineItem.wordMode ? karaokeLoader.implicitHeight : subLinesCol.implicitHeight) + 4

                    transformOrigin: root.textAlignment === Text.AlignHCenter ? Item.Center
                        : root.textAlignment === Text.AlignRight ? Item.Right : Item.Left
                    scale: lyricLineItem.isActive
                        ? (lineMouseArea.pressed ? root.activeScale * 0.96 : root.activeScale)
                        : (lineMouseArea.pressed ? 0.97 : (lineMouseArea.containsMouse ? 1.03 : 1.0))

                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }

                    Column {
                        id: subLinesCol
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 2
                        visible: !lyricLineItem.wordMode
                        // Whole-line halo, drawn on the composed line so no inner clip
                        // can cut it into a box. Only the active line pays for it.
                        layer.enabled: lyricLineItem.isActive && !!root.lineGlowStyle && Appearance.effectsEnabled
                        layer.effect: GE.Glow {
                            radius: root.lineGlowStyle?.radius ?? 12
                            samples: 1 + 2 * Math.ceil(root.lineGlowStyle?.radius ?? 12)
                            spread: 0.0
                            color: root.lineGlowColor
                            transparentBorder: true
                        }

                        Repeater {
                            model: lyricLineItem.subLines

                            delegate: Item {
                                id: subLineItem
                                required property int index
                                required property string modelData

                                readonly property var weightRange: (lyricLineItem.subWeights && lyricLineItem.subWeights[index])
                                    ? lyricLineItem.subWeights[index]
                                    : ({ start: index / Math.max(1, lyricLineItem.subLines.length), end: (index + 1) / Math.max(1, lyricLineItem.subLines.length) })
                                readonly property real subStart: weightRange.start
                                readonly property real subEnd: weightRange.end
                                readonly property real subProgress: lyricLineItem.isActive
                                    ? Math.max(0.0, Math.min(1.0, (lyricLineItem.lineProgress - subStart) / Math.max(0.001, subEnd - subStart)))
                                    : (lyricLineItem.isPast ? 1.0 : 0.0)

                                width: subLinesCol.width
                                height: Math.ceil(Math.max(subLineInactive.implicitHeight, subLineMask.implicitHeight) + 2)

                                // Text mask for this specific subline (bounded to exact text width)
                                StyledText {
                                    id: subLineMask
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: root.lineFont
                                    font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                    font.letterSpacing: root.lineLetterSpacing
                                    font.pixelSize: lyricLineItem.autoFontSize
                                    font.weight: root.lineWeightFor(lyricLineItem.isActive)
                                    visible: false
                                }

                                // Neon-tube echo for line-timed lyrics, revealed with the sweep so it
                                // only trails what has already been sung.
                                Item {
                                    visible: root.outlineEcho && lyricLineItem.isActive && subLineItem.subProgress > 0.001
                                    x: Math.round((parent.width - subLineMask.implicitWidth) / 2)
                                    y: Math.round((parent.height - subLineMask.implicitHeight) / 2)
                                    width: Math.round(subLineMask.implicitWidth * subLineItem.subProgress) + (root.style.outline?.dx ?? 5) + 2
                                    height: subLineMask.implicitHeight + (root.style.outline?.dy ?? 4) + 2
                                    clip: true

                                StyledText {
                                    x: root.style.outline?.dx ?? 5
                                    y: root.style.outline?.dy ?? 4
                                    text: modelData
                                    font.family: root.lineFont
                                    font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                    font.letterSpacing: root.lineLetterSpacing
                                    font.pixelSize: lyricLineItem.autoFontSize
                                    font.weight: root.lineWeightFor(true)
                                    color: "transparent"
                                    style: Text.Outline
                                    styleColor: root.styleColor(root.style.outline?.color ?? "theme")
                                    opacity: root.style.outline?.opacity ?? 0.5
                                }
                                }

                                // Inactive dimmed layer
                                StyledText {
                                    id: subLineInactive
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: root.lineFont
                                    font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                    font.letterSpacing: root.lineLetterSpacing
                                    font.pixelSize: lyricLineItem.autoFontSize
                                    font.weight: root.lineWeightFor(false)
                                    color: lyricLineItem.isPast ? root.sungColor : root.restColor

                                    opacity: {
                                        if (lyricLineItem.isActive)
                                            return 0.0;
                                        // Keep all lines in the song visible and readable with smooth resting opacity
                                        return Math.max(0.30, 0.48 - Math.min(lyricLineItem.distance, 4) * 0.04);
                                    }

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                // Active line progressive gradient sweep matching exact text bounding box
                                Item {
                                    id: subLineActiveGradient
                                    anchors.centerIn: parent
                                    width: subLineMask.implicitWidth
                                    height: subLineMask.implicitHeight
                                    opacity: lyricLineItem.isActive ? 1.0 : 0.0
                                    visible: opacity > 0.01

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }

                                    layer.enabled: opacity > 0.01
                                    layer.effect: GE.OpacityMask {
                                        maskSource: subLineMask
                                    }

                                    Rectangle {
                                        anchors.fill: parent

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop {
                                                position: 0.0
                                                color: subLineItem.subProgress > 0.01 ? root.sungColor : Qt.rgba(root.restColor.r, root.restColor.g, root.restColor.b, root.activeRestAlpha >= 0 ? root.activeRestAlpha : 0.25)
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress - 0.06))
                                                color: root.sungColor
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress))
                                                color: subLineItem.subProgress > 0.001 ? "#FFFFFF" : Qt.rgba(root.restColor.r, root.restColor.g, root.restColor.b, root.activeRestAlpha >= 0 ? root.activeRestAlpha : 0.25)
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress + 0.05))
                                                color: Qt.rgba(root.restColor.r, root.restColor.g, root.restColor.b, root.activeRestAlpha >= 0 ? root.activeRestAlpha : 0.25)
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: Qt.rgba(root.restColor.r, root.restColor.g, root.restColor.b, root.activeRestAlpha >= 0 ? root.activeRestAlpha : 0.25)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Syllable path: each syllable fills as it is sung, lifts and
                    // swells on its onset, then settles — the per-word motion the
                    // plain gradient sweep cannot express.
                    Loader {
                        id: karaokeLoader
                        anchors.centerIn: parent
                        width: parent.width
                        active: lyricLineItem.wordMode
                        visible: active
                        // Whole-line halo, drawn on the composed line so no inner clip
                        // can cut it into a box. Only the active line pays for it.
                        layer.enabled: lyricLineItem.isActive && !!root.lineGlowStyle && Appearance.effectsEnabled
                        layer.effect: GE.Glow {
                            radius: root.lineGlowStyle?.radius ?? 12
                            samples: 1 + 2 * Math.ceil(root.lineGlowStyle?.radius ?? 12)
                            spread: 0.0
                            color: root.lineGlowColor
                            transparentBorder: true
                        }
                        sourceComponent: Column {
                            spacing: 2
                            width: karaokeLoader.width

                            Repeater {
                                model: lyricLineItem.wordRows

                                delegate: Row {
                                    id: karaokeRow
                                    required property var modelData
                                    spacing: Math.round(lyricLineItem.autoFontSize * 0.3)
                                    x: root.textAlignment === Text.AlignHCenter
                                        ? Math.round((karaokeLoader.width - width) / 2)
                                        : root.textAlignment === Text.AlignRight
                                            ? karaokeLoader.width - width
                                            : 0

                                    Repeater {
                                        model: karaokeRow.modelData

                                        delegate: Item {
                                            // One item per *word*, filled by its syllables' timings.
                                            // Drawing syllables separately broke connected scripts
                                            // ("A nother") and letter spacing across syllable joins.
                                            id: syllable
                                            required property var modelData
                                            readonly property string wordText: {
                                                let out = "";
                                                for (let i = 0; i < modelData.length; i++)
                                                    out += modelData[i].text ?? "";
                                                return out;
                                            }
                                            readonly property real progress: {
                                                if (lyricLineItem.isPast)
                                                    return 1.0;
                                                if (!lyricLineItem.isActive)
                                                    return 0.0;
                                                const pos = LyricsService.currentPosition;
                                                let total = 0;
                                                for (let i = 0; i < modelData.length; i++)
                                                    total += Math.max(1, (modelData[i].text ?? "").length);
                                                let passed = 0;
                                                for (let i = 0; i < modelData.length; i++) {
                                                    const part = modelData[i];
                                                    const length = Math.max(1, (part.text ?? "").length);
                                                    const span = Math.max(0.05, (part.d ?? 0) > 0 ? part.d : 0.3);
                                                    if (pos < part.t)
                                                        break;
                                                    if (pos >= part.t + span) {
                                                        passed += length;
                                                        continue;
                                                    }
                                                    passed += length * ((pos - part.t) / span);
                                                    break;
                                                }
                                                return Math.max(0.0, Math.min(1.0, passed / Math.max(1, total)));
                                            }
                                            // Only the word being sung right now gets the lift and the glow.
                                            readonly property bool singing: lyricLineItem.isActive
                                                && progress > 0.0 && progress < 1.0

                                            implicitWidth: syllableBase.implicitWidth
                                            implicitHeight: syllableBase.implicitHeight
                                            width: implicitWidth
                                            height: implicitHeight

                                            // Kept small: syllables sit inside words, and a bigger lift
                                            // reads as superscript ("ig" + raised "no" + "ring").
                                            transformOrigin: Item.Bottom
                                            scale: singing ? 1.04 : 1.0
                                            y: singing ? -1 : 0

                                            Behavior on scale {
                                                enabled: Appearance.animationsEnabled
                                                NumberAnimation {
                                                    duration: 260
                                                    easing.type: Easing.OutBack
                                                    easing.overshoot: 2.4
                                                }
                                            }
                                            Behavior on y {
                                                enabled: Appearance.animationsEnabled
                                                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                                            }

                                            StyledText {
                                                anchors.fill: syllableBase
                                                text: syllable.wordText
                                                font.family: root.lineFont
                                                font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                                font.letterSpacing: root.lineLetterSpacing
                                                // The active line is scaled 1.18x; native glyphs are rasterized
                                                // at 1:1 and pixelate when stretched, distance-field ones do not.
                                                renderType: Text.QtRendering
                                                font.pixelSize: lyricLineItem.autoFontSize
                                                font.weight: root.lineWeightFor(true)
                                                color: root.glowColor
                                                opacity: (syllable.singing && root.glowStyle) ? (root.glowStyle.strength ?? 0.55) : 0.0
                                                visible: opacity > 0.01 && Appearance.effectsEnabled
                                                Behavior on opacity {
                                                    enabled: Appearance.animationsEnabled
                                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                                }
                                                layer.enabled: visible
                                                layer.effect: GE.Glow {
                                                    radius: root.glowStyle?.radius ?? 7
                                                    samples: 1 + 2 * Math.ceil(root.glowStyle?.radius ?? 7)
                                                    spread: 0.0
                                                    color: root.glowColor
                                                    transparentBorder: true
                                                }
                                            }

                                            // Neon-tube echo: an offset outline behind the word, revealed with the
                                            // fill so it never sits over words still to come — over those it
                                            // outshone the text and made it unreadable.
                                            Item {
                                                visible: root.outlineEcho && lyricLineItem.isActive && syllable.progress > 0.001
                                                width: Math.round(syllable.width * syllable.progress) + (root.style.outline?.dx ?? 5) + 2
                                                height: syllable.height + (root.style.outline?.dy ?? 4) + 2
                                                clip: true

                                            StyledText {
                                                x: root.style.outline?.dx ?? 5
                                                y: root.style.outline?.dy ?? 4
                                                text: syllable.wordText
                                                font.family: root.lineFont
                                                font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                                font.letterSpacing: root.lineLetterSpacing
                                                renderType: Text.QtRendering
                                                font.pixelSize: lyricLineItem.autoFontSize
                                                font.weight: root.lineWeightFor(lyricLineItem.isActive)
                                                color: "transparent"
                                                style: Text.Outline
                                                styleColor: root.styleColor(root.style.outline?.color ?? "theme")
                                                opacity: root.style.outline?.opacity ?? 0.5
                                            }
                                            }

                                            StyledText {
                                                id: syllableBase
                                                text: syllable.wordText
                                                font.family: root.lineFont
                                                font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                                font.letterSpacing: root.lineLetterSpacing
                                                // The active line is scaled 1.18x; native glyphs are rasterized
                                                // at 1:1 and pixelate when stretched, distance-field ones do not.
                                                renderType: Text.QtRendering
                                                font.pixelSize: lyricLineItem.autoFontSize
                                                font.weight: root.lineWeightFor(lyricLineItem.isActive)
                                                color: lyricLineItem.isPast
                                                    ? root.sungColor
                                                    : Qt.rgba(root.restColor.r, root.restColor.g, root.restColor.b,
                                                        (lyricLineItem.isActive && root.activeRestAlpha >= 0) ? root.activeRestAlpha : root.restAlpha)
                                                // Sung lines recede by distance like the plain path,
                                                // so only the active line reads at full strength.
                                                opacity: lyricLineItem.isActive
                                                    ? 1.0
                                                    : Math.max(0.30, 0.48 - Math.min(lyricLineItem.distance, 4) * 0.04)
                                            }

                                            // The sung part, revealed left to right within the syllable itself.
                                            Item {
                                                width: Math.round(syllable.width * syllable.progress)
                                                height: syllable.height
                                                clip: true
                                                visible: syllable.progress > 0.001
                                                opacity: syllableBase.opacity

                                                StyledText {
                                                    width: syllable.width
                                                    text: syllable.wordText
                                                    font.family: root.lineFont
                                                    font.capitalization: root.lineUppercase ? Font.AllUppercase : Font.MixedCase
                                                    font.letterSpacing: root.lineLetterSpacing
                                                    // The active line is scaled 1.18x; native glyphs are rasterized
                                                    // at 1:1 and pixelate when stretched, distance-field ones do not.
                                                    renderType: Text.QtRendering
                                                    font.pixelSize: lyricLineItem.autoFontSize
                                                    font.weight: root.lineWeightFor(lyricLineItem.isActive)
                                                    color: syllable.singing ? root.singingColor : root.sungColor
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: lineMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            viewport.isUserScrolling = false;
                            resyncTimer.stop();
                            if (modelData.time !== undefined) {
                                LyricsService.seekToTime(modelData.time);
                            }
                        }
                        onWheel: wheel => {
                            viewport.handleUserScroll(wheel.angleDelta.y);
                            wheel.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
