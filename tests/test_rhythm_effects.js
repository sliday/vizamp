const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const effects = {};
const source = fs.readFileSync(__dirname + "/../RhythmEffects.js", "utf8");
vm.runInNewContext(source.replace(".pragma library", ""), effects);

const look = { sparkCount: 5, sparkSpeed: 85, sparkLife: 0.30 };
const arrivals = Array.from({ length: 6 }, (_, lane) => ({ lane, strength: 1 }));
const fixedRandom = () => 0.99;
let sparks = effects.advance([], [], [], 0.033, look, fixedRandom);
assert.equal(sparks.length, 0);
sparks = effects.advance(sparks, arrivals, [], 0.033, look, fixedRandom);
assert.equal(sparks.length, 30);

for (let frame = 0; frame < 100; frame++) {
    sparks = effects.advance(sparks, arrivals, [], 0.033, look, fixedRandom);
    assert(sparks.length <= 36, "Sparks must stay within the rendering budget");
    assert(sparks.every(spark => Math.abs(spark.y) <= 0.38), "Sparks must stay within their string");
    assert(sparks.every(spark => spark.x >= spark.oldX), "Trails should follow the spark");
}
for (let frame = 0; frame < 12; frame++)
    sparks = effects.advance(sparks, [], [], 0.033, look, fixedRandom);
assert.equal(sparks.length, 0, "Sparks must expire after playback stops producing arrivals");

console.log("Rhythm effects passed: hit particles, limits, strings, and expiration");
