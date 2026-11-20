.pragma library
function advance(state,levels,previous,seconds) {
    const dt=Math.max(.001,Math.min(.08,seconds)),packets=[],arrivals=[]
    const old=state.packets||[],cooldown=(state.cooldown||Array(levels.length).fill(0)).map(t=>Math.max(0,t-dt))
    for(let i=0;i<old.length;i++) {
        const p=old[i],travel=p.travel+dt*(2+p.energy*2)
        const next={band:p.band,energy:p.energy,travel:travel}
        if(travel>=1)arrivals.push(next)
        else packets.push(next)
    }
    const candidates=[]
    if(previous.length===levels.length)for(let i=0;i<levels.length;i++) {
        const delta=levels[i]-previous[i],velocity=delta/dt
        if(delta>.01 && velocity>.45 && !(cooldown[i]>0) && !packets.some(p=>p.band===i))
            candidates.push({band:i,velocity:velocity,energy:Math.min(1,Math.max(0,(velocity-.4)/6+delta*2))})
    }
    candidates.sort((a,b)=>b.velocity-a.velocity)
    let launched=0,lastBand=-9
    for(let i=0;i<candidates.length && launched<2 && packets.length<48;i++) {
        const c=candidates[i]
        if(Math.abs(c.band-lastBand)<2)continue
        packets.push({band:c.band,energy:c.energy,travel:0});cooldown[c.band]=.2;lastBand=c.band;launched++
    }
    return {packets:packets,arrivals:arrivals,cooldown:cooldown}
}
function assign(packets,fractions,bandCount) {
    return packets.map(p=>{
        const target=p.band/Math.max(1,bandCount-1)
        let best=0,distance=Infinity
        for(let i=0;i<fractions.length;i++)if(Math.abs(fractions[i]-target)<distance){best=i;distance=Math.abs(fractions[i]-target)}
        return best
    })
}
