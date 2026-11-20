.pragma library

const sparkLimit = 36

function advance(sparks, arrivals, laneHeat, dt, look, random = Math.random) {
    const next = []
    for (const spark of sparks) {
        const age = spark.age + dt
        if (age >= spark.life) continue
        const y = Math.min(0.38, Math.max(-0.38, spark.y + spark.vy * dt))
        next.push({
            lane: spark.lane, age, life: spark.life, heat: spark.heat,
            x: spark.x + spark.vx * dt, y, oldX: spark.x, oldY: spark.y,
            vx: spark.vx * Math.exp(-dt * 4.2),
            vy: spark.vy + dt * 1.4
        })
    }
    for (const note of arrivals) {
        const heat = Math.max(0.5 + note.strength * 0.4, laneHeat[note.lane] || 0)
        const count = Math.max(1, Math.round(look.sparkCount * (0.55 + 0.45 * note.strength)))
        for (let i = 0; i < count && next.length < sparkLimit; i++) {
            const y = (random() - 0.5) * 0.18
            next.push({
                lane: note.lane, x: 0, y, oldX: 0, oldY: y, age: 0,
                vx: look.sparkSpeed * (0.55 + random() * 0.7),
                vy: (random() - 0.5) * 3.2,
                life: look.sparkLife * (0.82 + 0.36 * random()),
                heat
            })
        }
    }
    return next
}
