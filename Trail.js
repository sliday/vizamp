.pragma library
function segment(g,now) {
    const fresh=!isFinite(g.drawX)||!isFinite(g.drawY)||!g.drawAt||now-g.drawAt>200
    const fromX=fresh?g.x:g.drawX,fromY=fresh?g.y:g.drawY
    g.drawX=g.x;g.drawY=g.y;g.drawAt=now
    return {x0:fromX,y0:fromY,x1:g.x,y1:g.y,dx:g.x-fromX,dy:g.y-fromY}
}
function edge(x,y,width,height) {
    return Math.min(1,Math.max(0,Math.min(x,width-x)/4))*Math.min(1,Math.max(0,Math.min(y,height-y)/2.5))
}
