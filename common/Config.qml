pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property var options: ({
        media: {
            filterDuplicatePlayers: true,
            // Look of the lyric sheet; see components/lyricsProfiles.js. The lyrics
            // button cycles through them on a double-click.
            lyricsStyle: "reel",
            lyricsCustomStyle: ({})
        },
        background: {
            widgets: {
                mediaControls: {
                    lyricsExpanded: false,
                    visualizerType: "wave",
                    visualizerPosition: "bottom"
                }
            }
        }
    })

    property bool ready: true
    // Bumped on every change, so bindings that read settings re-evaluate.
    property int revision: 0
    signal configChanged()

    function getNestedValue(path: string, defaultValue: var): var {
        void root.revision;
        const parts = path.split(".");
        let curr = root.options;
        for (const p of parts) {
            if (curr && typeof curr === "object" && p in curr) {
                curr = curr[p];
            } else {
                return defaultValue;
            }
        }
        return curr !== undefined ? curr : defaultValue;
    }

    function setNestedValue(path: string, value: var): void {
        const parts = path.split(".");
        let curr = root.options;
        for (let i = 0; i < parts.length - 1; i++) {
            const p = parts[i];
            if (!(p in curr) || typeof curr[p] !== "object") {
                curr[p] = {};
            }
            curr = curr[p];
        }
        curr[parts[parts.length - 1]] = value;
        // The object was changed in place; tell the bindings that read it.
        root.revision++;
        root.optionsChanged();
        root.configChanged();
    }
}
