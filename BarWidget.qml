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
    readonly property bool stackedMode: setting("spectrumMode", "ridge") === "stacked"

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

    function toggleSpectrumMode() {
        if (!bar?.shell) return
        const nextSettings = Object.assign({}, settings, { spectrumMode: stackedMode ? "ridge" : "stacked" })
        bar.shell.updateEntryInline(moduleName, nextSettings)
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
        let match = null
        for (const player of list) {
            if (player.identity !== mediaStatus.identity || player.trackTitle !== mediaStatus.title
                || (mediaStatus.desktopEntry && player.desktopEntry !== mediaStatus.desktopEntry)
                || (mediaStatus.artist && player.trackArtist !== mediaStatus.artist)) continue
            if (match) return null
            match = player
        }
        return match
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
    Connections {
        target: root.timingPlayer
        function onUniqueIdChanged() { root.syncProgress() }
    }
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
        Item {
            id: meter
            anchors.centerIn: parent
            width: root.plotWidth
            height: Math.max(9, Math.min(20, root.barSize - 6))
            opacity: root.presence * Math.min(1, (1 - root.titleMix) * 5)
            visible: root.watching && opacity > 0.001

            transform: Rotation {
                origin.x: meter.width / 2
                origin.y: meter.height / 2
                axis.x: 1; axis.y: 0; axis.z: 0
                angle: root.stackedMode ? 0 : root.rollAngle * (1 - root.titleMix)
            }

            Loader {
                id: spectrumView
                anchors.fill: parent
                active: !root.stackedMode
                sourceComponent: SpectrumPlot {
                    trackKey: root.progressTrackKey
                    progress: root.visualProgress
                    handoff: root.titleMix
                    levels: root.motion.levels
                    peakColor: root.titleInk
                    background: root.background
                    ink: root.accentInk
                }
            }

            Loader {
                anchors.fill: parent
                active: root.stackedMode
                sourceComponent: StackedBars {
                    levels: root.motion.levels
                    peaks: root.motion.peaks
                    background: root.background
                }
            }
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
                item.particleOffsetY=Qt.binding(()=>(root.barSize-meter.height)/2)
                item.sandOrigins=Qt.binding(()=>spectrumView.item?spectrumView.item.grains:[])
                item.amount=Qt.binding(()=>root.watching?root.titleMix:0)
                item.gathering=Qt.binding(()=>root.watching&&root.showTitle)
                item.active=Qt.binding(()=>root.watching&&root.showTitle&&root.titleMix>0.98)
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: root.plotWidth
            height: 1
            visible: root.watching && root.playing && root.titleMix > 0.9 && root.trackProgress >= 0
            Accessible.role: Accessible.ProgressBar
            Accessible.name: strings.t("trackProgress")
                .arg(Progress.clock(root.trackPosition))
                .arg(Progress.clock(root.trackDuration))

            Rectangle {
                anchors.fill: parent
                color: root.accentInk
                opacity: 0.25
            }
            Rectangle {
                width: parent.width * Math.max(0, root.trackProgress)
                height: parent.height
                color: root.accentInk
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
        id: input
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        property int wheelDelta: 0
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.toggleSpectrumMode()
            else if (root.service) root.service.requestPlaybackToggle()
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y
            if (!delta || !root.service
                || !(delta < 0 ? root.mediaStatus.canGoNext : root.mediaStatus.canGoPrevious)) {
                wheel.accepted = false
                return
            }
            if (wheelDelta * delta < 0) wheelDelta = 0
            wheelDelta += delta
            wheelReset.restart()
            if (Math.abs(wheelDelta) >= 120) {
                root.service.requestTrackStep(wheelDelta < 0 ? 1 : -1)
                wheelDelta = 0
            }
        }
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
            wheelDelta = 0
            if (root.bar) root.bar.hideTooltip(root)
        }
    }
    Timer {
        id: wheelReset
        interval: 200
        onTriggered: input.wheelDelta = 0
    }
}
