.pragma library

function linear(channel) {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
}

function luminance(rgb) {
    return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2])
}

function contrast(first, second) {
    const a = luminance(first), b = luminance(second)
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

function rgb(color) {
    return [color.r, color.g, color.b]
}

function mix(first, second, amount) {
    return first.map((channel, i) => channel + (second[i] - channel) * amount)
}

function background(bar, theme) {
    const color = mix(rgb(theme), rgb(bar), bar.a)
    return Qt.rgba(color[0], color[1], color[2], 1)
}

function isLight(color) {
    return luminance(color) >= Math.sqrt(0.05 * 1.05) - 0.05
}

function ensureContrast(color, backdrop, minimum) {
    if (contrast(color, backdrop) >= minimum) return color
    const endpoint = isLight(backdrop) ? [0, 0, 0] : [1, 1, 1]
    let low = 0, high = 1
    for (let i = 0; i < 12; i++) {
        const middle = (low + high) / 2
        if (contrast(mix(color, endpoint, middle), backdrop) >= minimum) high = middle
        else low = middle
    }
    return mix(color, endpoint, high)
}

function readableColor(color, backdrop) {
    const corrected = ensureContrast(rgb(color), rgb(backdrop), 4.5)
    return Qt.rgba(corrected[0], corrected[1], corrected[2], 1)
}
