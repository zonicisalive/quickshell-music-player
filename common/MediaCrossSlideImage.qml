pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

// Direction-aware cross-slide cover art. On `source` change the incoming art
// slides in from one side while the outgoing art slides out the other:
//   slideDirection +1 (next/forward) → new enters from the right, old exits left
//   slideDirection -1 (previous)      → new enters from the left, old exits right
// One semantic surface with two layers — legitimate here because two distinct
// cover arts are genuinely different content (carries the same intent as the
// blur-swap it replaces, but reads as "one leaves, one enters" side-to-side).
// Reusable so every media surface (popups, sidebar, action center) stays in sync.
Rectangle {
    id: root

    property string source: ""
    property string transitionKey: source
    property int slideDirection: 1            // +1 forward, -1 backward
    property bool downloaded: true
    property color placeholderColor: Appearance.colors.colLayer1
    property color iconColor: Appearance.colors.colSubtext
    property int iconSize: 32
    property real artRadius: Appearance.rounding.small
    property bool effectEnabled: false
    property bool blurEnabled: false
    property real blur: 0
    property real blurMax: 32
    property real saturation: 1
    property bool animateChanges: true

    radius: artRadius
    color: "transparent"
    clip: true

    layer.enabled: true
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    property string _prevSrc: ""
    property string _prevKey: ""
    property string _pendingSrc: ""
    property string _pendingKey: ""
    property bool _waitingForReady: false

    function _resetLiveGeometry(): void {
        liveLayer.x = 0
        liveLayer.opacity = 1
    }

    function _showFirstSource(src: string, key: string): void {
        slide.stop()
        outLayer.visible = false
        outLayer.source = ""
        root._pendingSrc = ""
        root._pendingKey = ""
        root._waitingForReady = false
        liveLayer.source = src
        liveLayer.visible = true
        root._resetLiveGeometry()
        root._prevSrc = src
        root._prevKey = key
    }

    function _startTransitionWhenReady(): void {
        if (!root._waitingForReady || !root._pendingSrc.length)
            return

        if (liveLayer.status !== Image.Ready) {
            return
        }

        root._waitingForReady = false
        liveLayer.visible = true
        root._prevSrc = root._pendingSrc
        root._prevKey = root._pendingKey
        root._pendingSrc = ""
        root._pendingKey = ""

        if (Appearance.animationsEnabled) {
            slide.dir = root.slideDirection
            slide.restart()
        } else {
            root._resetLiveGeometry()
            outLayer.visible = false
            outLayer.source = ""
        }
    }

    // Live (incoming) cover. No binding on `source` — set imperatively so the
    // transition handler fully controls when the new art appears.
    Image {
        id: liveLayer
        width: root.width
        height: root.height
        x: 0
        y: 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: false
        // Players ship cover art at native resolution (often 1000px+). Bound the
        // decode to what is actually drawn, or every track change allocates the
        // full bitmap twice (live + outgoing snapshot).
        sourceSize.width: Math.max(1, Math.round(root.width * 2))
        sourceSize.height: Math.max(1, Math.round(root.height * 2))
        onStatusChanged: root._startTransitionWhenReady()
        layer.enabled: root.effectEnabled
        layer.effect: MultiEffect {
            blurEnabled: root.blurEnabled
            blur: root.blur
            blurMax: root.blurMax
            saturation: root.saturation
        }
    }

    // Snapshot of the previous art, only visible during a transition.
    Image {
        id: outLayer
        width: root.width
        height: root.height
        x: 0
        y: 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: false
        sourceSize.width: Math.max(1, Math.round(root.width * 2))
        sourceSize.height: Math.max(1, Math.round(root.height * 2))
        layer.enabled: root.effectEnabled
        layer.effect: MultiEffect {
            blurEnabled: root.blurEnabled
            blur: root.blur
            blurMax: root.blurMax
            saturation: root.saturation
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.placeholderColor
        visible: !root.downloaded

        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            iconSize: root.iconSize
            color: root.iconColor
        }
    }

    // Explicit from/to animations so the start position (off-screen) is honored
    // instantly — a Behavior on x would animate the reset-to-start as well.
    ParallelAnimation {
        id: slide
        property int dir: root.slideDirection

        NumberAnimation {
            target: liveLayer
            property: "x"
            from: slide.dir * root.width
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            target: liveLayer
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            target: outLayer
            property: "x"
            from: 0
            to: -slide.dir * root.width
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            target: outLayer
            property: "opacity"
            from: 1
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        onStopped: {
            outLayer.visible = false
            outLayer.source = ""
            root._resetLiveGeometry()
        }
    }

    function _handleSourceChange(): void {
        const src = root.source
        const key = (root.transitionKey && root.transitionKey.length > 0) ? root.transitionKey : src
        if (!src || src === "") {
            if (root._prevSrc.length > 0) {
                return
            }
            slide.stop()
            liveLayer.source = ""
            liveLayer.visible = false
            outLayer.visible = false
            outLayer.source = ""
            root._prevSrc = ""
            root._prevKey = ""
            root._pendingSrc = ""
            root._pendingKey = ""
            root._waitingForReady = false
            root._resetLiveGeometry()
            return
        }
        // First ever set: just show, no slide
        if (root._prevSrc === "" || !liveLayer.source || !liveLayer.source.toString()) {
            root._showFirstSource(src, key)
            return
        }
        if (src === root._prevSrc)
            return
        if (!root.animateChanges) {
            slide.stop()
            outLayer.visible = false
            outLayer.source = ""
            liveLayer.source = src
            liveLayer.visible = true
            root._resetLiveGeometry()
            root._prevSrc = src
            root._prevKey = key
            return
        }
        if (key === root._prevKey) {
            root._pendingSrc = ""
            root._pendingKey = ""
            root._waitingForReady = false
            return
        }
        // Snapshot previous art into the outgoing layer, load the new art in the
        // live layer, then cross-slide only once the incoming image is ready.
        slide.stop()
        outLayer.source = root._prevSrc
        outLayer.x = 0
        outLayer.opacity = 1
        outLayer.visible = true
        liveLayer.visible = false
        liveLayer.source = src
        liveLayer.x = root.slideDirection * root.width
        liveLayer.opacity = 0
        root._pendingSrc = src
        root._pendingKey = key
        root._waitingForReady = true
        root._startTransitionWhenReady()
    }

    onSourceChanged: root._handleSourceChange()
}
