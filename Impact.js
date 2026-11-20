.pragma library
function begin(state,count,seconds) {
    const work=[],dt=Math.max(.001,Math.min(.08,seconds))
    for(let i=0;i<count;i++)work.push((state.work?state.work[i]||0:0)*Math.exp(-dt/.35))
    return {work:work,hit:false,band:0,strength:0}
}
function strike(state,band,strength) {
    for(let i=0;i<state.work.length;i++) {
        const distance=(i-band)/1.4
        state.work[i]=Math.min(.65,state.work[i]+strength*.45*Math.exp(-distance*distance))
    }
    state.hit=true;state.band=band;state.strength=strength
    return state
}
function thickness(work) {
    const t=Math.max(0,Math.min(1,work/.65))
    return .65+3.65*Math.pow(t,2.1)
}
