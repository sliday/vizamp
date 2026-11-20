.pragma library

const laneCount = 6
const travelSeconds = 0.62
const hitSeconds = 0.18
const retriggerSeconds = 0.19
const vibrationSeconds = 0.29
const holdSeconds = 0.15

function advanceHolds(holds, levels, dt) {
    const next = []
    for (const hold of holds) {
        const age = hold.age + dt
        const audible = levels[hold.lane] >= Math.max(0.10, hold.strength * 0.42)
        const gap = audible ? 0 : hold.gap + dt
        const held = hold.held && gap <= 0.052
        const duration = hold.duration + (held ? dt : 0)
        if ((!held && duration < holdSeconds) || age - duration >= travelSeconds) continue
        next.push({ lane: hold.lane, age, duration, held, gap, strength: hold.strength })
    }
    return next
}

function displacement(beat, progress, spacing, heat = 0) {
    if (!beat) return 0
    const distance = 1 - progress
    const front = Math.min(1.2, 0.20 + beat.age * 8.5)
    const reach = Math.max(0, Math.min(1, (front - distance) / 0.18))
    const envelope = reach * Math.sin(Math.PI * progress) * Math.pow(1 - beat.age / vibrationSeconds, 2.8 - 1.3 * beat.strength)
    return Math.sin(beat.age * 75 + (1 - progress) * 12) * envelope * Math.min(1.2, spacing * (0.18 + 0.12 * heat)) * beat.strength
}

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
        arrivals: [],
        beats: Array(laneCount).fill(null),
        holds: []
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
    const startedHolds = []
    for (let lane = 0; lane < laneCount; lane++) {
        const level = energy(levels, lane)
        const baseline = state.baseline[lane]
        const cooldown = Math.max(0, state.cooldown[lane] - dt)
        next.levels[lane] = level
        next.baseline[lane] = baseline + (level - baseline) * (1 - Math.exp(-dt / 0.20))
        next.cooldown[lane] = cooldown
        next.hits[lane] = Math.max(0, state.hits[lane] - dt)
        const beat = state.beats[lane]
        if (!reducedMotion && beat && beat.age + dt < vibrationSeconds)
            next.beats[lane] = { age: beat.age + dt, strength: beat.strength }

        // React to attacks rather than emitting notes for a sustained sound.
        if (cooldown > 0 || level < 0.10
            || level - baseline < 0.045 || level - state.levels[lane] < 0.014) continue
        next.cooldown[lane] = retriggerSeconds
        if (reducedMotion) next.hits[lane] = hitSeconds
        else {
            const velocity = Math.min(1, (level - state.levels[lane]) / Math.max(0.018, dt) / 14)
            next.notes.push({ lane, age: 0, strength: level, velocity })
            if (!state.holds.some(hold => hold.lane === lane && hold.held))
                startedHolds.push({ lane, age: 0, duration: 0, held: true, gap: 0, strength: level })
            const impulse = 0.10 + 0.58 * velocity + 0.32 * level
            const ringing = next.beats[lane]
                ? beat.strength * (1 - next.beats[lane].age / vibrationSeconds) * 0.42 : 0
            next.beats[lane] = { age: 0, strength: impulse + (1 - impulse) * ringing }
        }
    }

    if (!reducedMotion) {
        next.holds = advanceHolds(state.holds, next.levels, dt).concat(startedHolds)
        for (const note of state.notes) {
            const age = note.age + dt
            if (age < travelSeconds) next.notes.push({ lane: note.lane, age, strength: note.strength, velocity: note.velocity })
            else {
                next.hits[note.lane] = hitSeconds
                next.arrivals.push(note)
            }
        }
    }
    return next
}
