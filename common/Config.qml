pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

Singleton {
    id: root

    property var options: ({
        media: {
            filterDuplicatePlayers: true
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

    function getNestedValue(path: string, defaultValue: var): var {
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
    }
}
