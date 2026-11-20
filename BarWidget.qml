pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Motion.js" as Motion
import "Palette.js" as Palette
import "Progress.js" as Progress
import "Status.js" as Status

BarWidget {
    id: root
    moduleName: "sliday.vizamp"

    readonly property var service: bar?.shell?.serviceFor(moduleName) ?? null
    property var connectedService: null
    readonly property bool watching: visible && (Window.window?.visible ?? true)
        && !bar?.shell?.bar?.barHidden
    readonly property var mediaStatus: service?.mediaStatus ?? ({})
    readonly property bool playing: mediaStatus.playing === true
    readonly property bool capturing: watching && playing && titleMix < 0.999
    readonly property string trackLabel: Status.label(mediaStatus)

    readonly property var display: Window.window?.screen
    readonly property real screenSpan: display ? (vertical ? display.height : display.width) : 1280
    readonly property real mediaWidth: Math.max(84, Math.min(
        vertical ? 180 : 320, screenSpan * (vertical ? 0.24 : 0.26)))
    readonly property real idleSize: Math.min(24, barSize)
    readonly property real contentLength: idleSize + (mediaWidth - idleSize) * presence
    readonly property real plotWidth: mediaWidth - 26
    readonly property color barBackground: bar?.background ?? Commons.Color.bar.background
    readonly property color background: Palette.background(barBackground, Commons.Color.background)
    readonly property color titleInk: Palette.readableColor(bar?.barForeground ?? Commons.Color.foreground, background)
    readonly property color accentInk: Palette.readableColor(Commons.Color.accent, background)
    implicitWidth: vertical ? barSize : contentLength
    implicitHeight: vertical ? contentLength : barSize
    property real presence: playing ? 1 : 0
    Behavior on presence {
        NumberAnimation { duration: Style.duration(root.playing ? 180 : 120); easing.type: Easing.OutCubic }
    }

    function syncConsumer() {
        if (connectedService !== service) {
            if (connectedService) connectedService.setConsumer(root, false, false)
            connectedService = service
        }
        if (connectedService) connectedService.setConsumer(root, watching, capturing)
    }

    onServiceChanged: Qt.callLater(syncConsumer)
    onWatchingChanged: Qt.callLater(syncConsumer)
    onCapturingChanged: Qt.callLater(syncConsumer)
    Component.onCompleted: Qt.callLater(syncConsumer)
    Component.onDestruction: if (connectedService) connectedService.setConsumer(root, false, false)

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    property real trackProgress: -1
    property real visualProgress: -1
    property real trackPosition: 0
    property real trackDuration: 0
    property string progressTrackKey: ""
    readonly property var timingPlayer: {
        const list = Mpris.players ? Mpris.players.values : []
        if (!mediaStatus.identity || !mediaStatus.title) return null
        for (let i=0; i<list.length; ++i) {
            const p=list[i]
            if (p.identity===mediaStatus.identity && p.trackTitle===mediaStatus.title
                && (!mediaStatus.artist || p.trackArtist===mediaStatus.artist)) return p
        }
        return null
    }
    function syncProgress() {
        const p=timingPlayer
        if (!p || !p.positionSupported || !p.lengthSupported) {
            progressTrackKey=""; trackProgress=-1; visualProgress=-1; trackPosition=0; trackDuration=0; return
        }
        const key=p.dbusName+":"+p.uniqueId
        trackPosition=Math.max(0,p.position)
        trackDuration=p.length
        const ratio=Progress.ratio(trackPosition,trackDuration)
        if(key!==progressTrackKey || visualProgress<0)visualProgress=ratio
        progressTrackKey=key
        trackProgress=ratio
    }
    onTimingPlayerChanged: syncProgress()
    Timer {
        interval: 250; running: root.watching && root.playing; repeat: true; triggeredOnStart: true
        onTriggered: root.syncProgress()
    }
    readonly property int titleDwellMs: titleView.item ? titleView.item.readDuration : 3000
    property bool cycleTitle: false
    property bool hovered: false
    readonly property bool showTitle: playing && trackLabel.length > 0 && (cycleTitle || hovered)
    property real titleMix: showTitle ? 1 : 0
    clip: true
    Behavior on titleMix {
        NumberAnimation { duration: Style.duration(root.showTitle ? 260 : 220); easing.type: Easing.OutCubic }
    }

    Timer {
        interval: root.cycleTitle ? root.titleDwellMs : root.titleDwellMs * 9
        running: root.watching && root.playing && root.trackLabel.length > 0
        repeat: true
        onTriggered: root.cycleTitle = !root.cycleTitle
    }
    property var motion: Motion.empty(24)
    readonly property var silence: Array(24).fill(0)
    property double tickTime: 0
    property double rollClock: 0
    readonly property real rollAngle: playing && !Style.reduceMotion ? 24 * Math.sin(rollClock * Math.PI * 2 / 9) : 0

    onPlayingChanged: {
        if (!playing) {
            cycleTitle = false
            hovered = false
            motion = Motion.empty(24)
            tickTime = 0
        }
    }

    Timer {
        interval: Style.reduceMotion ? 66 : 33
        running: root.capturing
        repeat: true
        onTriggered: {
            const now = Date.now()
            const dt = root.tickTime ? (now - root.tickTime) / 1000 : 0.016
            root.tickTime = now
            root.rollClock += Math.min(0.08, Math.max(0, dt))
            root.visualProgress=root.trackProgress<0?-1:root.visualProgress+(root.trackProgress-root.visualProgress)*(1-Math.exp(-Math.max(0,dt)/0.12))
            const target = root.service && now - root.service.frameTime < 250 ? root.service.targets : root.silence
            root.motion = Motion.advance(root.motion, target, dt)
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.mediaWidth
        height: root.barSize
        rotation: root.vertical ? (root.bar?.position === "left" ? -90 : 90) : 0
        Loader {
            id: spectrumView
            transform: Rotation {
                origin.x: spectrumView.width / 2
                origin.y: spectrumView.height / 2
                axis.x: 1; axis.y: 0; axis.z: 0
                angle: root.rollAngle * (1 - root.titleMix)
            }
            source: Qt.resolvedUrl("SpectrumPlot.qml")
            onLoaded: {
                item.trackKey = Qt.binding(() => root.progressTrackKey)
                item.progress = Qt.binding(() => root.visualProgress)
                item.handoff = Qt.binding(() => root.titleMix)
                item.levels = Qt.binding(() => root.motion.levels)
                item.peaks = Qt.binding(() => root.motion.peaks)
                item.peakColor = Qt.binding(() => root.titleInk)
                item.background = Qt.binding(() => root.background)
                item.ink = Qt.binding(() => root.accentInk)
            }
            anchors.centerIn: parent
            width: root.plotWidth
            height: Math.max(9, Math.min(20, root.barSize - 6))
            opacity: root.presence * Math.min(1, (1 - root.titleMix) * 5)
            visible: root.watching && opacity > 0.001
        }

        Loader {
            id: titleView
            x:13
            width:root.plotWidth
            height:parent.height
            clip:true
            opacity:root.presence*Math.min(1,root.titleMix*3)
            visible:root.watching&&opacity>0.001
            source:Qt.resolvedUrl("MarqueeTitle.qml")
            onLoaded: {
                item.text=Qt.binding(()=>root.trackLabel)
                item.fontFamily=Qt.binding(()=>root.bar?root.bar.fontFamily:"monospace")
                item.ink=Qt.binding(()=>root.titleInk)
                item.particleOffsetY=Qt.binding(()=>(root.barSize-spectrumView.height)/2)
                item.sandOrigins=Qt.binding(()=>spectrumView.item?spectrumView.item.grains:[])
                item.amount=Qt.binding(()=>root.watching?root.titleMix:0)
                item.gathering=Qt.binding(()=>root.watching&&root.showTitle)
                item.active=Qt.binding(()=>root.watching&&root.showTitle&&root.titleMix>0.98)
            }
        }

    }

    Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        readonly property bool audioUnavailable: root.capturing && !!root.service?.analyzerFailed
        text: audioUnavailable ? "!" : "▶"
        Accessible.name: audioUnavailable ? strings.t("audioUnavailable") : ""
        font.pixelSize: Style.font.body
        color: root.accentInk
        opacity: audioUnavailable ? 1 : 1 - root.presence
        visible: opacity > 0.001
    }

    Timer {
        id: hoverIntent
        interval: 120
        onTriggered: root.hovered = true
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.service) root.service.requestPlaybackToggle()
        onEntered: {
            if (root.service?.analyzerFailed && root.capturing && root.bar) {
                root.bar.showTooltip(root, strings.t("audioUnavailable"))
            } else if (root.playing) {
                hoverIntent.restart()
            }
        }
        onExited: {
            hoverIntent.stop()
            root.hovered = false
            if (root.bar) root.bar.hideTooltip(root)
        }
    }
}
