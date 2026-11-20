const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

function load(file, globals = {}) {
    const source = fs.readFileSync(__dirname + "/../" + file, "utf8");
    vm.runInNewContext(source.replace(".pragma library", ""), globals);
    return globals;
}

const palette = load("Palette.js", { Qt: { rgba: (r, g, b, a) => ({ r, g, b, a }) } });
const heat = load("Heat.js");
const white = [1, 1, 1];
const cream = [0.95, 0.91, 0.84];
const dark = [0.07, 0.08, 0.09];
const gray = [0.48, 0.48, 0.48];
for (const backdrop of [white, cream, gray]) {
    assert(palette.isLight(backdrop));
    const stops = heat.lightStops.map(color => palette.ensureContrast(color, backdrop, 4.5));
    for (let i = 0; i <= 100; i++) {
        assert(palette.contrast(heat.color(i / 100, stops), backdrop) >= 4.5);
    }
}
assert(!palette.isLight(dark));
assert(palette.contrast(palette.ensureContrast(dark, dark, 4.5), dark) >= 4.5);
const translucent = palette.background({ r: 0, g: 0, b: 0, a: 0.05 }, { r: 1, g: 1, b: 1 });
assert(palette.isLight(palette.rgb(translucent)));
console.log("Palette passed: live light/dark selection and contrast across the light gradient");
