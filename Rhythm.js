.pragma library

const laneCount = 6
const travelSeconds = 0.62
const hitSeconds = 0.18
const retriggerSeconds = 0.19

function laneY(lane, progress, height, taperLimit = 0.27) {
    const spacing = height / laneCount
    const taper = Math.min(taperLimit, Math.max(0, (spacing - 1.2) * 0.16))
    const offset = ((laneCount - 1) / 2 - lane) * spacing
    return height / 2 + offset * (1 - taper * (1 - progress))
}

function noteY(lane, progress, strength, clock, height, taperLimit = 0.27, sway = 0.25) {
    const amplitude = Math.min(1.35, height / laneCount * sway)
    const envelope = Math.sin(Math.PI * progress)
    const wave = Math.sin(progress * 8 + lane * 1.37 + clock * 3.1)
    return laneY(lane, progress, height, taperLimit) + wave * envelope * amplitude * (0.35 + 0.65 * strength)
}

function empty() {
    return {
        levels: Array(laneCount).fill(0),
        baseline: Array(laneCount).fill(0),
        cooldown: Array(laneCount).fill(0),
        hits: Array(laneCount).fill(0),
        notes: [],
        arrivals: []
    }
}

function energy(levels, lane) {
    const start = Math.floor(lane * levels.length / laneCount)
    const end = Math.floor((lane + 1) * levels.length / laneCount)
    let power = 0
    for (let i = start; i < end; i++) power += levels[i] * levels[i]
    return end > start ? Math.sqrt(power / (end - start)) : 0
}

function advance(state, levels, seconds, reducedMotion) {
    const dt = Math.min(0.1, Math.max(0, seconds))
    const next = empty()
    for (let lane = 0; lane < laneCount; lane++) {
        const level = energy(levels, lane)
        const baseline = state.baseline[lane]
        const cooldown = Math.max(0, state.cooldown[lane] - dt)
        next.levels[lane] = level
        next.baseline[lane] = baseline + (level - baseline) * (1 - Math.exp(-dt / 0.20))
        next.cooldown[lane] = cooldown
        next.hits[lane] = Math.max(0, state.hits[lane] - dt)

        // React to attacks rather than emitting notes for a sustained sound.
        if (cooldown > 0 || level < 0.10
            || level - baseline < 0.045 || level - state.levels[lane] < 0.014) continue
        next.cooldown[lane] = retriggerSeconds
        if (reducedMotion) next.hits[lane] = hitSeconds
        else next.notes.push({ lane, age: 0, strength: level })
    }

    if (!reducedMotion) {
        for (const note of state.notes) {
            const age = note.age + dt
            if (age < travelSeconds) next.notes.push({ lane: note.lane, age, strength: note.strength })
            else {
                next.hits[note.lane] = hitSeconds
                next.arrivals.push(note)
            }
        }
    }
    return next
}
