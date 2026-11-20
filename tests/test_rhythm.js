const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(__dirname + "/../Rhythm.js", "utf8");
const rhythm = {};
vm.runInNewContext(source.replace(".pragma library", ""), rhythm);

const silence = Array(24).fill(0);
const laneCount = 8;
assert.equal(rhythm.empty().levels.length, laneCount);
for (let lane = 0; lane < laneCount; lane++) {
    const levels = silence.slice();
    levels.fill(0.75, lane * 3, lane * 3 + 3);
    const { notes } = rhythm.advance(rhythm.empty(), levels, 0.033, false);
    assert.deepEqual(Array.from(notes, note => note.lane), [lane], "Each string receives three FFT bands");
}
const impulse = silence.slice();
impulse.fill(0.75, 6, 9);

let state = rhythm.advance(rhythm.empty(), silence, 0.033, false);
assert.equal(state.notes.length, 0);
state = rhythm.advance(state, impulse, 0.033, false);
assert.equal(state.notes.length, 1);
assert.equal(state.notes[0].lane, 2);
assert.equal(state.notes[0].age, 0);
assert.equal(state.notes[0].velocity, 1);
assert(state.beats[2] && state.beats.filter(Boolean).length === 1, "An attack only excites its string");

let arrivalTime;
for (let i = 0; i < 45; i++) {
    state = rhythm.advance(state, impulse, 1 / 30, false);
    assert(state.notes.length <= 1, "A sustained tone must not launch extra notes");
    if (arrivalTime === undefined && state.hits[2] > 0) arrivalTime = (i + 1) / 30;
}
assert(arrivalTime >= 0.70 && arrivalTime <= 0.70 + 1 / 30, "A note must reach its own hit marker after about 700 ms");
assert.equal(state.hits[2], 0);
assert.equal(state.beats[2], null, "Vibration must settle under a sustained signal");
assert(state.holds[0].held && state.holds[0].duration > 1, "A sustained tone keeps a single line active");
state = rhythm.advance(state, silence, 1 / 30, false);
assert(state.holds[0].held, "A short dip must not cut a hold in two");
state = rhythm.advance(state, silence, 1 / 30, false);
assert.equal(state.holds[0].held, false);
for (let i = 0; i < 23; i++) state = rhythm.advance(state, silence, 1 / 30, false);
assert.equal(state.holds.length, 0, "A released hold must leave the renderer");

state = rhythm.advance(rhythm.empty(), impulse, 0.033, true);
assert.equal(state.notes.length, 0);
assert.equal(state.holds.length, 0);
assert(state.beats.every(beat => !beat));
assert(state.hits[2] > 0, "Reduced motion lights the marker directly");

state = rhythm.empty();
for (let frame = 0; frame < 500; frame++) {
    const levels = frame % 2 ? silence : Array(24).fill(1);
    state = rhythm.advance(state, levels, 0.033, false);
    assert(state.notes.length <= 4 * laneCount, "Repeated attacks must keep the note pool bounded");
    assert(state.holds.length <= 36, "Repeated attacks must keep the hold pool bounded");
}

for (const height of [9, 20]) {
    for (let step = 0; step <= 20; step++) {
        const progress = step / 20;
        const positions = Array.from({ length: laneCount }, (_, lane) => {
            const beat = { age: 0.06 + lane * 0.014, strength: 1 };
            return rhythm.noteY(lane, progress, 1, 0.42, height)
                + rhythm.displacement(beat, progress, height / laneCount, 1);
        });
        assert(positions.every(y => y > 0 && y < height), "Notes must stay inside the canvas");
        assert(positions.every((y, i) => i === 0 || y < positions[i - 1]), "Notes must stay on separate strings");
        if (step === 0 || step === 20) {
            for (let lane = 0; lane < laneCount; lane++)
                assert(Math.abs(positions[lane] - rhythm.laneY(lane, progress, height)) < 1e-9,
                    "Motion should meet its string at spawn and at the hit line");
        }
    }
}
console.log("Rhythm passed: eight strings, onsets, arrivals, reduced motion, note limits and paths");
