import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Status.js" as Status

Item {
    id: root

    property var consumers: []
    readonly property bool watching: consumers.some(consumer => consumer.watching)
    readonly property bool capturing: consumers.some(consumer => consumer.capturing)
    readonly property int sinkId: Pipewire.defaultAudioSink?.id ?? -1
    property var statusHealth: ({ value: {}, failures: 0, lastGood: 0 })
    readonly property var mediaStatus: statusHealth.value
    property var targets: Array(24).fill(0)
    property double frameTime: 0
    property bool analyzerFailed: false

    function setConsumer(widget, watching, capturing) {
        const next = consumers.filter(consumer => consumer.widget !== widget)
        if (watching) next.push({ widget, watching, capturing })
        consumers = next
    }

    function requestPlaybackToggle() {
        if (!mediaAction.running) mediaAction.running = true
    }

    function acceptFrame(line) {
        if (line.length > 256) return
        const values = line.split(";")
        if (values.length !== 24) return
        const next = values.map(Number)
        if (next.some(value => !Number.isFinite(value) || value < 0 || value > 1)) return
        targets = next
        frameTime = Date.now()
        analyzerFailed = false
    }

    onCapturingChanged: {
        analyzer.running = capturing
        if (!capturing) frameTime = 0
    }

    onSinkIdChanged: {
        if (!capturing) return
        analyzer.running = false
        frameTime = 0
        retry.restart()
    }

    Process {
        id: statusProbe
        command: ["timeout", "0.8", "omarchy-shell", "media", "status"]
        stdout: StdioCollector { id: statusOutput }
        onExited: (code, exitStatus) => {
            const now = Date.now()
            root.statusHealth = code === 0 && exitStatus === 0
                ? Status.accept(root.statusHealth, statusOutput.text, now)
                : Status.failed(root.statusHealth, now)
        }
    }

    Timer {
        interval: 1000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statusProbe.running) statusProbe.running = true
    }

    Process {
        id: mediaAction
        command: ["timeout", "0.8", "omarchy-shell", "media", "playPause"]
    }

    Process {
        id: analyzer
        // Give Quickshell the full path without shell interpolation.
        command: [decodeURIComponent(String(Qt.resolvedUrl("build/vizamp-analyzer")).replace(/^file:\/\//, ""))]
        stdout: SplitParser { onRead: line => root.acceptFrame(line) }
        onRunningChanged: if (!running && root.capturing) root.analyzerFailed = true
    }

    Timer {
        id: retry
        interval: 3000
        running: root.capturing
        repeat: true
        onTriggered: if (!analyzer.running) analyzer.running = true
    }
}
