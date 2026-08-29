pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

Singleton {
    id: root

    property bool animationsEnabled: true
    property real fontSizeScale: 1.0

    // Design Tokens - Colors (Material 3 Dark by default, adapts to album art)
    readonly property var colors: ({
        colPrimary: "#a5d0bb",
        colPrimaryHover: "#bfe3d0",
        colPrimaryActive: "#8cbfa6",
        colPrimaryContainer: "#2d4a3e",
        colOnPrimary: "#122019",
        colOnPrimaryContainer: "#c8ecd7",
        colSecondary: "#b9cac0",
        colSecondaryContainer: "#3b4a43",
        colOnSecondary: "#25342d",
        colOnSecondaryContainer: "#a8b9af",
        colLayer0: "#131614",
        colOnLayer0: "#e2e2e0",
        colLayer1: "#1a1c1b",
        colOnLayer1: "#e2e2e0",
        colLayer2: "#282a29",
        colSubtext: "#a0a4a0",
        colSurface: "#131614",
        colOnSurface: "#e2e2e0",
        colSurfaceContainer: "#1e201f",
        colSurfaceContainerHigh: "#282a29",
        colSurfaceContainerHighest: "#333534",
        colOutline: "#8d928d",
        colOutlineVariant: "#434844",
        colShadow: "#000000",
        colScrim: "#80000000"
    })

    // Inir fixed color palette compatibility
    readonly property var inir: ({
        colText: "#e2e2e0",
        colTextSecondary: "#a0a4a0",
        colPrimary: "#a5d0bb",
        colOnPrimary: "#122019",
        colLayer1: "#1a1c1b",
        colLayer2: "#282a29",
        colBorder: "rgba(255, 255, 255, 0.1)",
        roundingNormal: 18,
        roundingLarge: 24
    })

    readonly property var m3colors: ({
        m3primary: root.colors.colPrimary,
        darkmode: true
    })

    // Corner Rounding Tokens
    readonly property var rounding: ({
        none: 0,
        small: 8,
        normal: 14,
        large: 20,
        verylarge: 26,
        full: 9999,
        screenRounding: 18
    })

    // Sizing Tokens
    readonly property var sizes: ({
        elevationMargin: 0,
        hyprlandGapsOut: 8
    })

    // Typography Metrics
    readonly property var font: ({
        family: {
            main: "sans-serif",
            numbers: "sans-serif",
            monospace: "monospace",
            icons: "Material Symbols Outlined, Material Symbols Rounded, Material Icons, sans-serif"
        },
        pixelSize: {
            smaller: Math.round(11 * root.fontSizeScale),
            small: Math.round(12 * root.fontSizeScale),
            normal: Math.round(14 * root.fontSizeScale),
            larger: Math.round(16 * root.fontSizeScale),
            huge: Math.round(22 * root.fontSizeScale)
        }
    })

    // Easing Animation Curves
    readonly property var animationCurves: ({
        emphasizedDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0],
        emphasizedAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0],
        standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    })

    readonly property var animation: ({
        elementMoveFast: {
            duration: 200,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        },
        elementResize: {
            duration: 350,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        }
    })

    // Worldview & Style compatibility flags
    readonly property bool zzzEverywhere: false
    readonly property bool inirEverywhere: false
    readonly property bool angelEverywhere: false
    readonly property bool auroraEverywhere: false
    readonly property bool cookieEverywhere: false
    readonly property bool effectsEnabled: true
    readonly property bool gameModeMinimal: false
}
