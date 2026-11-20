import QtQuick
import "Palette.js" as Palette

Canvas {
    id: root

    property var levels: []
    property bool running: false
    property bool reducedMotion: false
    property color background: "#121212"
    property var lookOverrides: ({})
    readonly property var look: Object.assign({
        columns: 80, buckets: 18, peakMix: 0.90, floor: 0.075, response: 0.84,
        alphaFloor: 0.19, alphaCeiling: 0.96, heatStart: 0.49, hotCore: 0.75,
        edgePixels: 17
    }, lookOverrides)
    readonly property int columns: look.columns
    readonly property var colors: {
        const backdrop = Palette.rgb(background)
        const stops = Palette.isLight(backdrop)
            ? [[0.25, 0.34, 0.55], [0.44, 0.16, 0.44], [0.74, 0.25, 0.06], [0.43, 0.13, 0.04]]
            : [[0.18, 0.38, 0.70], [0.65, 0.18, 0.58], [1.0, 0.45, 0.07], [1.0, 0.94, 0.68]]
        return Array.from({ length: look.buckets }, (_, index) => {
            const level = index / (look.buckets - 1)
            let color
            if (level <= look.heatStart) {
                color = Palette.mix(stops[0], stops[1], level / look.heatStart)
            } else {
                const heat = (level - look.heatStart) / (1 - look.heatStart)
                color = heat <= 0.65
                    ? Palette.mix(stops[1], stops[2], heat / 0.65)
                    : Palette.mix(stops[2], stops[3], (heat - 0.65) / 0.35 * look.hotCore)
            }
            const rgb = Palette.ensureContrast(color, backdrop, 3)
            return Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
        })
    }

    property var history: new Array(columns)
    property int cursor: 0
    property double lastSample: 0

    function resetHistory() {
        history = new Array(columns)
        cursor = 0
        lastSample = 0
        if (visible) requestPaint()
    }
    onRunningChanged: if (!running) resetHistory()
    onColumnsChanged: resetHistory()
    onReducedMotionChanged: requestPaint()
    onColorsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onLevelsChanged: {
        if (!running || !visible) return
        const now = Date.now()
        if (now - lastSample < (reducedMotion ? 180 : 55)) return
        history[cursor] = levels.slice()
        cursor = (cursor + 1) % columns
        lastSample = now
        requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!running || width < 1 || height < 1) return

        // Show bass at the bottom. When the widget is short, combine adjacent
        // frequency bins so a narrow peak can still light up its row.
        const rows = Math.min(24, Math.floor(height))
        const cells = colors.map(() => [])
        for (let col = 0; col < columns; col++) {
            const sample = history[reducedMotion ? col : (cursor + col) % columns]
            if (!sample) continue
            const x = Math.round(col * width / columns)
            const right = Math.round((col + 1) * width / columns)
            if (right <= x) continue
            for (let row = 0; row < rows; row++) {
                // Disjoint bin ranges keep a loud bin from smearing across rows.
                const start = Math.floor(row * sample.length / rows)
                const end = Math.floor((row + 1) * sample.length / rows)
                let peak = 0, power = 0
                for (let i = start; i < end; i++) {
                    const value = sample[i]
                    peak = Math.max(peak, value)
                    power += value * value
                }
                if (peak <= look.floor) continue
                const rms = Math.sqrt(power / (end - start))
                const energy = rms + (peak - rms) * look.peakMix
                if (energy <= look.floor) continue
                const level = Math.pow((energy - look.floor) / (1 - look.floor), look.response)
                const colorIndex = Math.round(level * (colors.length - 1))
                cells[colorIndex].push(x, height - row - 1, right - x)
            }
        }
        for (let i = 0; i < colors.length; i++) {
            ctx.beginPath()
            for (let j = 0; j < cells[i].length; j += 3)
                ctx.rect(cells[i][j], cells[i][j + 1], cells[i][j + 2], 1)
            ctx.fillStyle = colors[i]
            ctx.globalAlpha = look.alphaFloor + (look.alphaCeiling - look.alphaFloor) * i / (colors.length - 1)
            ctx.fill()
        }
        ctx.globalAlpha = 1

        // New samples enter at the right edge and old samples leave at the left.
        const edgeFraction = Math.min(look.edgePixels, width * 0.12) / width
        const mask = ctx.createLinearGradient(0, 0, width, 0)
        mask.addColorStop(0, "transparent")
        mask.addColorStop(edgeFraction, "white")
        mask.addColorStop(1 - edgeFraction, "white")
        mask.addColorStop(1, "transparent")
        ctx.save()
        ctx.globalCompositeOperation = "destination-in"
        ctx.fillStyle = mask
        ctx.fillRect(0, 0, width, height)
        ctx.restore()
    }
}
