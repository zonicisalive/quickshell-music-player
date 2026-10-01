pragma ComponentBehavior: Bound
import QtQuick
import "../common"
import "../common"
import "../common"

/**
 * PlayerProgress - Reusable progress bar/slider
 */
Item {
    id: root
    
    // Required properties
    required property real position
    required property real length
    required property bool canSeek
    required property bool isPlaying
    
    // Optional properties
    property color highlightColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
        : Appearance.inirEverywhere
        ? Appearance.inir.colPrimary 
        : Appearance.colors.colPrimary
    property color trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
        : Appearance.inirEverywhere
        ? Appearance.inir.colLayer2 
        : Appearance.colors.colSecondaryContainer
    property bool enableWavy: true
    property bool scrollable: true
    
    // Signals
    signal seekRequested(real seconds)
    
    readonly property real progressValue: length > 0
        ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property bool waveAnimationActive: root.enableWavy && root.isPlaying
        && root.visible && Appearance.animationsEnabled

    // Track whether we're in a user-interaction grace period
    property bool _userSeeking: false
    // Where the handle is: the dragged-to time during a seek, the real
    // position otherwise. Bind time labels to this so they move with the drag.
    property real previewPosition: root.position

    Timer {
        id: seekGraceTimer
        interval: 1000
        repeat: false
        onTriggered: root._userSeeking = false
    }

    // Seekable slider
    Loader {
        anchors.fill: parent
        active: root.canSeek
        sourceComponent: StyledSlider {
            id: sliderItem
            configuration: root.enableWavy ? StyledSlider.Configuration.Wavy : StyledSlider.Configuration.S
            trackWidth: root.enableWavy ? 2 : StyledSlider.Configuration.S
            handleHeight: Math.min(14, root.height)
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.waveAnimationActive
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            handleColor: root.highlightColor
            // value is driven only by the Binding below. A direct binding here
            // would come back every time that Binding pauses for a drag, and
            // then each position update snapped the handle back under the
            // cursor — the flicker on the wavy line.
            scrollable: root.scrollable
            // The time label beside the bar follows the drag, so the moving
            // percentage popup only costs frames here.
            showTooltip: false

            // Seek once when the drag ends, not on every pixel of it. Each seek
            // runs a playerctl process and makes the player jump and re-buffer,
            // so seeking per move turned a drag into dozens of them — the lag.
            onMoved: {
                root._userSeeking = true;
                seekGraceTimer.restart();
                // Wheel and keyboard nudges have no release; settle those instead.
                if (!sliderItem.pressed)
                    settleSeek.restart();
            }
            onPressedChanged: {
                if (sliderItem.pressed)
                    return;
                root._userSeeking = true;
                seekGraceTimer.restart();
                settleSeek.stop();
                root.seekRequested(sliderItem.value * root.length);
            }
            Timer {
                id: settleSeek
                interval: 180
                onTriggered: root.seekRequested(sliderItem.value * root.length)
            }
            // Lets the time label follow the handle while it is being dragged.
            Binding {
                target: root
                property: "previewPosition"
                value: sliderItem.value * root.length
                when: sliderItem.pressed || root._userSeeking
            }

            // Only push external progress updates when user is NOT interacting
            Binding {
                target: sliderItem
                property: "value"
                value: root.progressValue
                when: !sliderItem.pressed && !root._userSeeking
                // While dragging, leave the value where the user put it.
                restoreMode: Binding.RestoreNone
            }
        }
    }
    
    // Non-seekable progress bar
    Loader {
        anchors.fill: parent
        active: !root.canSeek
        sourceComponent: StyledProgressBar {
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.waveAnimationActive
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            value: root.progressValue
        }
    }
}
