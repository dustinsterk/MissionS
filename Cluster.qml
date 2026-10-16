import QtQuick 2.3
import QtGraphicalEffects 1.0

// MissionS cluster, 800x480. Three modes:
//   0 Normal - lavender, radial tick ring, orange redline block
//   1 Sport  - red, concentric rings
//   2 Track  - orange, scale rotates so 0 sits at the lower right, rpm shown
//              as a filled band, redline striped at the top
// Mode change: the label switches at once, the centre dial crossfades to the
// new colours, the side dials follow ~0.3 s later. Into / out of Track the
// rev scale turns (0.7 s) and the band fades in after it.
Item {
    id: cl
    width: 800
    height: 480

    // ---- data (display units) ----
    property int  mode: 0
    property real rpm: 0
    property real revmax: 8000
    property real redline: 7000
    property real shiftrpm: 0
    property string gear: "N"
    property real speed: 0
    property real speedmax: 300
    property string speedunit: "KM/H"
    property real oilp: 0
    property real oilmax: 8
    property string oilunit: "BAR"
    property int  oildec: 1
    property real coolant: 0
    property real coolmin: 40
    property real coolmax: 140
    property real fuel: 0
    property bool coolWarn: false
    property bool oilWarn: false
    property bool fuelWarn: false
    property real odometer: 0
    property real trip: 0

    FontLoader { id: numfont; source: "fonts/CaviarDreams_Bold.ttf" }
    FontLoader { id: labfont; source: "fonts/basic.ttf" }

    // ---- mode colours ----
    property var accentPal: ["#a493ff", "#ff2d2d", "#ff541c"]
    property var tickPal: ["#c9bfff", "#ff2d2d", "#ff541c"]
    property var hotPal:  ["#ff7a26", "#ff2d2d", "#ff2d2d"]
    property var names:   ["NORMAL", "SPORT", "TRACK"]

    // centre follows the mode at once, the side dials a moment later
    property int oMode: 0
    Component.onCompleted: { oMode=mode; bandOn=(mode===2) }
    onModeChanged: { outerDelay.restart(); syncBand() }
    Timer { id: outerDelay; interval: 300; onTriggered: cl.oMode=cl.mode }

    property color cAccent: accentPal[mode]
    Behavior on cAccent { ColorAnimation { duration: 450 } }
    property color cTick: tickPal[mode]
    Behavior on cTick { ColorAnimation { duration: 450 } }
    property color cHot: hotPal[mode]
    Behavior on cHot { ColorAnimation { duration: 450 } }
    property color oAccent: accentPal[oMode]
    Behavior on oAccent { ColorAnimation { duration: 450 } }

    // rev scale geometry (degrees clockwise from 12 o'clock)
    property real startAng: mode===2 ? 150 : 225
    property real sweep: mode===2 ? 240 : 270
    Behavior on startAng { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on sweep { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }

    // track band appears once the scale has turned, goes at once on the way out
    property bool bandOn: false
    Timer { id: bandDelay; interval: 550; onTriggered: cl.bandOn=(cl.mode===2) }
    function syncBand(){ if(mode===2) bandDelay.restart(); else { bandDelay.stop(); bandOn=false } }

    property real rpmS: rpm
    Behavior on rpmS { SpringAnimation { spring: 3.0; damping: 0.3 } }
    property real rpmF: Math.max(0, Math.min(1, rpmS/revmax))

    property bool shiftOn: shiftrpm>0 && rpm>=shiftrpm
    property bool blinkOn: true
    Timer { interval: 90; repeat: true; running: cl.shiftOn; onTriggered: cl.blinkOn=!cl.blinkOn; onRunningChanged: cl.blinkOn=true }

    // ---- background ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1d22" }
            GradientStop { position: 0.55; color: "#0b0d10" }
            GradientStop { position: 1.0; color: "#030405" }
        }
    }

    // ---- far dials ----
    SideDial {
        id: fuelDial
        x: 68-radius; y: 226-radius; z: 1
        radius: 64
        mode: cl.oMode; accent: cl.oAccent
        value: cl.fuel; minV: 0; maxV: 100
        startAng: 200; sweep: 140
        labels: []; steps: 8; majorEvery: 4; labelSize: 13
        hotFrom: 2
        valueText: cl.fuel.toFixed(0)+"%"; unitText: ""
        valueSize: 28; valueX: -10; valueY: radius-12
        warn: cl.fuelWarn
        numberInNormalOnly: true
        numFont: numfont.name; labelFont: labfont.name
        // pump icon
        Canvas {
            x: 44; y: 16; width: 22; height: 26
            property color c: cl.fuelWarn ? "#ff2d2d" : "#d0d6dd"
            onCChanged: requestPaint()
            onPaint: { var g=getContext("2d"); g.reset(); g.fillStyle=c; g.strokeStyle=c; g.lineWidth=2
                g.fillRect(2,4,11,20); g.clearRect(4,7,7,6)
                g.beginPath(); g.moveTo(13,9); g.lineTo(18,12); g.lineTo(18,21); g.lineTo(20,21); g.lineTo(20,8); g.stroke() }
        }
    }
    SideDial {
        id: coolDial
        x: 732-radius; y: 226-radius; z: 1
        radius: 64
        mode: cl.oMode; accent: cl.oAccent
        value: cl.coolant; minV: cl.coolmin; maxV: cl.coolmax
        startAng: 160; sweep: -140      // mirrored: cold at the bottom, hot at the top
        labels: []
        steps: 8; majorEvery: 4; labelSize: 13
        hotFrom: 2
        valueText: cl.coolant.toFixed(0)+"°"; unitText: ""
        valueSize: 28; valueX: 10; valueY: radius-12
        warn: cl.coolWarn
        numFont: numfont.name; labelFont: labfont.name
        // thermometer icon
        Canvas {
            x: 62; y: 16; width: 22; height: 26
            property color c: cl.coolWarn ? "#ff2d2d" : "#d0d6dd"
            onCChanged: requestPaint()
            onPaint: { var g=getContext("2d"); g.reset(); g.fillStyle=c; g.strokeStyle=c; g.lineWidth=2
                g.fillRect(9,2,4,16); g.beginPath(); g.arc(11,20,5,0,Math.PI*2); g.fill()
                g.fillRect(14,5,5,2); g.fillRect(14,10,5,2) }
        }
    }

    // ---- side dials ----
    SideDial {
        id: speedDial
        x: 196-radius; y: 262-radius; z: 2
        radius: 108
        mode: cl.oMode; accent: cl.oAccent
        value: cl.speed; minV: 0; maxV: cl.speedmax
        startAng: 190; sweep: 180         // only the part not hidden by the rev counter
        labels: [0,1,2,3,4,5,6].map(function(i){ return String(Math.round(cl.speedmax*i/6)) })
        steps: 24; majorEvery: 4; labelSize: 15
        valueText: Math.round(Math.max(0, cl.speed)).toFixed(0); unitText: cl.speedunit
        valueSize: 46; valueX: -14
        numFont: numfont.name; labelFont: labfont.name
        // dot above the number in Track
        Rectangle {
            width: 14; height: 14; radius: 7; color: "#ffffff"
            x: 108-7-10; y: 46
            opacity: cl.oMode===2 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }
    SideDial {
        id: oilDial
        x: 604-radius; y: 262-radius; z: 2
        radius: 108
        mode: cl.oMode; accent: cl.oAccent
        value: cl.oilp; minV: 0; maxV: cl.oilmax
        startAng: 170; sweep: -180        // mirror of the speedometer
        labels: [0,1,2,3,4].map(function(i){ return String(Math.round(cl.oilmax*i/4)) })
        steps: 16; majorEvery: 4; labelSize: 15
        valueText: cl.oilp.toFixed(cl.oildec); unitText: cl.oilunit
        valueSize: 46; valueX: 14
        warn: cl.oilWarn
        numFont: numfont.name; labelFont: labfont.name
        // oil can icon
        Canvas {
            x: 108-14+12; y: 52; width: 30; height: 16
            property color c: cl.oilWarn ? "#ff2d2d" : "#d0d6dd"
            onCChanged: requestPaint()
            onPaint: { var g=getContext("2d"); g.reset(); g.fillStyle=c; g.strokeStyle=c; g.lineWidth=2
                g.fillRect(6,6,16,8); g.fillRect(11,3,6,3)
                g.beginPath(); g.moveTo(22,8); g.lineTo(29,5); g.stroke()
                g.beginPath(); g.moveTo(6,8); g.lineTo(1,5); g.lineTo(1,9); g.stroke() }
        }
    }

    // ---- centre: rev counter ----
    Item {
        id: tacho
        property real rr: 172
        x: 400-rr; y: 236-rr; z: 3
        width: rr*2; height: rr*2

        DialFace { radius: tacho.rr; tint: cl.cAccent; tintOpacity: 0.13 }

        // Sport: concentric rings
        ArcRing {
            radius: tacho.rr; arcRadius: tacho.rr-16; count: 5; spacing: 5; lineWidth: 2
            startAng: 225; sweep: 270; strokeColor: "#ff2d2d"
            opacity: cl.mode===1 ? 1 : 0
            visible: opacity>0.01
            Behavior on opacity { NumberAnimation { duration: 450 } }
        }

        // Track: band track (dim) + rpm fill
        ArcRing {
            id: bandBase
            radius: tacho.rr; arcRadius: tacho.rr-62; lineWidth: 34
            startAng: 150; sweep: 240; strokeColor: "#3a140a"
            opacity: cl.bandOn ? 1 : 0
            visible: opacity>0.01
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }
        ArcRing {
            id: bandMask
            radius: tacho.rr; arcRadius: tacho.rr-62; lineWidth: 34
            startAng: 150; sweep: 240; strokeColor: "#ffffff"
            visible: false
        }
        ConicalGradient {
            id: bandGrad
            anchors.fill: bandMask
            source: bandMask
            angle: 150
            property real f: cl.rpmF*240/360
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ff3d12" }
                GradientStop { position: Math.max(0.001, bandGrad.f*0.6); color: "#ff541c" }
                GradientStop { position: Math.max(0.002, bandGrad.f); color: "#ff6a26" }
                GradientStop { position: Math.max(0.003, bandGrad.f+0.003); color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            opacity: bandBase.opacity
            visible: opacity>0.01
        }

        GaugeScale {
            radius: tacho.rr
            startAng: cl.startAng; sweep: cl.sweep
            steps: Math.round(cl.revmax/100); majorEvery: 10
            tickOuter: tacho.rr-12
            minorLen: 14; majorLen: 22; minorW: 2; majorW: 3; hotW: 4
            minorColor: cl.cTick; majorColor: "#ffffff"
            tickOpacity: cl.mode===0 ? 1 : 0
            hotFrom: cl.redline/cl.revmax; hotColor: cl.cHot
            hotOpacity: cl.mode===1 ? 0 : 1
            labels: { var a=[]; for(var i=0;i<=Math.round(cl.revmax/1000);i++) a.push(String(i)); return a }
            labelRadius: tacho.rr-54
            labelSize: 38
            labelColor: cl.mode===0 ? "#ece8ff" : "#ffffff"
            fontFamily: numfont.name
            labelBold: true
            Behavior on tickOpacity { NumberAnimation { duration: 450 } }
            Behavior on hotOpacity { NumberAnimation { duration: 450 } }
        }

        // needle
        Item {
            anchors.fill: parent
            rotation: cl.startAng+cl.sweep*cl.rpmF
            Rectangle {
                x: tacho.rr-6; y: 22
                width: 12; height: tacho.rr-22-26; radius: 6
                color: "#ff2a1a"; opacity: 0.25
            }
            Rectangle {
                x: tacho.rr-2.5; y: 24
                width: 5; height: tacho.rr-24-26; radius: 2.5
                color: "#ff2a1a"
                antialiasing: true
            }
        }
        // hub
        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 40; radius: 20
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#9aa1aa" }
                GradientStop { position: 1.0; color: "#2a2e34" }
            }
        }

        // gear
        Rectangle {
            id: gearBox
            x: tacho.rr+34; y: tacho.rr-32
            width: 58; height: 64; radius: 10
            color: cl.shiftOn ? (cl.blinkOn ? cl.cAccent : "#ffffff") : (cl.mode===2 ? "transparent" : "#f2f2f2")
            border.width: cl.mode===2 ? 3 : 0
            border.color: cl.cAccent
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2
                text: cl.gear
                color: cl.mode===2 && !cl.shiftOn ? "#ffffff" : "#0c0d10"
                font.family: numfont.name
                font.pixelSize: 50
                font.bold: true
            }
        }

        // mode label
        Rectangle {
            x: tacho.rr-width/2; y: tacho.rr+(cl.mode===2 ? 34 : 86)
            Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            width: 124; height: 34; radius: 17
            color: "#0a0b0e"
            border.width: 2
            border.color: cl.cAccent
            Text {
                anchors.centerIn: parent
                text: cl.names[cl.mode]
                color: cl.cAccent
                font.family: labfont.name
                font.pixelSize: 21
                font.bold: true
                font.letterSpacing: 2
            }
        }
    }

    // ---- bottom line ----
    Text {
        x: 18; y: 448
        text: "ODO " + Math.round(cl.odometer)
        color: "#8c939c"; font.family: labfont.name; font.pixelSize: 18
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 18; y: 448
        text: "TRIP " + (cl.trip/10).toFixed(1)
        color: "#8c939c"; font.family: labfont.name; font.pixelSize: 18
    }
}
