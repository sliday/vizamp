import QtQuick
import "Heat.js" as Heat
import "Palette.js" as Palette
import "Rhythm.js" as Rhythm
import "RhythmEffects.js" as Effects

Canvas {
    id: root

    property var levels: []
    property bool running: false
    property bool reducedMotion: false
    property color background: "#121212"
    property color ink: "#fbbd07"

    property var lookOverrides: ({})
    readonly property var look: Object.assign({
        railOpacity: 0.28, laneTaper: 0.23, noteSway: 0.23,
        trailLifetime: 0.075, trailGlow: 0.28, heatMix: 0.65, hitGlow: 0.42,
        sparkCount: 3, sparkSpeed: 55, sparkLife: 0.22
    }, lookOverrides)
    property var activity: Rhythm.empty()
    property var laneHeat: []
    property var sparks: []
    property double lastFrame: 0
    property real motionClock: 0
    readonly property var laneColors: {
        const colors = [ink, "#eb8055", "#d864a4", "#9e89ef", "#53b9c0", "#83bb72"]
        return colors.map(color => Palette.readableColor(Qt.lighter(color, 1), background))
    }
    readonly property var heatStops: {
        const backdrop = Palette.rgb(background)
        return Palette.isLight(backdrop)
            ? Heat.lightStops.map(color => Palette.ensureContrast(color, backdrop, 4.5))
            : Heat.darkStops
    }

    function warmColor(color, heat, amount) {
        const mixed = Palette.mix(Palette.rgb(color), Heat.color(heat, heatStops), amount)
        return Qt.rgba(mixed[0], mixed[1], mixed[2], 1)
    }

    onRunningChanged: {
        if (running) return
        activity = Rhythm.empty()
        laneHeat = []
        sparks = []
        lastFrame = 0
        motionClock = 0
        if (visible) requestPaint()
    }
    onReducedMotionChanged: {
        activity = Rhythm.empty()
        laneHeat = []
        sparks = []
        requestPaint()
    }
    onLaneColorsChanged: requestPaint()
    onLookChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onLevelsChanged: {
        if (!running || !visible) return
        const now = Date.now()
        const dt = lastFrame ? Math.min(0.1, Math.max(0, (now - lastFrame) / 1000)) : 0.033
        if (!reducedMotion) motionClock += dt
        const next = Rhythm.advance(activity, levels, dt, reducedMotion)
        laneHeat = reducedMotion ? [] : Heat.advance(laneHeat, activity.levels, next.levels, dt)
        sparks = reducedMotion ? [] : Effects.advance(sparks, next.arrivals, laneHeat, dt, look)
        activity = next
        lastFrame = now
        requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!running || width < 12 || height < Rhythm.laneCount) return

        const laneHeight = height / Rhythm.laneCount
        const strike = Math.max(4, Math.round(width * 0.05))
        const spawn = width - 6
        ctx.lineCap = "round"

        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.24
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(strike, 1)
        ctx.lineTo(strike, height - 1)
        ctx.stroke()

        for (let lane = 0; lane < Rhythm.laneCount; lane++) {
            const y = Rhythm.laneY(lane, 1, height, look.laneTaper)
            const hit = activity.hits[lane] / Rhythm.hitSeconds
            const color = laneColors[lane]
            const heat = laneHeat[lane] || 0

            ctx.strokeStyle = warmColor(color, heat, heat * look.heatMix * 0.45)
            ctx.globalAlpha = look.railOpacity
            ctx.lineWidth = 0.75
            ctx.beginPath()
            ctx.moveTo(strike + 2, y)
            ctx.lineTo(spawn, Rhythm.laneY(lane, 0, height, look.laneTaper))
            ctx.stroke()

            if (hit > 0 && !reducedMotion) {
                ctx.fillStyle = warmColor(color, Math.max(0.65, heat), look.heatMix)
                ctx.globalAlpha = look.hitGlow * hit
                ctx.fillRect(strike - 2, y - laneHeight * 0.36, 4 + 5 * hit, laneHeight * 0.72)
            }
            ctx.fillStyle = color
            ctx.globalAlpha = 0.50 + 0.50 * hit
            ctx.beginPath()
            ctx.arc(strike, y, Math.min(1.55, laneHeight * 0.35), 0, Math.PI * 2)
            ctx.fill()
        }

        for (const note of activity.notes) {
            const laneInk = laneColors[note.lane]
            const strength = note.strength
            const heat = Math.max(laneHeat[note.lane] || 0, strength * 0.72)
            const color = warmColor(laneInk, heat, look.heatMix * heat)
            const progress = note.age / Rhythm.travelSeconds
            const x = spawn + (strike - spawn) * progress
            const y = Rhythm.noteY(note.lane, progress, strength, motionClock, height, look.laneTaper, look.noteSway)
            const weight = Math.min(laneHeight * 0.65, 1.2 + 0.9 * strength)
            const enter = Math.min(1, 0.25 + note.age / 0.05)
            const tailAge = Math.max(0, note.age - look.trailLifetime * (0.72 + 0.52 * strength))

            // Sweep the note over its recent path, then draw a bright head.
            if (tailAge < note.age) {
                const tailX = spawn + (strike - spawn) * tailAge / Rhythm.travelSeconds
                const trail = ctx.createLinearGradient(tailX, 0, x, 0)
                trail.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0))
                trail.addColorStop(0.65, Qt.rgba(color.r, color.g, color.b, 0.32))
                trail.addColorStop(1, color)
                ctx.beginPath()
                for (let point = 0; point <= 4; point++) {
                    const age = tailAge + (note.age - tailAge) * point / 4
                    const along = age / Rhythm.travelSeconds
                    const px = spawn + (strike - spawn) * along
                    const py = Rhythm.noteY(note.lane, along, strength, motionClock - (note.age - age),
                        height, look.laneTaper, look.noteSway)
                    if (point === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
                ctx.strokeStyle = trail
                ctx.lineWidth = Math.min(laneHeight * 0.9, weight * 1.8)
                ctx.globalAlpha = look.trailGlow * enter
                ctx.stroke()
                ctx.lineWidth = weight
                ctx.globalAlpha = 0.76 * enter
                ctx.stroke()
            }

            ctx.fillStyle = laneInk
            ctx.globalAlpha = enter
            ctx.beginPath()
            ctx.arc(x, y, weight * 0.62, 0, Math.PI * 2)
            ctx.fill()
        }

        for (const spark of sparks) {
            const y = Rhythm.laneY(spark.lane, 1, height, look.laneTaper)
            const color = warmColor(laneColors[spark.lane], spark.heat, look.heatMix)
            const x = strike + spark.x
            ctx.strokeStyle = color
            ctx.lineWidth = Math.min(1.1, laneHeight * 0.45)
            ctx.globalAlpha = 0.78 * (1 - spark.age / spark.life)
            ctx.beginPath()
            ctx.moveTo(strike + spark.oldX - 0.5, y + spark.oldY * laneHeight)
            ctx.lineTo(x, y + spark.y * laneHeight)
            ctx.stroke()
        }
        ctx.globalAlpha = 1
    }
}
