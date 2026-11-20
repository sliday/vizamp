.pragma library
function follow(g,target,seconds) {
    const dt=Math.min(.05,Math.max(0,seconds)),omega=16,decay=Math.exp(-omega*dt)
    const dx=g.x-target.x,dy=g.y-target.y
    const cx=((g.vx||0)+omega*dx)*dt,cy=((g.vy||0)+omega*dy)*dt
    g.x=target.x+(dx+cx)*decay;g.y=target.y+(dy+cy)*decay
    g.vx=((g.vx||0)-omega*cx)*decay;g.vy=((g.vy||0)-omega*cy)*decay
}
