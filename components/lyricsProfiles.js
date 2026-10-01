.pragma library

// Lyric sheet style profiles. Pick one with `media.lyricsStyle`; "custom" merges
// `media.lyricsCustomStyle` from the config over the theme profile, so a new look
// only has to name what it changes.
//
// Colours: "#rrggbb", or "theme" / "themeText" to follow the wallpaper palette.
// Fonts:   "theme"     shell UI font
//          "heavy"     Archivo Black   — poster sans
//          "serif"     Playfair Display — high-contrast display serif
//          "script"    Great Vibes      — fine calligraphic script
//          "brush"     Kaushan Script   — bold brush script
//          "signature" Yellowtail       — connected neon-sign script
//          "poster"    Anton            — tall condensed poster capitals
//          "gothic"    Pirata One       — blackletter
//          "retro"     Monoton          — multi-line retro neon
//
// size     scale on the sheet's type size — display faces need their own
// activeRestAlpha  opacity of the not-yet-sung words on the current line
//          (defaults to the old dim value); raise it when glows drown them
// line     how every lyric line is set
// singing  the syllable being sung right now
// glow     halo behind the word being sung (null for none)
// lineGlow halo around the whole active line — the "burning phrase" look
// echo     "none", or "outline": an offset outline copy of each syllable
// stage    decorations behind the sheet built from the word being sung:
//            giant   a huge faded copy (the "COMPLETE" / "BABY" look)
//            accent  a calligraphic copy over it (the "baby" / "Forget" look);
//                    offset is how far below centre it sits, as a share of height

var profiles = {
    "default": {
        label: "Theme", icon: "palette",
        size: 1.0,
        line: { font: "theme", weight: 700, uppercase: false, spacing: 0 },
        fill: "theme", rest: "themeText", restAlpha: 0.28,
        singing: { color: "#ffffff" },
        glow: { color: "theme", radius: 7, strength: 0.55 },
        echo: "none",
        stage: null
    },

    // Poster sans over a giant blood-red serif.
    "cinematic": {
        label: "Cinematic", icon: "movie",
        size: 1.2,
        line: { font: "heavy", weight: 400, uppercase: true, spacing: 1 },
        fill: "#ffffff", rest: "#ffffff", restAlpha: 0.26, activeRestAlpha: 0.48,
        singing: { color: "#ffffff" },
        glow: { color: "#ffffff", radius: 14, strength: 0.7 },
        lineGlow: { color: "#ffffff", radius: 12, strength: 0.45 },
        echo: "none",
        stage: {
            giant: { font: "serif", weight: 900, uppercase: true, color: "#c0141f", opacity: 0.42 },
            accent: null
        }
    },

    // Stacked red capitals burning on black.
    "neon": {
        label: "Neon", icon: "local_fire_department",
        size: 1.55,
        line: { font: "heavy", weight: 400, uppercase: true, spacing: 1 },
        fill: "#ff6b7d", rest: "#ff6b7d", restAlpha: 0.22, activeRestAlpha: 0.55,
        singing: { color: "#ffd6db" },
        glow: { color: "#ff1f3d", radius: 18, strength: 0.9 },
        lineGlow: { color: "#ff1f3d", radius: 16, strength: 0.75 },
        echo: "none",
        stage: null
    },

    // Quiet display serif, a giant ghost word and a script flourish.
    "editorial": {
        label: "Editorial", icon: "auto_stories",
        size: 1.12,
        line: { font: "serif", weight: 500, uppercase: false, spacing: 0 },
        fill: "#f3e3cc", rest: "#f3e3cc", restAlpha: 0.30,
        singing: { color: "#ffffff" },
        glow: null,
        echo: "none",
        stage: {
            giant: { font: "serif", weight: 700, uppercase: true, color: "#f3e3cc", opacity: 0.09 },
            accent: { font: "script", color: "#e7a0a0", opacity: 0.55, offset: 0.14, size: 0.24, glow: null }
        }
    },

    // White serif with a violet brush-script echo of the sung word.
    "nocturne": {
        label: "Nocturne", icon: "dark_mode",
        size: 1.12,
        line: { font: "serif", weight: 600, uppercase: false, spacing: 0 },
        fill: "#ffffff", rest: "#ffffff", restAlpha: 0.28,
        singing: { color: "#ffffff" },
        glow: { color: "#ffffff", radius: 10, strength: 0.6 },
        lineGlow: { color: "#ffffff", radius: 10, strength: 0.4 },
        echo: "none",
        stage: {
            giant: null,
            // Below the sung line, like "Forget" under "Make you" — on it, it covers words.
            accent: { font: "brush", color: "#c77dff", opacity: 0.9, offset: 0.26, size: 0.2,
                      glow: { color: "#a855f7", radius: 16, strength: 0.85 } }
        }
    },

    // Connected script in white with a cyan neon tube behind it.
    "neonScript": {
        label: "Neon script", icon: "flare",
        size: 1.4,
        line: { font: "signature", weight: 400, uppercase: false, spacing: 0 },
        fill: "#ffffff", rest: "#ffffff", restAlpha: 0.30, activeRestAlpha: 0.55,
        singing: { color: "#ffffff" },
        glow: { color: "#29b6ff", radius: 16, strength: 0.85 },
        lineGlow: { color: "#29b6ff", radius: 12, strength: 0.5 },
        echo: "outline",
        outline: { color: "#29b6ff", opacity: 0.5, dx: 5, dy: 4 },
        stage: null
    }
};

// Lyric-edit mode: the sheet is replaced by one big line at a time, words
// landing on their timestamps and the look changing with the song. Each look:
//   font, uppercase, color, size, tint (the background wash), glow, outline
//   enter  slam | pop | rise | drop | swing — how each word lands
//   exit   zoom | lift | fade | spin | flicker — how the line leaves
//   accent optional second style for the line's most-held word: font, uppercase,
//          color, size (relative to the line), tilt (degrees), glow, enter
// sectionGap   seconds between lines that start a new section (and look)
// linesPerLook in a long section, move on after this many lines
profiles["kinetic"] = {
    label: "Edit", icon: "motion_photos_on",
    mode: "kinetic",
    sectionGap: 6.0,
    linesPerLook: 4,
    // One style per line; see "motion" below for the two-style version.
    looks: [
        { font: "heavy", uppercase: true, color: "#ffffff", size: 1.0, tint: "#b0101c",
          glow: { color: "#ff2a3a", radius: 14 }, enter: "slam", exit: "zoom" },
        { font: "serif", uppercase: false, color: "#f3e3cc", size: 1.05, tint: "#8a6a4a",
          glow: null, enter: "rise", exit: "lift" },
        { font: "signature", uppercase: false, color: "#ffffff", size: 1.25, tint: "#0b6fa8",
          glow: { color: "#29b6ff", radius: 16 }, enter: "drop", exit: "flicker" },
        { font: "heavy", uppercase: true, color: "#ffe14d", size: 0.95, tint: "#a85a00",
          glow: { color: "#ff9d00", radius: 12 }, outline: "#3a1c00", enter: "pop", exit: "spin" },
        { font: "brush", uppercase: false, color: "#e3c2ff", size: 1.15, tint: "#5b1f8f",
          glow: { color: "#a855f7", radius: 16 }, enter: "swing", exit: "fade" }
    ],
    // The fields below keep the shared helpers happy; the edit view draws its own.
    line: { font: "heavy", weight: 400, uppercase: true, spacing: 0 },
    fill: "#ffffff", rest: "#ffffff", restAlpha: 0.3,
    singing: { color: "#ffffff" }, glow: null, echo: "none", stage: null
};

// Motion: the same lyric-edit view, but every look pairs two styles — the line's
// own and an accent for the word the singer holds longest.
profiles["motion"] = {
    label: "Motion", icon: "animation",
    mode: "kinetic",
    sectionGap: 6.0,
    linesPerLook: 4,
    // Each look pairs two styles: the line's own, and an accent for the one
    // word the singer leans on (set on its own row, bigger). Pairings follow
    // the reference edits — heavy over serif, serif over script, and so on.
    looks: [
        // "BUT I'M / COMPLETE": white poster capitals, the held word in crimson serif.
        { font: "heavy", uppercase: true, color: "#ffffff", size: 1.0, tint: "#b0101c",
          glow: { color: "#ff2a3a", radius: 14 }, enter: "slam", exit: "zoom",
          accent: { font: "serif", uppercase: true, color: "#ff3b47", size: 1.45,
                    glow: { color: "#8a0010", radius: 18 }, enter: "rise" } },
        // "BABY / baby": cream serif, the held word in rose script.
        { font: "serif", uppercase: false, color: "#f3e3cc", size: 1.05, tint: "#8a6a4a",
          glow: null, enter: "rise", exit: "lift",
          accent: { font: "script", uppercase: false, color: "#e7a0a0", size: 1.7, tilt: -6,
                    glow: null, enter: "swing" } },
        // Neon script, with the held word as a white capital block lit in cyan.
        { font: "signature", uppercase: false, color: "#ffffff", size: 1.25, tint: "#0b6fa8",
          glow: { color: "#29b6ff", radius: 16 }, enter: "drop", exit: "flicker",
          accent: { font: "heavy", uppercase: true, color: "#ffffff", size: 0.95,
                    glow: { color: "#29b6ff", radius: 18 }, enter: "slam" } },
        // Gold capitals, the held word as a white brush stroke in orange light.
        { font: "heavy", uppercase: true, color: "#ffe14d", size: 0.95, tint: "#a85a00",
          glow: { color: "#ff9d00", radius: 12 }, outline: "#3a1c00", enter: "pop", exit: "spin",
          accent: { font: "brush", uppercase: false, color: "#ffffff", size: 1.5, tilt: -5,
                    glow: { color: "#ff7a00", radius: 16 }, enter: "pop" } },
        // "Make you / Forget": white serif, the held word in violet brush script.
        { font: "serif", uppercase: false, color: "#ffffff", size: 1.05, tint: "#5b1f8f",
          glow: { color: "#ffffff", radius: 10 }, enter: "rise", exit: "fade",
          accent: { font: "brush", uppercase: false, color: "#c77dff", size: 1.5, tilt: -4,
                    glow: { color: "#a855f7", radius: 18 }, enter: "swing" } }
    ],
    // The fields below keep the shared helpers happy; the edit view draws its own.
    line: { font: "heavy", weight: 400, uppercase: true, spacing: 0 },
    fill: "#ffffff", rest: "#ffffff", restAlpha: 0.3,
    singing: { color: "#ffffff" }, glow: null, echo: "none", stage: null
};

// Reel: the edit treatment. Letters land instead of whole words, the stage moves
// like a camera (a slow push across each line, a punch and jolt on every hit)
// and each line leaves on a cut. Nothing is drawn behind the text but its glow.
//   camera   push  how far the shot creeps in over a line (scale)
//            punch zoom added at the peak of a hit
//            shake jolt distance in pixels at the peak of a hit
// Per look, on top of the edit fields:
//   letters   animate letter by letter
//   highlight colour that sweeps through a word as it is sung
//   tint      unused by Reel (its backdrop is the album art); kept for "kinetic"
//   punch     how hard this look's hits drive the camera (0..1)
//   layout    "stack" or "stagger" (rows step left and right)
//   enter     slam | cascade | scatter | type | focus | flip | stretch | split
//             | wave | zoom | drop — how letters land
//   exit      through | blur | glitch | shatter | whip | fall | split | dissolve
//             | flip — the cut out
//   follow    follow-cam: the line is set bigger than the frame and the camera
//             pans to each word as it is sung
profiles["reel"] = {
    label: "Reel", icon: "theaters",
    mode: "kinetic",
    sectionGap: 6.0,
    linesPerLook: 4,
    camera: { push: 0.07, punch: 0.06, shake: 7 },
    looks: [
        // Hit: poster capitals slammed down letter by letter, the sung word
        // burning red, then the camera flies through the line.
        { font: "heavy", uppercase: true, color: "#ffffff", highlight: "#ff3b47", size: 1.0, tint: "#b0101c",
          glow: { color: "#ff2a3a", radius: 14 }, letters: true, enter: "slam", exit: "through", punch: 1.0,
          accent: { font: "serif", uppercase: true, color: "#ff3b47", size: 1.4,
                    glow: { color: "#8a0010", radius: 18 }, enter: "slam" } },
        // Focus: serif pulled into focus with a gold sweep, sinking back out of it.
        { font: "serif", uppercase: false, color: "#f3e3cc", highlight: "#ffd27a", size: 1.05, tint: "#8a6a4a",
          glow: null, letters: true, enter: "focus", exit: "blur", punch: 0.45,
          accent: { font: "script", uppercase: false, color: "#e7a0a0", size: 1.7, tilt: -6,
                    glow: null, enter: "focus" } },
        // Sign: script typed on like neon warming up, glitching off.
        { font: "signature", uppercase: false, color: "#ffffff", highlight: "#9fe8ff", size: 1.25, tint: "#0b6fa8",
          glow: { color: "#29b6ff", radius: 16 }, letters: true, enter: "type", exit: "glitch", punch: 0.6,
          accent: { font: "heavy", uppercase: true, color: "#ffffff", size: 0.95,
                    glow: { color: "#29b6ff", radius: 18 }, enter: "slam" } },
        // Scatter: gold capitals assembling out of the air and blown apart.
        { font: "heavy", uppercase: true, color: "#ffe14d", highlight: "#ffffff", size: 0.95, tint: "#a85a00",
          glow: { color: "#ff9d00", radius: 12 }, outline: "#3a1c00", letters: true, enter: "scatter", exit: "shatter",
          punch: 0.8,
          accent: { font: "brush", uppercase: false, color: "#ffffff", size: 1.5, tilt: -5,
                    glow: { color: "#ff7a00", radius: 16 }, enter: "cascade" } },
        // Whip: violet brush script dropping onto a staggered layout, whipped off frame.
        { font: "brush", uppercase: false, color: "#e3c2ff", highlight: "#ffffff", size: 1.15, tint: "#5b1f8f",
          glow: { color: "#a855f7", radius: 16 }, letters: true, layout: "stagger", enter: "cascade", exit: "whip",
          punch: 0.7,
          accent: { font: "heavy", uppercase: true, color: "#ffffff", size: 1.0,
                    glow: { color: "#a855f7", radius: 18 }, enter: "slam" } },
        // Poster: towering condensed capitals that squash and stretch into place,
        // then shred apart down the middle.
        { font: "poster", uppercase: true, color: "#ffffff", highlight: "#ff2a6d", size: 1.15, tint: "#3a0018",
          glow: { color: "#ff2a6d", radius: 10 }, letters: true, enter: "stretch", exit: "split", punch: 0.9,
          accent: { font: "script", uppercase: false, color: "#ff8fb1", size: 1.6, tilt: -7,
                    glow: { color: "#ff2a6d", radius: 16 }, enter: "cascade" } },
        // Gothic: blackletter flipping round like cards, dropped to the floor on the way out.
        { font: "gothic", uppercase: false, color: "#f4e9e9", highlight: "#ff2424", size: 1.2, tint: "#420000",
          glow: { color: "#ff0000", radius: 14 }, letters: true, enter: "flip", exit: "fall", punch: 0.85,
          accent: { font: "heavy", uppercase: true, color: "#ffffff", size: 0.9,
                    glow: { color: "#ff1a1a", radius: 18 }, enter: "slam" } },
        // Retro: multi-line neon rushing in from far away, fizzing out letter by letter.
        { font: "retro", uppercase: true, color: "#ff7ad9", highlight: "#ffffff", size: 0.85, tint: "#5c0a52",
          glow: { color: "#ff3cc7", radius: 16 }, letters: true, enter: "zoom", exit: "dissolve", punch: 0.55,
          accent: { font: "signature", uppercase: false, color: "#7af3ff", size: 1.7, tilt: -6,
                    glow: { color: "#00d5ff", radius: 16 }, enter: "wave" } },
        // Wave: aqua script rolling in on a swell, flipped away.
        { font: "signature", uppercase: false, color: "#c4fff4", highlight: "#ffffff", size: 1.3, tint: "#06574a",
          glow: { color: "#2ef2c8", radius: 16 }, letters: true, enter: "wave", exit: "flip", punch: 0.5,
          accent: { font: "poster", uppercase: true, color: "#ffffff", size: 1.0,
                    glow: { color: "#2ef2c8", radius: 14 }, enter: "stretch" } },
        // Split: outlined condensed yellow closing in from both sides, flown through.
        { font: "poster", uppercase: true, color: "#ffe14d", highlight: "#ffffff", size: 1.1, tint: "#5a4000",
          glow: null, outline: "#000000", letters: true, layout: "stagger", enter: "split", exit: "through",
          punch: 0.95,
          accent: { font: "gothic", uppercase: false, color: "#ffffff", size: 1.5,
                    glow: { color: "#ffb000", radius: 14 }, enter: "drop" } },
        // Ice: cold serif capitals bouncing down from above and falling away.
        { font: "serif", uppercase: true, color: "#e2f6ff", highlight: "#79d4ff", size: 1.0, tint: "#0b3566",
          glow: { color: "#79d4ff", radius: 12 }, letters: true, enter: "drop", exit: "fall", punch: 0.6,
          accent: { font: "script", uppercase: false, color: "#ffffff", size: 1.7, tilt: -5,
                    glow: { color: "#79d4ff", radius: 16 }, enter: "focus" } },
        // Follow: a follow-cam. The line is set bigger than the frame and the
        // camera pans to each word as it lands, like a lyric video tracking
        // the text word by word.
        { font: "poster", uppercase: true, color: "#ffffff", highlight: "#5ef0ff", size: 1.5, tint: "#0d3a3a",
          glow: { color: "#5ef0ff", radius: 10 }, letters: true, follow: true, enter: "slam", exit: "through",
          punch: 0.5,
          accent: { font: "brush", uppercase: false, color: "#5ef0ff", size: 1.3, tilt: -5,
                    glow: { color: "#00c8ff", radius: 14 }, enter: "cascade" } },
        // Follow (serif): the same camera move, slower and quieter, each word
        // pulled into focus as the camera arrives on it.
        { font: "serif", uppercase: false, color: "#fff4e3", highlight: "#ffcf8a", size: 1.5, tint: "#5a3a1a",
          glow: { color: "#ffb35c", radius: 10 }, letters: true, follow: true, enter: "focus", exit: "blur",
          punch: 0.3,
          accent: { font: "script", uppercase: false, color: "#ffcf8a", size: 1.5, tilt: -6,
                    glow: { color: "#ff9d3c", radius: 14 }, enter: "focus" } }
    ],
    // The fields below keep the shared helpers happy; the edit view draws its own.
    line: { font: "heavy", weight: 400, uppercase: true, spacing: 0 },
    fill: "#ffffff", rest: "#ffffff", restAlpha: 0.3,
    singing: { color: "#ffffff" }, glow: null, echo: "none", stage: null
};

// How letters land, per enter name. Distances are in ems of the line's size;
// stagger is the delay between neighbouring letters in milliseconds.
var letterMotion = {
    slam:    { scale: 2.6, x: 0, y: 0, rot: 0, spread: 0, dur: 170, stagger: 16, ease: "OutQuad" },
    cascade: { scale: 1.35, x: 0, y: -0.75, rot: 0, spread: 0, dur: 440, stagger: 34, ease: "OutBack" },
    scatter: { scale: 0.5, x: 0, y: 0, rot: 55, spread: 1.4, dur: 560, stagger: 10, ease: "OutExpo" },
    type:    { scale: 1.3, x: 0, y: 0, rot: 0, spread: 0, dur: 80, stagger: 30, ease: "Linear" },
    focus:   { scale: 1.15, x: 0, y: 0.3, rot: 0, spread: 0, dur: 500, stagger: 20, ease: "OutExpo", blur: true },
    rise:    { scale: 1.0, x: 0, y: 0.5, rot: 0, spread: 0, dur: 360, stagger: 22, ease: "OutCubic" },
    // Card flip round the vertical axis.
    flip:    { scale: 1.0, x: 0, y: 0, rot: 0, spread: 0, flip: 90, dur: 420, stagger: 40, ease: "OutBack" },
    // Squashed tall and thin, springing out to shape.
    stretch: { scale: 1.0, x: 0, y: 0, rot: 0, spread: 0, sy: 2.4, dur: 460, stagger: 24, ease: "OutBack" },
    // Odd and even letters closing in from opposite sides.
    split:   { scale: 1.0, x: 0, y: 0, rot: 0, spread: 0, alt: 1.6, dur: 380, stagger: 14, ease: "OutExpo" },
    // Letters rolling in on alternating swells.
    wave:    { scale: 0.8, x: 0, y: 0, rot: 18, spread: 0, altY: 0.9, dur: 520, stagger: 30, ease: "OutBack" },
    // Rushing in from far away, out of focus.
    zoom:    { scale: 0.05, x: 0, y: 0, rot: 0, spread: 0, dur: 520, stagger: 26, ease: "OutExpo", blur: true },
    // Dropped from above with a bounce.
    drop:    { scale: 1.0, x: 0, y: -1.6, rot: 0, spread: 0, dur: 620, stagger: 38, ease: "OutBounce" }
};

// Order the switcher shows them in.
var order = ["default", "cinematic", "neon", "editorial", "nocturne", "neonScript", "kinetic", "motion", "reel"];

function merge(base, over) {
    var out = {};
    var key;
    for (key in base)
        out[key] = base[key];
    for (key in over) {
        var value = over[key];
        if (value && typeof value === "object" && !Array.isArray(value)
                && base[key] && typeof base[key] === "object")
            out[key] = merge(base[key], value);
        else
            out[key] = value;
    }
    return out;
}

function resolve(name, custom) {
    if (name === "custom")
        return merge(profiles["default"], custom || {});
    return profiles[name] || profiles["default"];
}
