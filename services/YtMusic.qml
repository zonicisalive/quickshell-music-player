pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    property MprisPlayer mpvPlayer: null
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property real currentPosition: 0
    property real currentDuration: 0
    property bool isPlaying: false
    property bool canSeek: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property string currentVideoId: ""
    
    function togglePlaying(): void {}
    function playPrevious(): void {}
    function playNext(): void {}
    function seek(seconds: real): void {}
}
