import QtQuick
import "Palette.js" as Palette

Item {
    id: root

    property var levels: []
    property var peaks: []
    property color background: "#121212"
    readonly property var backdrop: Palette.rgb(background)
    readonly property color fillInk: adapted([251 / 255, 190 / 255, 7 / 255])
    readonly property color capInk: adapted([182 / 255, 10 / 255, 10 / 255])

    function adapted(rgb) {
        const color = Palette.isLight(backdrop)
            ? Palette.ensureContrast(rgb, backdrop, 4.5)
            : rgb
        return Qt.rgba(color[0], color[1], color[2], 1)
    }

    Row {
        anchors.fill: parent
        spacing: 1

        Repeater {
            model: root.levels.length

            delegate: Item {
                id: band
                required property int index
                readonly property real level: root.levels[index] ?? 0
                readonly property real peak: root.peaks[index] ?? 0
                readonly property real meterHeight: height - 2
                readonly property real fillHeight: Math.round(level * meterHeight)
                readonly property real capHeight: Math.max(0, fillHeight - Math.round(meterHeight * 0.72))
                width: (root.width - (root.levels.length - 1) * parent.spacing) / root.levels.length
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: band.fillHeight - band.capHeight
                    color: root.fillInk
                }

                Rectangle {
                    y: parent.height - band.fillHeight
                    width: parent.width
                    height: band.capHeight
                    color: root.capInk
                }

                Rectangle {
                    y: parent.height - Math.round(band.peak * band.meterHeight) - height
                    width: parent.width
                    height: 1
                    visible: band.peak > band.level + 0.05
                    color: root.fillInk
                }
            }
        }
    }
}
