.pragma library

function geometry(levels, width, height) {
    const n = levels.length
    if (n < 2 || width <= 0 || height <= 4) return []
    const points = []
    for (let i = 0; i < n; ++i) {
        const value = Math.max(0, Math.min(1, Number(levels[i]) || 0))
        points.push({ x: i * width / (n - 1), y: height - 2 - Math.pow(value, 0.85) * (height - 4), slope: 0 })
    }
    for (let i = 1; i < n - 1; ++i) {
        const left = (points[i].y - points[i-1].y) / (points[i].x - points[i-1].x)
        const right = (points[i+1].y - points[i].y) / (points[i+1].x - points[i].x)
        points[i].slope = left * right <= 0 ? 0 : Math.sign(left) * Math.min(Math.abs((left + right) / 2), 3 * Math.min(Math.abs(left), Math.abs(right)))
    }
    return points
}

function trace(ctx, points) {
    if (!points.length) return
    ctx.moveTo(points[0].x, points[0].y)
    for (let i = 1; i < points.length; ++i) {
        const a = points[i-1], b = points[i], third = (b.x - a.x) / 3
        ctx.bezierCurveTo(a.x + third, a.y + a.slope * third,
                         b.x - third, b.y - b.slope * third, b.x, b.y)
    }
}
