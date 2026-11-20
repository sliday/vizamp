.pragma library

function ratio(position,duration) {
    return isFinite(position)&&isFinite(duration)&&position>=0&&duration>0 ? Math.max(0,Math.min(1,position/duration)) : -1
}
function density(progress,fraction) {
    if(progress<=0)return 0
    if(progress>=1)return 1
    const t=Math.max(0,Math.min(1,(progress-fraction)/0.035))
    return t*t*(3-2*t)
}
function clock(seconds) {
    const s=Math.max(0,Math.floor(seconds)),m=Math.floor(s/60)
    return m+":"+String(s%60).padStart(2,"0")
}
