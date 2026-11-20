.pragma library
var contactOrder=[]
var topInset = 3
var gravity = 155

function limitRise(grain) {
    const acceleration = grain.radio > 0 ? gravity * 0.12 : gravity
    const maxSpeed = grain.radio > 0 ? 10 : 29
    // Leave enough room for gravity to stop the particle inside the canvas.
    const room = Math.max(0, grain.y - topInset)
    grain.vy = Math.max(grain.vy, -Math.min(maxSpeed, Math.sqrt(2 * acceleration * room)))
}

function surface(points, x) {
    if (points.length < 2) return {y:0,slope:0}
    let i=0
    while(i<points.length-2 && x>points[i+1].x)i++
    const a=points[i],b=points[i+1],dx=b.x-a.x
    const t=Math.max(0,Math.min(1,(x-a.x)/dx))
    return {
        y:(2*t*t*t-3*t*t+1)*a.y+(t*t*t-2*t*t+t)*dx*a.slope+(-2*t*t*t+3*t*t)*b.y+(t*t*t-t*t)*dx*b.slope,
        slope:((6*t*t-6*t)*a.y+(3*t*t-4*t+1)*dx*a.slope+(-6*t*t+6*t)*b.y+(3*t*t-2*t)*dx*b.slope)/dx
    }
}

function create(points,width,rest,rng) {
    const x=3+rng()*(width-6),g=surface(points,x),size=0.55+rng()*0.5
    return {x:x,y:Math.max(topInset,g.y-size/2-(rest?0:1+rng()*2)),drawX:x,drawY:g.y-size/2,drawAt:0,vx:rest?0:(rng()-0.5)*8,
        vy:rest?0:-1.333333-rng()*3.333333,ground:g.y,air:!rest,size:size,
        mass:size*size*1.5,age:rest?rng():0,life:7.5+rng()*15,
        restitution:0.35+rng()*0.3,drag:0.45+rng()*0.45}
}

function seed(points,width,count,rng) {
    rng=rng||Math.random
    const grains=[]
    for(let i=0;i<count;i++)grains.push(create(points,width,true,rng))
    return grains
}

function advance(grains,points,seconds,width,rng) {
    rng=rng||Math.random
    const dt=Math.min(0.033,Math.max(0.001,seconds))
    for(let i=0;i<grains.length;i++) {
        const p=grains[i]
        p.age+=dt
        p.spark=Math.max(0,(p.spark||0)-dt)
        p.radio=Math.max(0,(p.radio||0)-dt)
        if(p.age>p.life || p.x<1 || p.x>width-1 || !isFinite(p.y)) {
            Object.assign(p,create(points,width,false,rng))
            continue
        }
        const response=Math.min(1,p.size*p.size/p.mass)
        const ground=surface(points,p.x)
        const velocity=Math.max(-100,Math.min(100,(ground.y-p.ground)/dt))
        const norm=Math.sqrt(1+ground.slope*ground.slope)
        const nx=ground.slope/norm,ny=-1/norm
        if(!p.air) {
            if(velocity < -7) {
                const kick=Math.min(65,-velocity*1.1+4)*response*2
                p.air=true
                p.vx+=nx*kick+(rng()-0.5)*kick*0.18
                p.vy=ny*kick/1.5
            } else if(ground.y-p.ground>0.45) {p.air=true;p.vy=0}
            else p.vx=(p.vx+ground.slope*35*dt)*Math.exp(-5*dt)
        }
        if(p.air) {
            p.vx*=Math.exp(-p.drag*dt)
            p.vy=Math.min(72*response,p.vy+gravity*(p.radio>0?0.12:1)*dt)
            limitRise(p)
            p.y+=p.vy*dt
        }
        p.x+=p.vx*dt
        if(p.x<2 || p.x>width-2) {
            Object.assign(p,create(points,width,false,rng))
            continue
        }
        const landing=surface(points,p.x)
        const length=Math.sqrt(1+landing.slope*landing.slope)
        const normalX=landing.slope/length,normalY=-1/length
        const impact=p.vx*normalX+(p.vy-velocity)*normalY
        if(p.air && !(p.radio>0) && p.y>=landing.y-p.size/2 && impact<0) {
            const correction=landing.y-p.size/2-p.y
            p.y+=Math.max(-0.55,Math.min(0.55,correction))
            p.vx-=(1+p.restitution)*impact*normalX*response
            p.vy-=(1+p.restitution)*impact*normalY*response
            p.vx*=0.78
            if(Math.abs(p.vy-velocity)<9 && Math.abs(velocity)<20) {p.air=false;p.vy=0}
        } else if(!p.air) {
            const correction=landing.y-p.size/2-p.y
            p.y+=Math.max(-0.55,Math.min(0.55,correction))
        }
        p.ground=landing.y
    }
    // X-sorted broad phase: distant pairs never need a distance calculation.
    contactOrder.length=grains.length
    for(let i=0;i<grains.length;i++)contactOrder[i]=i
    contactOrder.sort((a,b)=>grains[a].x-grains[b].x)
    for(let i=0;i<contactOrder.length;i++)for(let j=i+1;j<contactOrder.length;j++) {
        const a=grains[contactOrder[i]],b=grains[contactOrder[j]],dx=b.x-a.x,dy=b.y-a.y
        if(dx>2)break
        if(a.radio>0 || b.radio>0 || Math.abs(dy)>1.1)continue
        const distance=Math.sqrt(dx*dx+dy*dy),contact=(a.size+b.size)*0.5
        if(distance>=contact)continue
        const nx=distance>0.001?dx/distance:1,ny=distance>0.001?dy/distance:0
        const overlap=(contact-distance)*0.5
        a.x-=nx*overlap;b.x+=nx*overlap
        if(a.air)a.y-=ny*overlap
        if(b.air)b.y+=ny*overlap
        const closing=(b.vx-a.vx)*nx+(b.vy-a.vy)*ny
        if(closing>=0)continue
        const impulse=-(1+Math.min(a.restitution,b.restitution))*closing/(1/a.mass+1/b.mass)
        a.vx-=impulse*nx/a.mass;b.vx+=impulse*nx/b.mass
        a.vy-=impulse*ny/a.mass;b.vy+=impulse*ny/b.mass
        if(a.vy < -4)a.air=true
        if(b.vy < -4)b.air=true
    }
    for (const grain of grains) {
        grain.y = Math.max(topInset, grain.y)
        limitRise(grain)
    }
    return grains
}

function explode(grains,x,y,strength,rng,requestedCount) {
    rng=rng||Math.random
    const nearest=grains.map((g,i)=>({i:i,d:(g.x-x)*(g.x-x)+(g.y-y)*(g.y-y)})).sort((a,b)=>a.d-b.d)
    const count=Math.min(requestedCount||14,nearest.length)
    for(let i=0;i<count;i++) {
        const g=grains[nearest[i].i],angle=-Math.PI+rng()*Math.PI
        const impulse=(28+rng()*22)*Math.min(1.4,strength)*Math.min(1,g.size*g.size/g.mass)*2
        g.vx+=Math.cos(angle)*impulse
        g.vy=Math.min(g.vy,(Math.sin(angle)*impulse-6)/1.5)
        g.air=true;g.radio=0;g.spark=0.2+rng()*0.14
        limitRise(g)
    }
    return grains
}

function radiate(grains,x,y,rng) {
    rng=rng||Math.random
    let choice=-1,distance=Infinity
    for(let i=0;i<grains.length;i++) {
        const g=grains[i],d=(g.x-x)*(g.x-x)+(g.y-y)*(g.y-y)
        if(!(g.spark>0)&&!(g.radio>0)&&d<distance){choice=i;distance=d}
    }
    if(choice>=0) {
        const g=grains[choice],angle=rng()*Math.PI*2,speed=(9+rng()*12)*Math.min(1,g.size*g.size/g.mass)*2
        g.x=x;g.y=Math.max(topInset,y-.8);g.vx=Math.cos(angle)*speed;g.vy=Math.sin(angle)*speed/1.5
        g.drawX=g.x;g.drawY=g.y;g.drawAt=0
        g.air=true;g.radio=.7
        limitRise(g)
    }
    return choice
}
