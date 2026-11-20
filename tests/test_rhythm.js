const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(__dirname + "/../Rhythm.js", "utf8");
const rhythm = {};
vm.runInNewContext(source.replace(".pragma library", ""), rhythm);

const silence = Array(24).fill(0);
const impulse = silence.slice();
impulse.fill(0.75, 9, 14);

let state = rhythm.advance(rhythm.empty(), silence, 0.033, false);
assert.equal(state.notes.length, 0);
state = rhythm.advance(state, impulse, 0.033, false);
assert.equal(state.notes.length, 1);
assert.equal(state.notes[0].lane, 2);
assert.equal(state.notes[0].age, 0);

let hit = false;
for (let i = 0; i < 45; i++) {
    state = rhythm.advance(state, impulse, 1 / 30, false);
    assert(state.notes.length <= 1, "A sustained tone must not launch extra notes");
    if (state.hits[2] > 0) hit = true;
}
assert(hit, "A traveling note must light its own hit marker");
assert.equal(state.hits[2], 0);

state = rhythm.advance(rhythm.empty(), impulse, 0.033, true);
assert.equal(state.notes.length, 0);
assert(state.hits[2] > 0, "Reduced motion lights the marker directly");

state = rhythm.empty();
for (let frame = 0; frame < 500; frame++) {
    const levels = frame % 2 ? silence : Array(24).fill(1);
    state = rhythm.advance(state, levels, 0.033, false);
    assert(state.notes.length <= 20, "Repeated attacks must keep the note pool bounded");
}

console.log("Rhythm passed: frequency lanes, onset detection, arrivals, reduced motion and note limits");
