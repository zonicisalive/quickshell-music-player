pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

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
        colSecondaryContainerHover: "#465650",
        colSecondaryContainerActive: "#52625b",
        colOnSecondary: "#25342d",
        colOnSecondaryContainer: "#a8b9af",
        colLayer0: "#131614",
        colOnLayer0: "#e2e2e0",
        colLayer1: "#1a1c1b",
        colOnLayer1: "#e2e2e0",
        colLayer2: "#282a29",
        colLayer3: "#333534",
        colLayer3Hover: "#3d3f3e",
        colLayer0Base: "#131614",
        colLayer1Hover: "#222423",
        colLayer1Active: "#2a2c2b",
        colOnLayer3: "#e2e2e0",
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
        verysmall: 6,
        unsharpen: 2,
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
            icons: "Material Symbols Outlined, Material Symbols Rounded, Material Icons, sans-serif",
            title: "sans-serif"
        },
        variableAxes: {
            main: ({}),
            numbers: ({})
        },
        pixelSize: {
            smallest: Math.round(10 * root.fontSizeScale),
            smaller: Math.round(11 * root.fontSizeScale),
            small: Math.round(12 * root.fontSizeScale),
            normal: Math.round(14 * root.fontSizeScale),
            large: Math.round(15 * root.fontSizeScale),
            larger: Math.round(16 * root.fontSizeScale),
            huge: Math.round(22 * root.fontSizeScale)
        }
    })

    // Easing Animation Curves
    readonly property var animationCurves: ({
        emphasizedDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0],
        emphasizedAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0],
        standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0],
        standardDecel: [0, 0, 0, 1, 1, 1],
        expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1.0, 1.0]
    })

    readonly property var animation: ({
        elementMoveFast: {
            duration: 200,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        },
        elementMove: {
            duration: 500,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        },
        elementMoveEnter: {
            duration: 400,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        },
        stateChange: {
            duration: 200,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.standard
        },
        elementResize: {
            duration: 350,
            type: Easing.BezierSpline,
            bezierCurve: root.animationCurves.emphasizedDecel
        }
    })

    // Token groups for the shell's other global styles. They are switched off
    // here (see the flags below), but the shared widgets still read them, so
    // they need real values.
    readonly property var zzz: ({
        accent: root.colors.colPrimary, accentSoft: root.colors.colPrimaryContainer,
        bg: root.colors.colLayer0, paper: root.colors.colLayer1, paperAlt: root.colors.colLayer2,
        ink: root.colors.colOnLayer1, inkMuted: root.colors.colSubtext, ghostInk: root.colors.colOutlineVariant,
        onColor: root.colors.colOnPrimary, onMuted: root.colors.colSubtext,
        sticker: root.colors.colPrimary, onSticker: root.colors.colOnPrimary,
        signal: "#ffb4ab", posterCool: root.colors.colSecondary,
        hairlineStrong: root.colors.colOutline, metricFill: root.colors.colPrimary, metricTrack: root.colors.colLayer2,
        technicalGrid: root.colors.colOutlineVariant, technicalGridStrong: root.colors.colOutline,
        technicalMarker: root.colors.colPrimary, technicalWarning: "#ffb4ab",
        registrationMark: root.colors.colOutline, registrationMarkAlt: root.colors.colOutlineVariant,
        registrationRail: root.colors.colOutlineVariant, diagonalStripe: root.colors.colOutlineVariant,
        borderThick: 2, controlRadius: 10, cornerRadius: 12, panelRadius: 18, cutCorner: 10,
        markerLength: 8, markerThickness: 2, overshootDuration: 300, useDiagonals: false
    })
    readonly property var angel: ({
        colPrimary: root.colors.colPrimary, colOnPrimary: root.colors.colOnPrimary,
        colText: root.colors.colOnLayer1, colTextSecondary: root.colors.colSubtext,
        colBorder: root.colors.colOutlineVariant, colBorderHover: root.colors.colOutline,
        colBorderSubtle: root.colors.colOutlineVariant,
        colGlassCard: root.colors.colLayer1, colGlassCardHover: root.colors.colLayer2,
        colGlassCardActive: root.colors.colSurfaceContainerHigh, colGlassTooltip: root.colors.colLayer2,
        colEscalonado: root.colors.colLayer2, colEscalonadoHover: root.colors.colSurfaceContainerHigh,
        colEscalonadoBorder: root.colors.colOutlineVariant,
        borderWidth: 1, cardBorderWidth: 1, borderCoverage: 1.0, blurSaturation: 1.0, overlayOpacity: 0.4,
        escalonadoOffsetX: 4, escalonadoOffsetY: 4, escalonadoHoverOffsetX: 6, escalonadoHoverOffsetY: 6,
        roundingNormal: 14, roundingSmall: 8
    })
    readonly property var aurora: ({
        colElevatedSurface: root.colors.colLayer2, colSubSurface: root.colors.colLayer1,
        colSubSurfaceActive: root.colors.colLayer2, colTooltipSurface: root.colors.colLayer2,
        colTooltipBorder: root.colors.colOutlineVariant, popupTransparentize: 0.1
    })
    readonly property var cookie: ({
        roundNormal: 14, shadowBlur: 0.6, shadowColor: "#66000000", shadowOffset: 2, shadowSpread: 0
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
