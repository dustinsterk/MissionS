import QtQuick 2.3

// One or more concentric arcs, painted once (repainted only when a property
// below changes). Used for the static mode layers, which crossfade by opacity.
Canvas {
    id: ring
    property real radius: 100
    width: radius*2
    height: radius*2
    property real arcRadius: radius-10
    property real startAng: 225       // degrees clockwise from 12 o'clock
    property real sweep: 270
    property real fromF: 0
    property real toF: 1
    property real lineWidth: 2
    property int  count: 1
    property real spacing: 5
    property color strokeColor: "#ffffff"
    property string cap: "butt"

    function rad(a){ return (a-90)*Math.PI/180 }
    onPaint: {
        var c=getContext("2d")
        c.reset()
        c.strokeStyle=strokeColor
        c.lineWidth=lineWidth
        c.lineCap=cap
        for(var i=0;i<count;i++){
            c.beginPath()
            c.arc(radius, radius, arcRadius-i*spacing, rad(startAng+sweep*fromF), rad(startAng+sweep*toF), false)
            c.stroke()
        }
    }
    onArcRadiusChanged: requestPaint()
    onStartAngChanged: requestPaint()
    onSweepChanged: requestPaint()
    onFromFChanged: requestPaint()
    onToFChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onRadiusChanged: requestPaint()
}
