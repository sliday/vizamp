const fs=require('fs'),vm=require('vm'),assert=require('assert');
function load(file){const m={};vm.createContext(m);vm.runInContext(fs.readFileSync(__dirname+'/../'+file,'utf8').replace('.pragma library',''),m);return m;}
const trail=load('Trail.js');let p={x:10,y:10};trail.segment(p,1000);p.x=30;p.y=25;let line=trail.segment(p,1033);assert.equal(line.x0,10);assert.equal(line.y0,10);assert.equal(line.dx,20);assert.equal(line.dy,15);p.drawAt=0;p.x=100;assert.equal(trail.segment(p,1066).dx,0);
assert.equal(trail.edge(0,10,100,20),0);assert.equal(trail.edge(50,0,100,20),0);assert.equal(trail.edge(50,10,100,20),1);
const status=load('Status.js');let state=status.accept({value:{},failures:0,lastGood:0},'{"playing":true,"title":"Live"}',1000);state=status.failed(state,2000);state=status.failed(state,3000);assert.equal(state.value.playing,true);state=status.failed(state,4000);assert.equal(state.value.playing,undefined);state=status.accept(state,'{"playing":false,"title":"Paused"}',4100);assert.equal(state.failures,0);assert.equal(state.value.playing,false);assert.equal(status.label({title:'ELEMENTS',artist:'Radiohead'}),'ELEMENTS - Radiohead');
const motion=load('TitleMotion.js');const g={x:0,y:0,vx:0,vy:0};motion.follow(g,{x:200,y:10},0);assert.equal(g.x,0);motion.follow(g,{x:200,y:10},1/60);assert(g.x>0&&g.x<10);for(let i=0;i<60;i++)motion.follow(g,{x:200,y:10},1/60);assert(Math.abs(g.x-200)<.01);
state=status.accept(state,'{"playing":true,"desktopEntry":"player","canGoNext":true,"canGoPrevious":"false"}',4200);
assert.strictEqual(state.value.desktopEntry,'player');
assert.strictEqual(state.value.canGoNext,true);
assert.strictEqual(state.value.canGoPrevious,false);
console.log('Review regressions passed: swept paths, spawn reset, edge fade, status grace, artist label, continuous springs');
