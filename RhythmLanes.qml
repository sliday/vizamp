import QtQuick
import "Palette.js" as Palette
import "Rhythm.js" as Rhythm

Canvas {
    id: root

    property var levels: []
    property bool running: false
    property bool reducedMotion: false
    property color background: "#121212"
    property color ink: "#fbbd07"

    property var activity: Rhythm.empty()
    property double lastFrame: 0
    readonly property var laneColors: {
        const colors = [ink, "#eb8055", "#d864a4", "#9e89ef", "#53b9c0"]
        return colors.map(color => Palette.readableColor(Qt.lighter(color, 1), background))
    }

    onRunningChanged: {
        if (running) return
        activity = Rhythm.empty()
        lastFrame = 0
        if (visible) requestPaint()
    }
    onReducedMotionChanged: {
        activity = Rhythm.empty()
        requestPaint()
    }
    onLaneColorsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onLevelsChanged: {
        if (!running || !visible) return
        const now = Date.now()
        activity = Rhythm.advance(activity, levels, lastFrame ? (now - lastFrame) / 1000 : 0.033, reducedMotion)
        lastFrame = now
        requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!running || width < 12 || height < 5) return

        const laneHeight = height / laneColors.length
        const strike = Math.max(4, Math.round(width * 0.05))
        const spawn = width - 6
        function laneY(lane) { return height - (lane + 0.5) * laneHeight }

        for (let lane = 0; lane < laneColors.length; lane++) {
            const y = Math.floor(laneY(lane))
            const hit = activity.hits[lane] / Rhythm.hitSeconds
            ctx.fillStyle = laneColors[lane]
            ctx.globalAlpha = 0.20
            ctx.fillRect(strike + 3, y, spawn - strike - 2, 1)
            ctx.globalAlpha = 0.45 + 0.55 * hit
            ctx.fillRect(strike - 1, y - 1, hit > 0 ? 5 : 3, laneHeight >= 3 ? 3 : 2)
        }

        for (const note of activity.notes) {
            const x = Math.round(spawn + (strike - spawn) * note.age / Rhythm.travelSeconds)
            const y = Math.floor(laneY(note.lane))
            ctx.globalAlpha = 0.55 + 0.45 * note.strength
            ctx.fillStyle = laneColors[note.lane]
            ctx.fillRect(x - 1, y - 1, note.strength > 0.65 ? 6 : 4, laneHeight >= 3 ? 3 : 2)
        }
        ctx.globalAlpha = 1
    }
}
