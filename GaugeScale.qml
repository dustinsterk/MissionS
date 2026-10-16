import QtQuick 2.3

// Tick marks and numbers around a round dial. The item is a 2*radius square
// with the dial centre in the middle. Angles are degrees clockwise from
// 12 o'clock; startAng/sweep can be animated (ticks and numbers move, the
// numbers stay upright).
Item {
    id: sc
    property real radius: 100
    width: radius*2
    height: radius*2

    property real startAng: 225
    property real sweep: 270
    property int  steps: 40          // tick intervals
    property int  majorEvery: 5
    property real tickOuter: radius-10
    property real minorLen: 8
    property real majorLen: 16
    property real minorW: 2
    property real majorW: 3
    property color minorColor: "#ffffff"
    property color majorColor: "#ffffff"
    property real tickOpacity: 1
    property real hotFrom: 2         // fraction of the scale from which ticks are "hot" (>1 = none)
    property color hotColor: "#ff3020"
    property real hotOpacity: 1
    property real hotW: 3

    property var  labels: []
    property real labelRadius: radius-40
    property real labelSize: 20
    property color labelColor: "#ffffff"
    property real labelOpacity: 1
    property string fontFamily: ""
    property bool labelBold: false

    function angAt(f){ return startAng+sweep*f }

    Repeater {
        model: sc.steps+1
        Rectangle {
            property real f: index/sc.steps
            property bool major: index%sc.majorEvery===0
            property bool hot: f>=sc.hotFrom-0.0001
            width: hot ? sc.hotW : (major ? sc.majorW : sc.minorW)
            height: major ? sc.majorLen : sc.minorLen
            x: sc.radius-width/2
            y: sc.radius-sc.tickOuter
            antialiasing: true
            color: hot ? sc.hotColor : (major ? sc.majorColor : sc.minorColor)
            opacity: hot ? sc.hotOpacity : sc.tickOpacity
            visible: opacity>0.01
            transform: Rotation { origin.x: width/2; origin.y: sc.tickOuter; angle: sc.angAt(f) }
        }
    }

    Repeater {
        model: sc.labels.length
        Text {
            property real a: sc.angAt(sc.labels.length>1 ? index/(sc.labels.length-1) : 0)*Math.PI/180
            text: sc.labels[index]
            color: sc.labelColor
            opacity: sc.labelOpacity
            visible: opacity>0.01
            font.family: sc.fontFamily
            font.pixelSize: sc.labelSize
            font.bold: sc.labelBold
            x: sc.radius+sc.labelRadius*Math.sin(a)-width/2
            y: sc.radius-sc.labelRadius*Math.cos(a)-height/2
        }
    }
}
