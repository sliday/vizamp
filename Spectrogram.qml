import QtQuick
import "Palette.js" as Palette

Canvas {
    id: root

    property var levels: []
    property bool running: false
    property bool reducedMotion: false
    property color background: "#121212"
    readonly property int columns: 72
    readonly property var colors: {
        const backdrop = Palette.rgb(background)
        const stops = Palette.isLight(backdrop)
            ? [[0.28, 0.37, 0.58], [0.34, 0.22, 0.58], [0.56, 0.19, 0.31], [0.50, 0.25, 0.05]]
            : [[0.20, 0.48, 0.73], [0.49, 0.40, 0.86], [0.91, 0.34, 0.54], [1.0, 0.72, 0.18]]
        return stops.map(color => {
            const rgb = Palette.ensureContrast(color, backdrop, 3)
            return Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
        })
    }

    property var history: new Array(columns)
    property int cursor: 0
    property double lastSample: 0

    onRunningChanged: {
        if (running) return
        history = new Array(columns)
        cursor = 0
        lastSample = 0
        if (visible) requestPaint()
    }
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
            for (let row = 0; row < rows; row++) {
                const start = Math.floor(row * sample.length / rows)
                const end = Math.ceil((row + 1) * sample.length / rows)
                let energy = 0
                for (let i = start; i < end; i++) energy = Math.max(energy, sample[i])
                if (energy < 0.08) continue
                const colorIndex = Math.min(colors.length - 1, Math.floor(energy * colors.length))
                cells[colorIndex].push(x, height - row - 1, right - x)
            }
        }
        for (let i = 0; i < colors.length; i++) {
            ctx.beginPath()
            for (let j = 0; j < cells[i].length; j += 3)
                ctx.rect(cells[i][j], cells[i][j + 1], cells[i][j + 2], 1)
            ctx.fillStyle = colors[i]
            ctx.globalAlpha = 0.28 + 0.2 * i
            ctx.fill()
        }
        ctx.globalAlpha = 1

        // New samples enter at the right edge and old samples leave at the left.
        const edgeFraction = Math.min(16, width * 0.12) / width
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
