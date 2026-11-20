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
        trailLifetime: 0.085, trailGlow: 0.28, heatMix: 0.65, hitGlow: 0.42,
        sparkCount: 3, sparkSpeed: 55, sparkLife: 0.22
    }, lookOverrides)
    property var activity: Rhythm.empty()
    property var laneHeat: []
    property var sparks: []
    property double lastFrame: 0
    property real motionClock: 0
    readonly property bool lightBackground: Palette.isLight(Palette.rgb(background))
    readonly property var laneColors: {
        const colors = [ink, "#eb8055", "#db639b", "#a488f1",
            "#619aff", "#51c3c3", "#75bf80", "#c4d36b"]
        return colors.map(color => Palette.readableColor(Qt.lighter(color, 1), background))
    }
    readonly property var noteColors: {
        const highlight = lightBackground ? [0.18, 0.09, 0.16] : [1, 0.96, 0.86]
        return laneColors.map(color => {
            const rgb = Palette.mix(Palette.rgb(color), highlight, lightBackground ? 0.24 : 0.30)
            return Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
        })
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

    function displacement(lane, progress, spacing) {
        return Rhythm.displacement(activity.beats[lane], progress, spacing, laneHeat[lane] || 0)
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
        if (reducedMotion) {
            laneHeat = []
        } else {
            const baseHeat = Heat.advance(laneHeat, activity.levels, next.levels, dt)
            for (const note of next.notes) {
                if (note.age !== 0) continue
                const before = baseHeat[note.lane]
                baseHeat[note.lane] = before + (1 - before) * (0.12 + 0.30 * note.velocity)
            }
            laneHeat = baseHeat
        }
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

        const strikeColor = Palette.readableColor(ink, background)
        const marker = ctx.createLinearGradient(0, 0, 0, height)
        marker.addColorStop(0, Qt.rgba(strikeColor.r, strikeColor.g, strikeColor.b, 0))
        marker.addColorStop(0.18, strikeColor)
        marker.addColorStop(0.82, strikeColor)
        marker.addColorStop(1, Qt.rgba(strikeColor.r, strikeColor.g, strikeColor.b, 0))
        ctx.strokeStyle = marker
        ctx.globalAlpha = lightBackground ? 0.32 : 0.24
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

            const railColor = warmColor(color, heat, look.heatMix * (0.32 * heat + 0.52 * heat * heat))
            const rail = ctx.createLinearGradient(strike, 0, spawn, 0)
            rail.addColorStop(0, railColor)
            rail.addColorStop(0.78, railColor)
            rail.addColorStop(1, Qt.rgba(railColor.r, railColor.g, railColor.b, 0))
            ctx.strokeStyle = rail
            const beat = activity.beats[lane]
            const ring = beat ? beat.strength * (1 - beat.age / Rhythm.vibrationSeconds) : 0
            const loudness = reducedMotion ? 0 : activity.levels[lane]
            ctx.globalAlpha = look.railOpacity + 0.13 * loudness + 0.28 * ring
                + (lightBackground ? 0.08 : 0)
            const thinWidth = 0.42
            const loudWidth = Math.min(2.05, laneHeight * 0.66)
            const thickness = Math.min(1, 0.88 * Math.pow(loudness, 1.15) + 0.35 * heat * heat)
            ctx.lineWidth = thinWidth + (loudWidth - thinWidth) * thickness
            ctx.beginPath()
            ctx.moveTo(strike + 2, y)
            if (activity.beats[lane]) {
                for (let point = 1; point <= 24; point++) {
                    const distance = point / 24
                    const progress = 1 - distance
                    ctx.lineTo(strike + (spawn - strike) * distance,
                        Rhythm.laneY(lane, progress, height, look.laneTaper)
                        + displacement(lane, progress, laneHeight))
                }
            } else {
                ctx.lineTo(spawn, Rhythm.laneY(lane, 0, height, look.laneTaper))
            }
            const railAlpha = ctx.globalAlpha
            const railWidth = ctx.lineWidth
            const radiance = Math.max(0, (heat - 0.45) / 0.55)
            if (radiance > 0) {
                ctx.lineWidth = Math.min(laneHeight * 0.9, railWidth * 2)
                ctx.globalAlpha = 0.28 * radiance
                ctx.stroke()
            }
            ctx.lineWidth = railWidth
            ctx.globalAlpha = railAlpha
            ctx.stroke()

            if (hit > 0 && !reducedMotion) {
                const flash = warmColor(color, Math.max(0.65, heat), look.heatMix)
                const flare = ctx.createLinearGradient(strike - 2, 0, strike + 7, 0)
                const clear = Qt.rgba(flash.r, flash.g, flash.b, 0)
                flare.addColorStop(0, clear)
                flare.addColorStop(0.25, flash)
                flare.addColorStop(1, clear)
                ctx.fillStyle = flare
                ctx.globalAlpha = look.hitGlow * hit * (0.45 + 0.55 * hit)
                ctx.fillRect(strike - 2, y - laneHeight * 0.36, 9, laneHeight * 0.72)
            }
            const receiving = activity.holds.some(hold => hold.lane === lane && hold.held
                && hold.age >= Rhythm.travelSeconds)
            ctx.fillStyle = warmColor(color, Math.max(heat, 0.66 + 0.1 * hit),
                look.heatMix * Math.max(hit, receiving ? 0.65 : 0))
            ctx.globalAlpha = receiving ? 0.92 : 0.38 + 0.62 * hit
            ctx.beginPath()
            ctx.arc(strike, y, Math.min(1.12 + 0.53 * hit, laneHeight * (0.30 + 0.09 * hit)), 0, Math.PI * 2)
            ctx.fill()
        }

        for (const hold of activity.holds) {
            if (hold.duration < Rhythm.holdSeconds) continue
            const from = Math.min(1, (hold.age - hold.duration) / Rhythm.travelSeconds)
            const to = Math.min(1, hold.age / Rhythm.travelSeconds)
            const tailX = spawn + (strike - spawn) * from
            const headX = spawn + (strike - spawn) * to
            const laneColor = laneColors[hold.lane]
            const holdHeat = hold.held ? 0.65 : 0.65 * (1 - from)
            const color = warmColor(laneColor, holdHeat, 0.45 * holdHeat)
            const ribbon = ctx.createLinearGradient(tailX, 0, headX, 0)
            ribbon.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.1))
            ribbon.addColorStop(0.72, Qt.rgba(color.r, color.g, color.b, 0.62))
            ribbon.addColorStop(1, color)
            ctx.strokeStyle = ribbon
            const holdFade = Math.min(1, 0.25 + (hold.duration - Rhythm.holdSeconds) / 0.10)
                * Math.min(1, (to - from) / 0.20)
            ctx.lineWidth = Math.min(2.0, laneHeight * (0.31 + 0.28 * hold.strength))
            ctx.beginPath()
            for (let point = 0; point <= 16; point++) {
                const progress = from + (to - from) * (point / 16)
                const x = spawn + (strike - spawn) * progress
                const y = Rhythm.noteY(hold.lane, progress, hold.strength, motionClock, height,
                    look.laneTaper, look.noteSway)
                    + displacement(hold.lane, progress, laneHeight)
                if (point === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            const holdWidth = ctx.lineWidth
            ctx.lineWidth = Math.min(laneHeight * 0.86, holdWidth * 1.7)
            ctx.globalAlpha = 0.20 * holdFade * hold.strength
            ctx.stroke()
            ctx.lineWidth = holdWidth
            ctx.globalAlpha = 0.68 * holdFade
            ctx.stroke()
        }

        for (const note of activity.notes) {
            const laneInk = laneColors[note.lane]
            const strength = note.strength
            const heat = Math.max(laneHeat[note.lane] || 0, strength * 0.72)
            const color = warmColor(laneInk, heat, look.heatMix * heat)
            const progress = note.age / Rhythm.travelSeconds
            const x = spawn + (strike - spawn) * progress
            const y = Rhythm.noteY(note.lane, progress, strength, motionClock, height, look.laneTaper, look.noteSway)
                + displacement(note.lane, progress, laneHeight)
            const weight = Math.min(laneHeight * 0.65, 0.90 + 0.88 * Math.pow(strength, 1.35) + 0.65 * heat * note.velocity)
            const enter = 1 - Math.pow(1 - Math.min(1, note.age / 0.075), 2)
            const tailAge = Math.max(0, note.age - look.trailLifetime * (0.55 + 0.50 * strength * strength + 0.30 * note.velocity))

            // Sweep the note over its recent path, then draw a bright head.
            const heldHead = activity.holds.some(hold => hold.lane === note.lane
                && Math.abs(hold.age - note.age) < 0.001 && hold.duration >= Rhythm.holdSeconds)
            if (tailAge < note.age && !heldHead) {
                const tailX = spawn + (strike - spawn) * tailAge / Rhythm.travelSeconds
                const trail = ctx.createLinearGradient(tailX, 0, x, 0)
                trail.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0))
                trail.addColorStop(0.52, Qt.rgba(color.r, color.g, color.b, 0.16))
                trail.addColorStop(0.78, Qt.rgba(color.r, color.g, color.b, 0.47))
                trail.addColorStop(1, color)
                ctx.beginPath()
                for (let point = 0; point <= 4; point++) {
                    const age = tailAge + (note.age - tailAge) * point / 4
                    const along = age / Rhythm.travelSeconds
                    const px = spawn + (strike - spawn) * along
                    const py = Rhythm.noteY(note.lane, along, strength, motionClock - (note.age - age),
                        height, look.laneTaper, look.noteSway)
                        + displacement(note.lane, along, laneHeight)
                    if (point === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
                ctx.strokeStyle = trail
                ctx.lineWidth = Math.min(laneHeight * 0.76, weight * 1.55)
                ctx.globalAlpha = look.trailGlow * enter * (0.52 + 0.48 * strength)
                ctx.stroke()
                ctx.lineWidth = weight
                ctx.globalAlpha = (lightBackground ? 0.87 : 0.76) * enter
                ctx.stroke()
            }

            ctx.fillStyle = warmColor(noteColors[note.lane], heat, look.heatMix * strength * progress * 0.46)
            ctx.globalAlpha = enter
            ctx.beginPath()
            ctx.arc(x, y, weight * 0.62, 0, Math.PI * 2)
            ctx.fill()
            if (strength > 0.48) {
                ctx.fillStyle = lightBackground ? "#391a16" : "#fff0ce"
                ctx.globalAlpha = enter * strength * (0.24 + 0.44 * progress)
                ctx.beginPath()
                ctx.arc(x - weight * 0.14, y, weight * 0.28, 0, Math.PI * 2)
                ctx.fill()
            }
        }

        for (const spark of sparks) {
            const y = Rhythm.laneY(spark.lane, 1, height, look.laneTaper)
            const life = 1 - spark.age / spark.life
            const color = warmColor(laneColors[spark.lane], spark.heat * (0.7 + 0.3 * life),
                look.heatMix * life)
            const x = strike + spark.x
            const tailX = strike + spark.oldX - 0.5
            const dy = displacement(spark.lane, Math.max(0, 1 - spark.x / 30), laneHeight)
            const streak = ctx.createLinearGradient(tailX, 0, x, 0)
            streak.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.16))
            streak.addColorStop(1, color)
            ctx.strokeStyle = streak
            ctx.lineWidth = Math.min(laneHeight * 0.45, 0.45 + 0.65 * life)
            ctx.globalAlpha = (lightBackground ? 0.96 : 0.88) * life * (0.50 + 0.50 * life)
            ctx.beginPath()
            ctx.moveTo(tailX, y + spark.oldY * laneHeight + dy)
            ctx.lineTo(x, y + spark.y * laneHeight + dy)
            ctx.stroke()
            if (spark.heat > 0.73 && life > 0.50) {
                ctx.fillStyle = color
                ctx.globalAlpha *= 0.72
                ctx.beginPath()
                ctx.arc(x, y + spark.y * laneHeight + dy, 0.52, 0, Math.PI * 2)
                ctx.fill()
            }
        }
        ctx.globalAlpha = 1
    }
}
