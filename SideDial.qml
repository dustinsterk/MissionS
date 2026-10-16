import QtQuick 2.3

// A round side dial (speed, oil pressure, fuel, coolant). Follows the
// cluster's "outer" mode, which changes a moment after the centre dial:
//   0 Normal: full scale, marker, number
//   1 Sport : red ring, scale, marker
//   2 Track : scale fades away, heavy ring, marker
Item {
    id: d
    property real radius: 100
    width: radius*2
    height: radius*2

    property int  mode: 0
    property color accent: "#a493ff"
    property real value: 0
    property real minV: 0
    property real maxV: 100
    property var  labels: []
    property int  steps: 20
    property int  majorEvery: 5
    property real startAng: 225
    property real sweep: 270
    property real labelSize: 15
    property real hotFrom: 2

    property string valueText: ""
    property string unitText: ""
    property real valueSize: 44
    property real valueY: radius-valueSize*0.62
    property real valueX: 0             // offset of the number from the centre
    property bool warn: false
    property bool numberInNormalOnly: false
    property string numFont: ""
    property string labelFont: ""

    default property alias extra: extras.data

    function frac(){ return Math.max(0, Math.min(1, (value-minV)/(maxV-minV))) }

    DialFace { radius: d.radius; tint: d.accent; tintOpacity: 0.07 }

    // Sport: thin ring at the edge
    ArcRing {
        radius: d.radius; arcRadius: d.radius-11; lineWidth: 3
        startAng: d.startAng; sweep: d.sweep; strokeColor: "#ff2d2d"
        opacity: d.mode===1 ? 0.95 : 0
        visible: opacity>0.01
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
    // Track: heavy ring
    ArcRing {
        radius: d.radius; arcRadius: d.radius-14; lineWidth: 7
        startAng: d.startAng; sweep: d.sweep; strokeColor: "#ff4d1c"; cap: "round"
        opacity: d.mode===2 ? 1 : 0
        visible: opacity>0.01
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    GaugeScale {
        radius: d.radius
        startAng: d.startAng; sweep: d.sweep
        steps: d.steps; majorEvery: d.majorEvery
        tickOuter: d.radius-9
        minorLen: 6; majorLen: 11; minorW: 2; majorW: 3
        minorColor: d.mode===1 ? "#ff6a5e" : "#8f96a0"
        majorColor: "#ffffff"
        hotFrom: d.hotFrom; hotColor: "#ff2d2d"
        tickOpacity: d.mode===2 ? 0 : 1
        hotOpacity: d.mode===2 ? 0 : 1
        labels: d.labels
        labelRadius: d.radius-30
        labelSize: d.labelSize
        labelColor: "#e8ecf0"
        labelOpacity: d.mode===2 ? 0 : 1
        fontFamily: d.labelFont
        Behavior on tickOpacity { NumberAnimation { duration: 400 } }
        Behavior on labelOpacity { NumberAnimation { duration: 400 } }
    }

    // value marker on the edge
    Item {
        anchors.fill: parent
        rotation: d.startAng+d.sweep*mfrac
        property real mfrac: d.frac()
        Behavior on mfrac { SpringAnimation { spring: 2.5; damping: 0.35 } }
        Rectangle {
            x: d.radius-width/2; y: 7
            width: d.mode===2 ? 6 : 4
            height: d.mode===2 ? 22 : 18
            radius: 2
            color: d.warn ? "#ff2d2d" : (d.mode===0 ? "#ff3b2b" : "#ffffff")
            antialiasing: true
        }
    }

    Text {
        id: num
        text: d.valueText
        x: d.radius-width/2+d.valueX
        y: d.valueY
        color: d.warn ? (blink.on ? "#ff2d2d" : "#ffffff") : "#ffffff"
        font.family: d.numFont
        font.pixelSize: d.valueSize
        font.bold: true
        opacity: (d.numberInNormalOnly && d.mode!==0) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
    Text {
        text: d.unitText
        anchors.horizontalCenter: num.horizontalCenter
        y: num.y+num.height-4
        color: "#aab1ba"
        font.family: d.labelFont
        font.pixelSize: Math.max(11, d.valueSize*0.26)
        opacity: num.opacity
    }

    Item { id: extras; anchors.fill: parent }

    Timer { id: blink; property bool on: true; interval: 400; repeat: true; running: d.warn; onTriggered: on=!on; onRunningChanged: on=true }
}
