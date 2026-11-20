import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Contour.js" as Contour
import "Sand.js" as Sand
import "Heat.js" as Heat
import "Progress.js" as Progress
import "Magnet.js" as Magnet
import "Palette.js" as Palette
import "Radio.js" as Radio
import "Impact.js" as Impact
import "Pulse.js" as Pulse
import "Trail.js" as Trail

Canvas {
    id: root
    property var levels: []
    property var peaks: []
    property real progress: -1
    property string trackKey: ""
    onTrackKeyChanged: { resetHistory = true; requestPaint() }
    property real reveal: 1
    property real handoff: 0
    property color peakColor: Commons.Color.foreground
    property color background: Commons.Color.bar.background
    property color ink: Commons.Color.accent
    readonly property var backdrop: Palette.rgb(background)
    readonly property bool lightBackground: Palette.isLight(backdrop)
    readonly property var heatStops: lightBackground
        ? Heat.lightStops.map(color => Palette.ensureContrast(color, backdrop, 4.5))
        : Heat.darkStops
    readonly property string radioactiveInk: lightBackground
        ? rgb(Palette.ensureContrast([0.17, 0.36, 0.09], backdrop, 4.5)) : "#e1f7ce"
    implicitWidth: 194
    implicitHeight: 20
    antialiasing: true
    readonly property int grainLimit: 176
    property var grains: []
    property var bandHeat: []
    property var priorLevels: []
    property var priorSpeeds: []
    property double lastBurst: 0
    property double nextRadiate: 0
    property var radioState: ({})
    property var impactState: ({})
    property var pulseState: ({})
    property double lastPaint: 0
    property double vibrationClock: 0
    property double silenceSince: 0
    property bool hasHistory: false
    property bool draining: false
    property bool resetHistory: true
    onVisibleChanged: { resetHistory = true; if (visible) requestPaint() }
    Timer { interval: 33; running: root.visible && root.draining; repeat: true; onTriggered: root.requestPaint() }
    onHandoffChanged: requestPaint()
    onRevealChanged: requestPaint()
    onLevelsChanged: requestPaint()
    onPeaksChanged: requestPaint()
    onInkChanged: { resetHistory = true; requestPaint() }
    onBackgroundChanged: { resetHistory = true; requestPaint() }
    onPeakColorChanged: requestPaint()
    onWidthChanged: { resetHistory = true; requestPaint() }
    onHeightChanged: { resetHistory = true; requestPaint() }

    function rgba(color, alpha) {
        return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")"
    }

    function rgb(color) {
        return "rgb(" + Math.round(color[0]*255) + "," + Math.round(color[1]*255) + "," + Math.round(color[2]*255) + ")"
    }

    function heatColor(heat) {
        return rgb(Heat.color(heat, heatStops))
    }

    function floorFade(value) {
        const t = Math.min(1, Math.max(0, value / 0.09))
        return t * t * (3 - 2 * t)
    }

    onPaint: {
        const ctx = getContext("2d")
        const now = Date.now()
        const dt = lastPaint ? (now - lastPaint) / 1000 : 0.016
        lastPaint = now
        ctx.globalAlpha = 1
        if (resetHistory || dt > 0.25 || Style.reduceMotion) {
            ctx.clearRect(0, 0, width, height)
            if (resetHistory || dt > 0.25) { if (handoff < 0.02) grains = []; bandHeat = []; priorLevels = []; radioState = ({}); impactState = ({}); pulseState=({}) }
            resetHistory = false
        } else {
            // Feedback persistence: erase a fraction of history, never paint a black veil.
            ctx.globalCompositeOperation = "destination-out"
            ctx.fillStyle = "black"
            ctx.globalAlpha = 1 - Math.exp(-dt / (handoff > 0.01 ? 0.055 : 0.115))
            ctx.fillRect(0, 0, width, height)
            ctx.globalAlpha = 1
        }
        ctx.globalCompositeOperation = "source-over"
        if (height < 9 || width < 10) return
        pulseState=Style.reduceMotion||handoff>.02?({packets:[],arrivals:[],cooldown:[]}):Pulse.advance(pulseState,levels,priorLevels,dt)
        impactState=Impact.begin(impactState,levels.length,dt)
        bandHeat = Heat.advance(bandHeat, priorLevels, levels, dt)
        radioState=Radio.advance(radioState,priorLevels,levels,bandHeat,dt,null)
        priorLevels = levels.slice()
        if (!levels.length || Math.max.apply(null, levels) <= 0.001) {
            if (!silenceSince) silenceSince = now
            draining = hasHistory && now - silenceSince < 600
            if (!draining) { ctx.clearRect(0, 0, width, height); hasHistory = false; grains = [] }
            return
        }
        silenceSince = 0
        hasHistory = true
        draining = false
        vibrationClock += Math.min(0.05, Math.max(0, dt))
        const fold = handoff * 0.7
        const baseline = (height - 2) * (1 - fold) + height / 2 * fold
        const allPoints = Contour.geometry(levels.map(v => v * reveal), width, height - 3).map(p => ({
            x: p.x, y: (p.y + 3) * (1 - fold) + height / 2 * fold, slope: p.slope * (1 - fold)
        }))
        const points = allPoints
        const worked = Style.reduceMotion ? [] : (impactState.work || [])
        const wash = ctx.createLinearGradient(0, 1, 0, height)
        wash.addColorStop(0, root.rgba(ink, 0.17))
        wash.addColorStop(1, root.rgba(ink, 0.015))
        ctx.beginPath()
        Contour.trace(ctx, points)
        ctx.lineTo(points[points.length - 1].x, baseline)
        ctx.lineTo(points[0].x, baseline)
        ctx.closePath()
        ctx.fillStyle = wash
        ctx.globalAlpha = 0.15
        ctx.fill()
        ctx.globalAlpha = 1

        // Fine columns expose the actual frequency bands inside the flowing ridge.
        const columns = ctx.createLinearGradient(0, 0, 0, height - 2)
        columns.addColorStop(0, root.rgba(ink, lightBackground ? 0.85 : 0.65))
        columns.addColorStop(0.55, root.rgba(ink, 0.38))
        columns.addColorStop(1, root.rgba(ink, 0.035))
        ctx.strokeStyle = columns
        ctx.lineWidth = 1.5
        ctx.lineCap = "round"
        const contacts=[]
        const sproutCount=48
        const fractions=Array.from({length:sproutCount},(_,i)=>Magnet.position(i,sproutCount,root.progress))
        const lightRoots=Pulse.assign(pulseState.packets||[],fractions,levels.length)
        const arrivalRoots=Pulse.assign(pulseState.arrivals||[],fractions,levels.length)
        for (let i=0; i<sproutCount; ++i) {
            const fraction=fractions[i]
            const x=fraction*width
            const amplitude=Magnet.sample(levels,fraction)
            const temperature=Magnet.sample(bandHeat,fraction)
            ctx.strokeStyle = columns
            ctx.lineWidth = 1.5
            ctx.globalAlpha = root.floorFade(amplitude * reveal) * 0.35
            ctx.beginPath()
            const tip = Sand.surface(points,x).y + 0.5
            const rise = Math.max(0, baseline - tip)
            // Compress actual band frequencies to visible vibration rates (~0.6–3.4 Hz).
            const frequency = 45 * Math.pow(10000 / 45, fraction)
            const rate = 0.6 * Math.pow(frequency / 45, 0.32)
            const phase = vibrationClock * Math.PI * 2 * rate + i * 2.39996323
            const pull = root.progress < 0 ? 0 : Math.tanh((root.progress - fraction) * 12) * 2.2
            const bend = pull + (Style.reduceMotion ? 0 : Math.sin(phase)) * Math.min(1.1, rise * 0.14)
            ctx.moveTo(x, baseline)
            ctx.bezierCurveTo(x + bend * 0.65, baseline - rise * 0.35,
                              x - bend, baseline - rise * 0.75, x, tip)
            ctx.stroke()
            const band=Math.min(levels.length-1,Math.round(fraction*(levels.length-1)))
            if(!Style.reduceMotion && rise>.25)for(let arrival=0;arrival<arrivalRoots.length;arrival++) {
                if(arrivalRoots[arrival]!==i)continue
                const energy=pulseState.arrivals[arrival].energy
                Impact.strike(impactState,band,energy)
                Radio.strike(radioState,band,energy,bandHeat)
                contacts.push({x:x,y:tip-.5,energy:energy})
            }
            for(let light=0;light<lightRoots.length;light++) {
                if(lightRoots[light]!==i || rise<=.25)continue
                const packet=pulseState.packets[light],travel=packet.travel
                const from=Math.max(0,travel-0.2),u=1-travel,v=1-from
                const px=x+3*u*u*travel*bend*0.65-3*u*travel*travel*bend
                const py=u*u*u*baseline+3*u*u*travel*(baseline-rise*0.35)+3*u*travel*travel*(baseline-rise*0.75)+travel*travel*travel*tip
                const sx=x+3*v*v*from*bend*0.65-3*v*from*from*bend
                const sy=v*v*v*baseline+3*v*v*from*(baseline-rise*0.35)+3*v*from*from*(baseline-rise*0.75)+from*from*from*tip
                ctx.strokeStyle=root.heatColor(0.15+0.65*packet.energy)
                ctx.lineWidth=1.8
                ctx.globalAlpha=root.floorFade(amplitude*reveal)*Math.min(1,travel/0.1)*(0.15+0.8*packet.energy)
                ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(px,py);ctx.stroke()
            }
        }
        ctx.globalAlpha = 1
        ctx.lineWidth = 1.25
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        const heatColors=bandHeat.map(h=>root.heatColor(h))
        const temperature=ctx.createLinearGradient(0,0,width,0)
        for(let i=0;i<heatColors.length;i++)temperature.addColorStop(i/(heatColors.length-1),heatColors[i])
        const activeZones=[]
        if(!Style.reduceMotion)for(let i=1;i<points.length;i++) {
            const glow=radioState.glow[i]||0
            if(glow>.02)activeZones.push({i:i,glow:glow})
        }
        activeZones.sort((a,b)=>b.glow-a.glow)
        for(let j=0;j<Math.min(3,activeZones.length);j++) {
            const zone=activeZones[j],i=zone.i
            ctx.strokeStyle=radioactiveInk;ctx.lineWidth=3.5;ctx.globalAlpha=zone.glow*(lightBackground?.17:.1)
            ctx.beginPath();Contour.trace(ctx,[points[i-1],points[i]]);ctx.stroke()
        }
        ctx.lineWidth=1.25
        ctx.strokeStyle=temperature
        for (let i = 1; i < points.length; ++i) {
            ctx.lineWidth=Impact.thickness(Math.max(worked[i-1]||0,worked[i]||0))
            const leftHeat = bandHeat[i-1] || 0, rightHeat = bandHeat[i] || 0
            ctx.globalAlpha = root.floorFade((levels[i-1] + levels[i]) * 0.5 * reveal)
                * (0.5 + 0.5 * Math.min(1, (leftHeat + rightHeat) / 1.3))
            ctx.beginPath()
            Contour.trace(ctx, [points[i-1], points[i]])
            ctx.stroke()
        }
        ctx.fillStyle=root.heatColor(.8)
        for(let i=0;i<contacts.length;i++) {ctx.globalAlpha=contacts[i].energy*.8;ctx.fillRect(contacts[i].x-.8,contacts[i].y-.8,1.6,1.6)}
        ctx.globalAlpha = 1
        const sandPoints=points.map((p,i)=>({x:p.x,y:p.y-(Impact.thickness(worked[i]||0)-0.65)/2,slope:p.slope}))
        if (handoff < 0.02 && !Style.reduceMotion) {
            grains = grains.length ? Sand.advance(grains, sandPoints, dt, width) : Sand.seed(sandPoints, width, root.grainLimit)
            if(contacts.length && now-lastBurst>200 && grains.length) {
                let hit=contacts[0]
                for(let i=1;i<contacts.length;i++)if(contacts[i].energy>hit.energy)hit=contacts[i]
                if(hit.energy>.2) {
                    Sand.explode(grains,hit.x,Sand.surface(sandPoints,hit.x).y,.55+hit.energy*.6,undefined,6+Math.round(hit.energy*4))
                    lastBurst=now
                }
            }
            if(activeZones.length && now>nextRadiate) {
                const zone=activeZones[Math.floor(Math.random()*Math.min(3,activeZones.length))]
                if(zone.glow>.1) {
                    const x=points[zone.i].x
                    for(let speck=0;speck<(zone.glow>.7?2:1);speck++)Sand.radiate(grains,x,sandPoints[zone.i].y)
                }
                nextRadiate=now+160+Math.random()*220
            }
            ctx.fillStyle = root.rgba(peakColor, 0.8)
            for (let i = 0; i < grains.length; ++i) {
                const g = grains[i]
                const energyIndex = Math.min(levels.length - 1, Math.round(g.x / width * (levels.length - 1)))
                g.color = g.spark>0?root.heatColor(Math.min(.7,.35+g.spark)):(g.radio>0?radioactiveInk:(heatColors[energyIndex] || root.heatColor(0)))
                ctx.fillStyle = g.color
                const visibility=g.radio>0?.85*Math.min(1,g.radio/.15):(g.spark>0?.9*Math.min(1,g.spark/.12):root.floorFade(levels[energyIndex])*(g.air?.8:.32))
                const edge=Trail.edge(g.x,g.y,width,height)
                ctx.globalAlpha=visibility*Math.min(1,g.age/.15)*edge
                if(g.radio>0) {
                    ctx.globalAlpha*=.1
                    ctx.fillRect(g.x-1.5,g.y-1.5,3,3)
                    ctx.globalAlpha=visibility*edge
                }
                const sparkSize=g.size+(g.spark>0?0.55*Math.min(1,g.spark/0.35):0)
                const path=Trail.segment(g,now)
                if(path.dx*path.dx+path.dy*path.dy>.01) {
                    ctx.strokeStyle=g.color;ctx.lineWidth=sparkSize;ctx.lineCap="round"
                    ctx.beginPath();ctx.moveTo(path.x0,path.y0);ctx.lineTo(path.x1,path.y1);ctx.stroke()
                } else ctx.fillRect(g.x-sparkSize/2,g.y-sparkSize/2,sparkSize,sparkSize)
            }
        } else if (Style.reduceMotion) grains = []
        ctx.globalAlpha = 1
        const edge = ctx.createLinearGradient(0, 0, width, 0)
        edge.addColorStop(0, "transparent")
        edge.addColorStop(0.04, "white")
        edge.addColorStop(0.96, "white")
        edge.addColorStop(1, "transparent")
        ctx.globalCompositeOperation = "destination-in"
        ctx.fillStyle = edge
        ctx.fillRect(0, 0, width, height)
        if (handoff > 0.001) {
            const wipe = ctx.createLinearGradient(0, 0, width, 0)
            const frontier = Math.min(0.999, Math.max(0.001, handoff))
            wipe.addColorStop(0, "transparent")
            wipe.addColorStop(Math.max(0, frontier - 0.035), "transparent")
            wipe.addColorStop(Math.min(1, frontier + 0.035), "white")
            wipe.addColorStop(1, "white")
            ctx.fillStyle = wipe
            ctx.fillRect(0, 0, width, height)
        }
        ctx.globalCompositeOperation = "source-over"
    }
}
