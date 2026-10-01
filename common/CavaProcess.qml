import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum for Reel's beat reaction, from a cava process of its own.
// `points` holds 0..1000 per band, lowest frequencies first (mono). Without
// cava installed it stays empty and Reel simply doesn't react to beats.
Item {
    id: root

    property bool active: false
    property var points: []

    Process {
        running: root.active
        command: ["bash", "-c",
            "command -v cava >/dev/null || exit 0; "
            + "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-music-player-cava.conf\"; "
            + "printf '[general]\\nframerate = 60\\nbars = 16\\nautosens = 1\\n"
            + "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\n"
            + "ascii_max_range = 1000\\nchannels = mono\\n[smoothing]\\nnoise_reduction = 20\\n' > \"$cfg\"; "
            + "exec cava -p \"$cfg\""]
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(parseFloat).filter(value => !isNaN(value));
            }
        }
        onRunningChanged: if (!running) root.points = []
    }
}
