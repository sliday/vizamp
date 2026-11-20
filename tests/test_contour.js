const fs = require('fs'), vm = require('vm'), assert = require('assert');
const contour = {};
vm.createContext(contour);
vm.runInContext(fs.readFileSync(__dirname + '/../Contour.js','utf8').replace('.pragma library',''),contour);
function check(levels) {
    const points=contour.geometry(levels,194,20);
    assert.equal(points.length,levels.length);
    for(let i=0;i<points.length;i++) {
        const p=points[i]; assert(p.x>=0 && p.x<=194 && p.y>=2 && p.y<=18);
        if(!i) continue;
        const a=points[i-1], b=p, third=(b.x-a.x)/3;
        const controls=[a.y,a.y+a.slope*third,b.y-b.slope*third,b.y];
        for(let step=0;step<=20;step++) {
            const t=step/20,u=1-t;
            const y=u*u*u*controls[0]+3*u*u*t*controls[1]+3*u*t*t*controls[2]+t*t*t*controls[3];
            assert(y>=Math.min(a.y,b.y)-1e-8 && y<=Math.max(a.y,b.y)+1e-8,'Curve overshoots measured spectrum');
        }
    }
}
check(Array(24).fill(0));check(Array.from({length:24},(_,i)=>i/23));
check(Array.from({length:24},(_,i)=>i%2));
check(Array.from({length:24},(_,i)=>i===7?1:0));
assert.equal(contour.geometry([],194,20).length,0);
assert.equal(contour.geometry([0,1],0,20).length,0);
console.log('Contour: bounds, monotonic interpolation, sharp peaks and empty frames passed');
