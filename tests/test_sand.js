const vm=require('vm'),fs=require('fs'),assert=require('assert');
const s={};vm.createContext(s);vm.runInContext(fs.readFileSync(__dirname+'/../Sand.js','utf8').replace('.pragma library',''),s);
const ground=(y,slope=0)=>[{x:0,y,slope},{x:194,y:y+194*slope,slope}];
let g=s.seed(ground(13),194,1,()=>.5);g[0].life=1000;
for(let i=0;i<60;i++)g=s.advance(g,ground(13),1/60,194,()=>.5);
assert(!g[0].air);assert(Math.abs(g[0].y-(13-g[0].size/2))<1e-6);
g=s.advance(g,ground(9),1/60,194,()=>.5);assert(g[0].air&&g[0].vy<0);
let y=g[0].y;g=s.advance(g,ground(9),1/60,194,()=>.5);assert(g[0].y<y);
for(let i=0;i<180;i++)g=s.advance(g,ground(9),1/60,194,()=>.5);
assert(!g[0].air);
let slope=s.seed(ground(8,.02),194,1,()=>.5);slope=s.advance(slope,ground(5,.02),1/60,194,()=>.5);assert(slope[0].vx>0,'Slope must provide a sideways impulse');
let state=123;const rng=()=>((state=(1664525*state+1013904223)>>>0)/4294967296);
let pool=s.seed(ground(13),194,176,rng),recycled=0;const refs=pool.slice();
for(let frame=0;frame<900;frame++){
 const ages=pool.map(p=>p.age);pool=s.advance(pool,ground(11+3*Math.sin(frame*.04)),1/60,194,rng);
 assert.equal(pool.length,176);pool.forEach((p,i)=>{assert.strictEqual(p,refs[i]);assert(Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.vx)&&Number.isFinite(p.vy));if(p.age<ages[i])recycled++;});
}
assert(recycled>10,'New grains must continuously recycle into the fixed pool');

// Loud peaks can launch specks from only a few pixels below the canvas edge.
for (const step of [1 / 30, 1 / 60, 1 / 144]) {
    const loudPeak = ground(4);
    const sparks = s.seed(loudPeak, 194, 24, rng);
    s.explode(sparks, 97, 4, 1.4, rng, sparks.length);
    const specks = s.seed(loudPeak, 194, 1, rng);
    s.radiate(specks, 97, 4, () => 0.75);
    assert(specks[0].vy < 0, "The speck should still lift off");
    const grains = sparks.concat(specks);
    assert(sparks.some(p => Math.abs(p.vx) > 10), "Bursts should still spread sideways");
    for (let t = 0; t < 0.8; t += step) {
        s.advance(grains, loudPeak, step, 194, rng);
        assert(grains.every(p => p.y >= 3), "Upward bursts must remain visible");
    }
}
console.log('Sand passed: settling, sideways motion, visible bursts, collisions and recycling');
