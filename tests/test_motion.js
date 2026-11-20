const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const motion = {};
vm.createContext(motion);
vm.runInContext(fs.readFileSync(__dirname + '/../Motion.js', 'utf8').replace('.pragma library', ''), motion);
function simulate(step, duration, target, state = motion.empty(24)) {
    for (let t = 0; t < duration - 1e-8; t += step)
        state = motion.advance(state, Array(24).fill(target), step);
    return state;
}
const at30 = simulate(1/30, 1, 1), at60 = simulate(1/60, 1, 1);
assert(Math.abs(at30.levels[0] - at60.levels[0]) < 0.001);
assert(at60.levels[0] > 0.99);
const settled = simulate(1/60, 1, 0, at60);
assert(settled.levels[0] < 0.002);
assert(settled.peaks[0] < 0.02);
assert(settled.levels.every(Number.isFinite));
const short = simulate(1/60, 0.1, 0, at60);
assert(short.peaks[0] > short.levels[0]);
console.log('Motion: frame-rate independence, attack, release, peak hold and settling passed');
