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
        columns: 88, buckets: 22, peakMix: 0.90, floor: 0.080, response: 0.78,
        alphaFloor: 0.14, alphaCeiling: 1.0, heatStart: 0.46, hotCore: 0.94,
        edgePixels: 17
    }, lookOverrides)
    readonly property int columns: look.columns
    readonly property bool lightBackground: Palette.isLight(Palette.rgb(background))
    readonly property var colors: {
        const backdrop = Palette.rgb(background)
        const stops = Palette.isLight(backdrop)
            ? [[0.24, 0.31, 0.60], [0.48, 0.14, 0.43], [0.79, 0.27, 0.035], [0.39, 0.095, 0.024]]
            : [[0.13, 0.37, 0.82], [0.70, 0.145, 0.44], [1.0, 0.47, 0.075], [1.0, 0.96, 0.72]]
        return Array.from({ length: look.buckets }, (_, index) => {
            const level = index / (look.buckets - 1)
            let color
            if (level <= look.heatStart) {
                color = Palette.mix(stops[0], stops[1], Math.pow(level / look.heatStart, 1.17))
            } else {
                const heat = (level - look.heatStart) / (1 - look.heatStart)
                const ember = lightBackground ? 0.65 : 0.56
                color = heat <= ember
                    ? Palette.mix(stops[1], stops[2], heat / ember)
                    : Palette.mix(stops[2], stops[3], Math.pow((heat - ember) / (1 - ember), lightBackground ? 1.30 : 1.34) * look.hotCore)
            }
            const rgb = Palette.ensureContrast(color, backdrop, 2.45 + 1.05 * level)
            return Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
        })
    }

    property var history: new Array(columns)
    property int cursor: 0
    property double lastSample: 0
    property var pendingPeaks: []
    property var pendingSums: []
    property int pendingCount: 0

    function resetHistory() {
        history = new Array(columns)
        cursor = 0
        lastSample = 0
        clearPending()
        if (visible) requestPaint()
    }
    onRunningChanged: if (!running) resetHistory()
    onColumnsChanged: resetHistory()
    onReducedMotionChanged: {
        clearPending()
        if (reducedMotion) {
            const ordered = history.slice(cursor).concat(history.slice(0, cursor)).filter(sample => !!sample)
            cursor = ordered.length % columns
            history = ordered.concat(new Array(columns - ordered.length))
        }
        requestPaint()
    }
    onColorsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onLevelsChanged: {
        if (running && visible) appendSample(levels, Date.now())
    }

    function clearPending() {
        pendingPeaks = []
        pendingSums = []
        pendingCount = 0
    }

    function appendSample(frame, now) {
        if (lastSample && now - lastSample > 350) clearPending()
        pendingPeaks = frame.map((level, index) => Math.max(level, pendingPeaks[index] || 0))
        pendingSums = frame.map((level, index) => level + (pendingSums[index] || 0))
        pendingCount++
        if (now - lastSample < (reducedMotion ? 180 : 50)) return
        history[cursor] = pendingPeaks.map((peak, index) => (reducedMotion ? 0.74 : 0.85) * peak
            + (reducedMotion ? 0.26 : 0.15) * pendingSums[index] / pendingCount)
        clearPending()
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
        const pixelWidth = Math.round(width)
        const pixelHeight = Math.round(height)
        const rows = Math.min(24, pixelHeight)
        const floor = look.floor + (lightBackground ? 0.014 : 0)
        const cells = colors.map(() => [])
        const visibleColumns = Math.min(columns, pixelWidth)
        for (let col = 0; col < visibleColumns; col++) {
            const first = Math.floor(col * columns / visibleColumns)
            const end = Math.floor((col + 1) * columns / visibleColumns)
            let sample
            for (let source = first; source < end; source++) {
                const frame = history[reducedMotion ? source : (cursor + source) % columns]
                if (frame) sample = sample ? frame.map((level, i) => Math.max(level, sample[i] || 0)) : frame
            }
            if (!sample) continue
            const x = Math.round(col * pixelWidth / visibleColumns)
            const right = Math.round((col + 1) * pixelWidth / visibleColumns)
            const sampleRows = Math.min(rows, sample.length)
            for (let row = 0; row < sampleRows; row++) {
                // Disjoint bin ranges keep a loud bin from smearing across rows.
                const start = Math.floor(row * sample.length / sampleRows)
                const end = Math.floor((row + 1) * sample.length / sampleRows)
                let peak = 0, power = 0
                for (let i = start; i < end; i++) {
                    const value = sample[i]
                    peak = Math.max(peak, value)
                    power += value * value
                }
                const position = (row + 0.5) / sampleRows
                const rowFloor = floor + 0.020 * position * position * position
                    + 0.014 * Math.pow(1 - position, 6)
                if (peak <= rowFloor) continue
                const rms = Math.sqrt(power / (end - start))
                const energy = rms + (peak - rms) * (look.peakMix + (0.06 + 0.055 * position) * (1 - rms / peak))
                if (energy <= rowFloor) continue
                const normalized = Math.min(1, (energy - rowFloor) / (1 - rowFloor))
                const isolated = 1 - rms / peak
                const level = Math.min(1, Math.pow(normalized, look.response)
                    + 0.045 * isolated * Math.sin(Math.PI * normalized))
                const colorIndex = Math.min(colors.length - 1, Math.floor(level * colors.length))
                const upper = pixelHeight - Math.round((row + 1) * pixelHeight / sampleRows)
                const lower = pixelHeight - Math.round(row * pixelHeight / sampleRows)
                cells[colorIndex].push(x, upper, right - x, lower - upper)
            }
        }
        for (let i = 0; i < colors.length; i++) {
            ctx.beginPath()
            for (let j = 0; j < cells[i].length; j += 4)
                ctx.rect(cells[i][j], cells[i][j + 1], cells[i][j + 2], cells[i][j + 3])
            ctx.fillStyle = colors[i]
            const intensity = i / (colors.length - 1)
            ctx.globalAlpha = look.alphaFloor + (look.alphaCeiling - look.alphaFloor)
                * Math.pow(intensity, lightBackground ? 1.04 : 1.18)
            ctx.fill()
        }
        ctx.globalAlpha = 1

        // New samples enter at the right edge and old samples leave at the left.
        const entrance = Math.min(look.edgePixels, width * 0.13, 6 * width / visibleColumns) / width
        const exit = Math.min(look.edgePixels * (lightBackground ? 1.12 : 1.28), width * 0.16) / width
        const mask = ctx.createLinearGradient(0, 0, width, 0)
        mask.addColorStop(0, "transparent")
        mask.addColorStop(exit * 0.34, "#44ffffff")
        mask.addColorStop(exit * 0.70, "#c8ffffff")
        mask.addColorStop(exit, "white")
        mask.addColorStop(1 - entrance, "white")
        mask.addColorStop(1 - entrance * 0.58, "#c2ffffff")
        mask.addColorStop(1 - entrance * 0.24, "#38ffffff")
        mask.addColorStop(1, "transparent")
        ctx.save()
        ctx.globalCompositeOperation = "destination-in"
        ctx.fillStyle = mask
        ctx.fillRect(0, 0, width, height)
        ctx.restore()
    }
}
