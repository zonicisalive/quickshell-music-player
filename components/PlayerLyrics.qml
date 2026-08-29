pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import "../common"
import "../common"
import "../common"
import "../services"

Item {
    id: root

    property color textColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    property color activeColor: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property int textAlignment: Text.AlignHCenter
    property int lineSpacing: 12

    property int baseSize: Appearance.font.pixelSize.normal
    property real activeScale: 1.18
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
                color: ColorUtils.applyAlpha(root.textColor, 0.55)
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(root.textColor, 0.85)
                text: placeholder.isLoading ? Translation.tr("Looking for lyrics")
                    : placeholder.isNoTrack ? Translation.tr("Nothing playing")
                    : Translation.tr("No synced lyrics for this track")
            }
        }
    }

    function splitIntoLines(str: string, maxW: real, pixelSz: real): var {
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
            if ((currentLine.length + 1 + word.length) <= maxCharsPerLine) {
                currentLine += " " + word;
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

    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        opacity: root.hasLyrics ? 1 : 0
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
                    readonly property real lineProgress: isActive
                        ? Math.max(0.0, Math.min(1.0, (LyricsService.currentPosition - lineStart) / Math.max(0.05, lineDuration)))
                        : (isPast ? 1.0 : 0.0)

                    readonly property real autoFontSize: {
                        const base = root.baseSize;
                        const len = rawText.length;
                        if (len > 50)
                            return Math.max(12, base - 2);
                        if (len > 34)
                            return Math.max(13, base - 1);
                        return base;
                    }

                    readonly property var subLines: root.splitIntoLines(rawText, lyricColumn.width, autoFontSize)
                    readonly property var subWeights: root.getSublineWeights(subLines)

                    width: lyricColumn.width
                    height: subLinesCol.implicitHeight + 4

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
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: lyricLineItem.autoFontSize
                                    font.weight: lyricLineItem.isActive ? Font.Bold : Font.DemiBold
                                    visible: false
                                }

                                // Inactive dimmed layer
                                StyledText {
                                    id: subLineInactive
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: lyricLineItem.autoFontSize
                                    font.weight: Font.DemiBold
                                    color: lyricLineItem.isPast ? root.activeColor : root.textColor

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
                                                color: subLineItem.subProgress > 0.01 ? root.activeColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress - 0.06))
                                                color: root.activeColor
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress))
                                                color: subLineItem.subProgress > 0.001 ? "#FFFFFF" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
                                            }
                                            GradientStop {
                                                position: Math.max(0.0, Math.min(1.0, subLineItem.subProgress + 0.05))
                                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
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
