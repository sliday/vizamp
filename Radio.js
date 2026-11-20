.pragma library
function advance(state,oldLevels,levels,heat,seconds,impact) {
    const dt=Math.min(.08,Math.max(.001,seconds)),dose=[],velocity=[],glow=[],acceleration=[],thermal=[]
    const previous=state||{}
    for(let i=0;i<levels.length;i++) {
        const v=oldLevels.length===levels.length?(levels[i]-oldLevels[i])/dt:0
        const a=previous.velocity&&previous.velocity.length===levels.length?(v-previous.velocity[i])/dt:0
        const h=heat[i]||0,old=previous.dose?previous.dose[i]||0:0
        const strike=impact && Math.abs(i-impact.band)<=1 && h>.2
            ? .22*impact.strength*(i===impact.band?1:.5) : 0
        const d=Math.min(3,Math.max(0,old+dt*(h>.62?.7+Math.min(.3,Math.abs(a)/200):-.5)+strike))
        const t=Math.max(0,Math.min(1,(d-.8)/1.2))
        const hot=previous.thermal?previous.thermal[i]||0:0
        thermal.push(Math.min(3,Math.max(0,hot+dt*(h>.82?1.4:-.9))))
        dose.push(d);velocity.push(v);acceleration.push(a);glow.push(t*t*(3-2*t))
    }
    return {dose:dose,velocity:velocity,acceleration:acceleration,glow:glow,thermal:thermal}
}
function strike(state,band,strength,heat) {
    for(let i=Math.max(0,band-1);i<=Math.min(state.dose.length-1,band+1);i++) {
        if(!heat || (heat[i]||0)<=.62)continue
        state.dose[i]=Math.min(3,state.dose[i]+.08*strength*(i===band?1:.5))
        const t=Math.max(0,Math.min(1,(state.dose[i]-.8)/1.2))
        state.glow[i]=t*t*(3-2*t)
    }
    return state
}
