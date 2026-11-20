.pragma library

function empty(count) {
    return { levels: Array(count).fill(0), peaks: Array(count).fill(0),
             holds: Array(count).fill(0), speeds: Array(count).fill(0) }
}

function advance(state, target, seconds) {
    const dt = Math.min(0.08, Math.max(0.001, seconds))
    const next = empty(target.length)
    for (let i = 0; i < target.length; ++i) {
        const previous = state.levels[i]
        const tau = target[i] > previous ? 0.035 : 0.145
        let value = previous + (target[i] - previous) * (1 - Math.exp(-dt / tau))
        if (value < 0.001) value = 0
        next.levels[i] = value
        let peak = state.peaks[i], hold = state.holds[i], speed = state.speeds[i]
        if (value >= peak) { peak = value; hold = 0.14; speed = 0 }
        else if (hold > 0) hold = Math.max(0, hold - dt)
        else {
            speed = Math.min(2.0, speed + 3.8 * dt)
            peak = Math.max(value, peak - speed * dt)
        }
        next.peaks[i] = peak
        next.holds[i] = hold
        next.speeds[i] = speed
    }
    return next
}
