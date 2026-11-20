import QtQuick
import "DotFont.js" as Font
import "Trail.js" as Trail
import "TitleMotion.js" as TitleMotion

Canvas {
    id: root
    property string text: ""
    property string fontFamily: "monospace"
    property color ink: "#e8ac70"
    property bool active: false
    property double clock: 0
    property double stageClock: 0
    property double lastStep: 0
    property double lastPaint: 0
    property real amount: 0
    property bool gathering: false
    property var sandOrigins: []
    property real particleOffsetY: 4
    property var actors: []
    property var goals: []
    property bool needTargets: true
    property bool clearForFall: false
    property real textAlpha: 0
    onGatheringChanged: {
        stageClock=0;lastStep=Date.now();needTargets=true
        if(gathering) {clock=0;actors=sandOrigins}
        else {
            actors.forEach(g=>{g.vx+=(Math.random()-0.5)*4;g.vy=Math.max(0,g.vy)+4+Math.random()*5})
            clearForFall=true
        }
        requestPaint()
    }
    onAmountChanged: {if(amount<0.005&&!gathering)actors=[];requestPaint()}
    readonly property string message: Font.prepare(text)
    readonly property bool nativeText: !Font.supported(text)
    readonly property real textWidth: nativeText?fallback.implicitWidth:Math.max(0,message.length*12-2)
    readonly property real distance: textWidth+36
    readonly property real offset: textWidth>width && clock>0.8?((clock-0.8)*26)%distance:0
    readonly property int readDuration: Math.max(3000,Math.round(800+Math.max(0,textWidth-width)/26*1000+1500))
    onActiveChanged: {if(active)clock=0;requestPaint()}
    onTextChanged: {clock=0;needTargets=true;stageClock=0;requestPaint()}
    onOffsetChanged: {if(gathering&&actors.length)needTargets=true;requestPaint()}
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Timer {
        interval:33
        running:(root.active&&root.textWidth>root.width)||(root.amount>0.001&&(root.stageClock<0.7||!root.gathering))
        repeat:true
        onTriggered:{
            const now=Date.now(),dt=root.lastStep?(now-root.lastStep)/1000:0.033
            root.lastStep=now
            if(root.active)root.clock+=dt
            root.stageClock+=dt
            root.requestPaint()
        }
    }
    Text {
        id:fallback
        opacity:root.textAlpha
        visible:root.nativeText
        textFormat:Text.PlainText;text:root.text;color:root.ink
        font.family:root.fontFamily;font.pixelSize:13
        x:root.textWidth>root.width?-root.offset:(root.width-width)/2
        anchors.verticalCenter:parent.verticalCenter
    }
    Text {
        opacity:root.textAlpha
        visible:root.nativeText && root.textWidth>root.width
        textFormat:Text.PlainText;text:root.text;color:root.ink
        font.family:root.fontFamily;font.pixelSize:13
        x:root.distance-root.offset
        anchors.verticalCenter:parent.verticalCenter
    }
    onPaint: {
        const ctx=getContext('2d'),now=Date.now()
        const dtPaint=lastPaint?(now-lastPaint)/1000:0.033
        lastPaint=now
        if(clearForFall) {ctx.clearRect(0,0,width,height);clearForFall=false}
        else if(amount>0.001 && (stageClock<0.7||!gathering) && dtPaint<0.2) {
            ctx.globalCompositeOperation='destination-out'
            ctx.fillStyle='black';ctx.globalAlpha=1-Math.exp(-dtPaint/0.07)
            ctx.fillRect(0,0,width,height)
        } else ctx.clearRect(0,0,width,height)
        ctx.globalCompositeOperation='source-over';ctx.globalAlpha=1
        const t=Math.min(1,Math.max(0,(stageClock-0.2)/0.4))
        textAlpha=amount===0&&active?1:(gathering?t*t*(3-2*t):0)
        if(nativeText || !message.length)return
        ctx.fillStyle=ink;ctx.globalAlpha=0.95*textAlpha
        const visibleDots=needTargets?[]:null
        const origin=textWidth>width?-offset:(width-textWidth)/2
        const top=(height-12)/2
        for(let copy=0;copy<(textWidth>width?2:1);copy++) {
            const left=origin+copy*distance
            const first=Math.max(0,Math.floor(-left/12)-1)
            const last=Math.min(message.length-1,Math.ceil((width-left)/12))
            for(let i=first;i<=last;i++) {
                const glyph=Font.glyphs[message[i]]||Font.glyphs['?']
                for(let row=0;row<7;row++) {
                    const bits=parseInt(glyph.slice(row*2,row*2+2),16)
                    for(let col=0;col<5;col++)if(bits&(1<<(4-col))) {
                        const x=left+i*12+col*2,y=top+row*2
                        ctx.fillRect(x-0.65,y-0.65,1.3,1.3)
                        if(visibleDots&&x>=1&&x<width-1)visibleDots.push({x:x,y:y-particleOffsetY})
                    }
                }
            }
        }
        if(visibleDots) {
            visibleDots.sort((a,b)=>a.x-b.x||a.y-b.y)
            const targets=[]
            if(visibleDots.length)for(let i=0;i<actors.length;i++)targets.push(visibleDots[Math.floor(i*visibleDots.length/actors.length)])
            goals=targets;needTargets=false
        }
        if(actors.length) {
            const dt=Math.min(0.033,Math.max(0.001,dtPaint))
            for(let i=0;i<actors.length;i++) {
                const g=actors[i],goal=goals[i]
                if(gathering&&goal) TitleMotion.follow(g,goal,dt)
                else {
                    g.vy+=180*dt;g.vx*=Math.exp(-0.7*dt)
                    g.x+=g.vx*dt;g.y+=g.vy*dt
                }
                ctx.fillStyle=g.color||ink
                const path=Trail.segment(g,now),y=g.y+particleOffsetY
                ctx.globalAlpha=Math.min(1,amount*4)*(gathering?1-textAlpha*0.7:1)*Trail.edge(g.x,y,width,height)
                if(stageClock<0.7||!gathering) {
                    ctx.strokeStyle=g.color||ink;ctx.lineWidth=1;ctx.lineCap="round"
                    ctx.beginPath();ctx.moveTo(path.x0,path.y0+particleOffsetY);ctx.lineTo(path.x1,path.y1+particleOffsetY);ctx.stroke()
                }
            }
        }
        ctx.globalAlpha=1
    }
}
