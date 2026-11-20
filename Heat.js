.pragma library

function advance(previous,oldLevels,levels,seconds) {
    const dt=Math.min(0.08,Math.max(0.001,seconds))
    return levels.map((v,i)=>{
        const speed=oldLevels.length===levels.length?Math.abs(v-oldLevels[i])/dt:0
        const target=1-Math.exp(-speed*0.22)
        const before=previous[i]||0
        const heat=before+(target-before)*(1-Math.exp(-dt/(target>before?0.025:0.28)))
        return heat<0.001?0:heat
    })
}

var darkStops = [[0.38,0.055,0.025],[0.91,0.24,0.07],[1,0.64,0.24],[1,0.93,0.78],[0.69,0.84,1],[0.94,0.76,1]]
var lightStops = [[0.49,0.15,0.08],[0.66,0.23,0.06],[0.57,0.31,0.02],[0.48,0.25,0.48],[0.13,0.34,0.59],[0.29,0.20,0.67]]

function color(heat, stops) {
    const stars = stops || darkStops
    if(heat>0.8) {
        const t=Math.max(0,Math.min(1,(heat-0.8)/0.2))
        return stars[4].map((channel, i) => channel + (stars[5][i] - channel) * t)
    }
    const t=Math.max(0,Math.min(1,heat/0.8))
    const at=t*4,i=Math.min(3,Math.floor(at)),f=at-i
    return [stars[i][0]+(stars[i+1][0]-stars[i][0])*f,
            stars[i][1]+(stars[i+1][1]-stars[i][1])*f,
            stars[i][2]+(stars[i+1][2]-stars[i][2])*f]
}
