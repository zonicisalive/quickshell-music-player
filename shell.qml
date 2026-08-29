//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import "components"
import "presets"
import "services"
import "common"

ShellRoot {
    id: root

    PanelWindow {
        id: playerWindow
        visible: true

        anchors.top: true
        anchors.right: true
        margins.top: 40
        margins.right: 40

        implicitWidth: playerWidget.width
        implicitHeight: playerWidget.height
        color: "transparent"

        readonly property MprisPlayer activePlayer: MprisController.activePlayer

        ExpandingLyricsPlayer {
            id: playerWidget
            player: playerWindow.activePlayer
            width: 420
            height: lyricsExpanded ? 380 : 144

            Behavior on height {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
