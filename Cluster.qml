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
    property int  inputs: 0        // rpmtest.inputsdata (telltales, turn signals)

    // ECU ASCII status text over CAN (canasciidata), same logic as GTDash:
    // sanitise to printable ASCII, collapse repeats/partials, then the
    // settle / dwell / TPMS-hush pipeline in the canAsciiText item below.
    property string canAsciiRaw: ""
    readonly property string canAsciiStr: {
        var src = cl.canAsciiRaw;
        if (!src) return "";
        var out = "";
        for (var i = 0; i < src.length; i++) {
            var c = src.charCodeAt(i);
            if (c >= 32 && c < 127) out += src.charAt(i);   // keep printable ASCII; drop NUL/control/high bytes
        }
        return cl.canAsciiCollapse(out.trim());
    }
    // True if b is the same characters as a in a rotated order once spaces are
    // removed (b is a rotation of a). Recognises a no-separator repeat that the
    // collapse reordered ("7% Slip" vs "Slip7%", "LTC Off" vs "OffLTC") so the
    // display can hold the version already shown instead of flipping to the garble.
    function canAsciiSameRotation(a, b) {
        // a = fresh candidate, b = the text already on screen. Only treat a as
        // a garbled rotation of b when a has NO separator but b DOES -- i.e. a
        // is the space-stripped, reordered repeat ("Slip7%" of "7% Slip"). Two
        // distinct single words that happen to be rotations (STOP/POST) both
        // lack spaces and so are left alone (hardened residual-risk guard).
        if (a.indexOf(" ") >= 0 || b.indexOf(" ") < 0) return false;
        var x = a.split(" ").join(""), y = b.split(" ").join("");
        if (!x.length || x.length !== y.length || x === y) return false;
        return (x + x).indexOf(y) >= 0;
    }
    // Message severity: faults outrank info. Drives BOTH the min-dwell and the
    // severity-hold gate in canAsciiSettle (one notion, no separate priority).
    function canAsciiSeverity(s) {
        if (!s) return 0;                                   // blank
        return (s.indexOf("FAULT") >= 0 || s === "TPMS") ? 2 : 1;   // 2 = fault-class, 1 = info
    }
    // Collapse a host buffer that does not self-clear and piles a message up.
    // Word-level only: drop word-fragments left by a window that opened or closed
    // mid-word, drop consecutive duplicate words, then collapse an exact repeated
    // phrase to one copy. Distinct messages ("TPMS FAULT", "Boost Control Fault
    // Detected") have no such repeat and pass through untouched.
    // NOTE: a char-level "smallest period" collapse was tried and removed -- it
    // mangled FAULT. Do NOT reintroduce it.
    function canAsciiCollapse(out) {
        if (!out.length) return "";
        var w = out.split(/\s+/);
        // The host window can open or close mid-word, so the first token may be a
        // SUFFIX of the real word ("AULT FAULT", "T FAULT", "ULT FAULT") and the
        // last token a PREFIX of it ("FAULT FAU", "LT FAULT FAU"). Drop those
        // partials. (substring, not endsWith/startsWith, for Qt 5.12.8 V4 safety.)
        if (w.length >= 2) {
            var f = w[0], s = w[1];
            if (f.length < s.length && s.substring(s.length - f.length) === f) w.shift();
        }
        if (w.length >= 2) {
            var e = w[w.length - 1], q = w[w.length - 2];
            if (e.length < q.length && q.substring(0, e.length) === e) w.pop();
        }
        var c = [];                                                // collapse consecutive duplicate words
        for (var a = 0; a < w.length; a++)
            if (a === 0 || w[a] !== w[a - 1]) c.push(w[a]);
        var n = c.length;                                          // collapse an exact repeated phrase
        for (var pp = 1; pp <= (n >> 1); pp++) {
            if (n % pp !== 0) continue;
            var rep = true;
            for (var j = pp; j < n; j++) { if (c[j] !== c[j - pp]) { rep = false; break; } }
            if (rep) return c.slice(0, pp).join(" ");
        }
        return c.join(" ");
    }
    property real trip: 0

    // Saira SemiExpanded (SIL Open Font License, see fonts/OFL-Saira.txt):
    // SemiBold for numbers, Medium for labels
    FontLoader { id: numfont; source: "fonts/SairaSemiExpanded-SemiBold.ttf" }
    FontLoader { id: labfont; source: "fonts/SairaSemiExpanded-Medium.ttf" }

    // ---- mode colours ----
    property var accentPal: ["#a493ff", "#ff2d2d", "#ff541c"]
    property var tickPal: ["#c9bfff", "#ff2d2d", "#ff541c"]
    property var hotPal:  ["#ff7a26", "#ff2d2d", "#ff2d2d"]
    property var names:   ["NORMAL", "SPORT", "TRACK"]

    // centre follows the mode at once, the side dials a moment later
    property int oMode: 0
    Component.onCompleted: { oMode=mode; bandOn=(mode===2); labelTimer.restart() }
    onModeChanged: { outerDelay.restart(); syncBand(); showLabel() }

    // mode label (NORMAL / SPORT / TRACK): shown on start-up and on every mode
    // change, fades away after 3 s. holdLabel keeps it up (settings preview).
    property bool holdLabel: false
    property bool labelShown: true
    function showLabel(){ labelShown=true; labelTimer.restart() }
    Timer { id: labelTimer; interval: 3000; onTriggered: cl.labelShown=false }
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
        arcName: "fuel"
        x: 68-radius; y: 226-radius; z: 1
        radius: 64
        mode: cl.oMode; accent: cl.oAccent
        value: cl.fuel; minV: 0; maxV: 100
        startAng: 200; sweep: 140
        labels: []; steps: 8; majorEvery: 4; labelSize: 13
        hotFrom: 2
        valueText: cl.fuel.toFixed(0); unitText: "%"
        valueSize: 26; valueX: -8; valueY: radius-16
        warn: cl.fuelWarn
        numberInNormalOnly: true
        numFont: numfont.name; labelFont: labfont.name
        // pump icon
        Image {   // pump icon: white, red when low
            x: 40; y: 22; height: 20; fillMode: Image.PreserveAspectFit; smooth: true
            source: cl.fuelWarn ? "assets/fuel_level_warning.png" : "assets/fuel.png"
        }
    }
    SideDial {
        id: coolDial
        arcName: "cool"
        x: 732-radius; y: 226-radius; z: 1
        radius: 64
        mode: cl.oMode; accent: cl.oAccent
        value: cl.coolant; minV: cl.coolmin; maxV: cl.coolmax
        startAng: 160; sweep: -140      // mirrored: cold at the bottom, hot at the top
        labels: []
        steps: 8; majorEvery: 4; labelSize: 13
        hotFrom: 2
        valueText: cl.coolant.toFixed(0)+"°"; unitText: ""
        valueSize: 24; valueX: 8; valueY: radius-14
        warn: cl.coolWarn
        numFont: numfont.name; labelFont: labfont.name
        // thermometer icon
        Image {   // coolant icon: white, red when hot
            x: 54; y: 20; height: 22; fillMode: Image.PreserveAspectFit; smooth: true
            source: cl.coolWarn ? "assets/coolant_temp_warning.png" : "assets/coolant_white.png"
        }
    }

    // ---- side dials ----
    SideDial {
        id: speedDial
        arcName: "speed"
        x: 196-radius; y: 262-radius; z: 2
        radius: 108
        mode: cl.oMode; accent: cl.oAccent
        value: cl.speed; minV: 0; maxV: cl.speedmax
        startAng: 190; sweep: 180         // only the part not hidden by the rev counter
        labels: [0,1,2,3,4,5,6].map(function(i){ return String(Math.round(cl.speedmax*i/6)) })
        steps: 24; majorEvery: 4; labelSize: 15
        valueText: Math.round(Math.max(0, cl.speed)).toFixed(0); unitText: cl.speedunit
        valueSize: 40; valueX: -12
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
        arcName: "oil"
        x: 604-radius; y: 262-radius; z: 2
        radius: 108
        mode: cl.oMode; accent: cl.oAccent
        value: cl.oilp; minV: 0; maxV: cl.oilmax
        startAng: 170; sweep: -180        // mirror of the speedometer
        labels: [0,1,2,3,4].map(function(i){ return String(Math.round(cl.oilmax*i/4)) })
        steps: 16; majorEvery: 4; labelSize: 15
        valueText: cl.oilp.toFixed(cl.oildec); unitText: cl.oilunit
        valueSize: 40; valueX: 12
        warn: cl.oilWarn
        numFont: numfont.name; labelFont: labfont.name
        // oil can icon
        Image {   // oil can icon: white, red on low pressure
            x: 108-17+12; y: 54; height: 15; fillMode: Image.PreserveAspectFit; smooth: true
            source: cl.oilWarn ? "assets/oil_pressure_warning.png" : "assets/oil_white.png"
        }
    }

    // ---- centre: rev counter ----
    Item {
        id: tacho
        property real rr: 172
        x: 400-rr; y: 236-rr; z: 3
        width: rr*2; height: rr*2

        DialFace { radius: tacho.rr; tint: cl.cAccent; tintOpacity: 0.13 }

        // Sport: concentric rings (pre-rendered, tools/make_arcs.py)
        Image {
            anchors.fill: parent; smooth: true
            source: "arcs/tacho_sport_rings.png"
            opacity: cl.mode===1 ? 1 : 0
            visible: opacity>0.01
            Behavior on opacity { NumberAnimation { duration: 450 } }
        }

        // Track: band track (dim) + rpm fill (the white band is the gradient's mask)
        Image {
            id: bandBase
            anchors.fill: parent; smooth: true
            source: "arcs/tacho_band_base.png"
            opacity: cl.bandOn ? 1 : 0
            visible: opacity>0.01
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }
        Image {
            id: bandMask
            anchors.fill: parent; smooth: true
            source: "arcs/tacho_band_mask.png"
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
            labelBold: false
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
                font.pixelSize: 46
            }
        }

        // mode label
        Rectangle {
            opacity: (cl.labelShown || cl.holdLabel) ? 1 : 0
            visible: opacity>0.01
            Behavior on opacity { NumberAnimation { duration: 600 } }
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
                font.letterSpacing: 1.5
            }
        }
    }

    // ---- turn signals (upper corners), straight from the flasher bits ----
    Image {
        source: "assets/left_indicator.png"
        x: 22; y: 14; height: 46; fillMode: Image.PreserveAspectFit; smooth: true
        visible: (cl.inputs & 0x40) !== 0
    }
    Image {
        source: "assets/right_indicator.png"
        x: 800-22-width; y: 14; height: 46; fillMode: Image.PreserveAspectFit; smooth: true
        visible: (cl.inputs & 0x80) !== 0
    }

    // ---- warning light strip (same icons and bits as GTDash) ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 444; spacing: 10
        Repeater {
            model: [
                { src: "high_beam",            bit: 0x10 },
                { src: "sidelight",            bit: 0x800 },      // sidelights (green)
                { src: "rear_fog",             bit: 0x08 },       // rear fog (amber)
                { src: "brake_warning",        bit: 0x8000100 },  // brake | handbrake
                { src: "oil_pressure_warning", bit: 0x200 },
                { src: "battery_warning",      bit: 0x02 },
                { src: "seatbelt_warning",     bit: 0x400 },
                { src: "abs_warning",          bit: 0x20000 },
                { src: "tc_warning",           bit: 0x10000 },    // traction control (amber)
                { src: "mil_warning",          bit: 0x40000 },
                { src: "airbag_warning",       bit: 0x8000 },
                { src: "door_open",            bit: 0x4000 }
            ]
            Item {
                id: ttCell
                height: 24
                width: ttImg.width
                property bool isTc: modelData.src === "tc_warning"
                property bool tcOff: (cl.inputs & 0x10000000) !== 0   // TC OFF bit
                Image {
                    id: ttImg
                    source: "assets/" + modelData.src + ".png"
                    height: 24
                    width: Math.min(38, implicitHeight > 0 ? 24 * implicitWidth / implicitHeight : 34)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    // lit when its bit is set; TC also lights when switched OFF
                    opacity: ((cl.inputs & modelData.bit) || (ttCell.isTc && ttCell.tcOff)) ? 1.0 : 0.2
                }
                Rectangle {   // dark backing so "OFF" reads over the amber symbol
                    visible: ttCell.isTc && ttCell.tcOff
                    anchors.centerIn: ttImg
                    width: offTxt.implicitWidth + 4; height: offTxt.implicitHeight + 1; radius: 2
                    color: "#000000"; opacity: 0.6
                }
                Text {
                    id: offTxt
                    visible: ttCell.isTc && ttCell.tcOff
                    anchors.centerIn: ttImg
                    text: "OFF"; color: "#ffffff"
                    font.family: labfont.name; font.pixelSize: 9
                }
            }
        }
    }

    // ---- ECU ASCII status line (from GTDash), above ODO ----
    // Cycling ECU status (FAULT, TPMS, LTC, SLIP%...): a value must hold 120 ms
    // to show, info messages get a 0.9 s minimum dwell (faults interrupt at
    // once), 3 s of quiet blanks the line, and after 5 TPMS->FAULT occurrences
    // in a power cycle the repeating TPMS fault is hushed until the next one.
    Text {
        id: canAsciiText
        property string pending: cl.canAsciiStr    // latest collapsed value
        property int canAsciiPairs: 0                 // TPMS->FAULT occurrences this power cycle (cumulative)
        property bool canAsciiAwaitFault: false       // last settled message was TPMS (next FAULT counts once)
        property bool canAsciiInFault: false          // inside a TPMS-fault context (its FAULTs repeat)
        property bool canAsciiHushed: false           // TPMS fault latched off for the session
        readonly property int canAsciiSuppressAfter: 5  // hush after this many TPMS->FAULT occurrences (0 = never)
        readonly property int canAsciiDwellMs: 900      // min ms a committed message holds before a non-higher-severity one may replace it
        onPendingChanged: canAsciiSettle.restart()    // debounce: ignore sub-120 ms blips
        visible: text.length > 0
        text: ""
        x: 18; y: 420                                 // just above ODO, below the rev counter
        width: 360; elide: Text.ElideRight
        color: "#ffcf6b"                              // amber ECU message
        font.family: labfont.name; font.pixelSize: 16
        Timer {
            id: canAsciiSettle
            interval: 120; repeat: false
            onTriggered: {
                var c = canAsciiText.pending;
                if (!c) {
                    canAsciiClearTimer.restart();             // empty -> arm blank
                } else {
                    var show = c;
                    if (c === "TPMS") {
                        if (canAsciiText.canAsciiSuppressAfter > 0
                            && canAsciiText.canAsciiPairs >= canAsciiText.canAsciiSuppressAfter)
                            canAsciiText.canAsciiHushed = true;          // enough occurrences -> latch off
                        canAsciiText.canAsciiAwaitFault = true;          // a FAULT may follow
                        canAsciiText.canAsciiInFault = true;             // entering the TPMS-fault context
                        if (canAsciiText.canAsciiHushed) show = "";
                    } else if (c === "FAULT") {
                        if (canAsciiText.canAsciiAwaitFault) {           // first FAULT after a TPMS = one occurrence
                            canAsciiText.canAsciiAwaitFault = false;
                            if (!canAsciiText.canAsciiHushed) canAsciiText.canAsciiPairs += 1;
                        }
                        if (canAsciiText.canAsciiHushed && canAsciiText.canAsciiInFault) show = "";   // hush repeating TPMS-fault FAULT
                        // a FAULT outside a TPMS-fault context keeps showing
                    } else {
                        canAsciiText.canAsciiAwaitFault = false;
                        canAsciiText.canAsciiInFault = false;            // other text ends the TPMS-fault context
                    }
                    // If the new value is just a space-stripped rotation of what is
                    // already on screen (host re-sent a no-separator repeat that the
                    // collapse reordered, e.g. "7% Slip" -> "Slip7%"), keep the version
                    // already shown rather than swapping to the reordered one.
                    if (show && canAsciiText.text && show !== canAsciiText.text
                        && cl.canAsciiSameRotation(show, canAsciiText.text)) show = canAsciiText.text;
                    // Min on-screen dwell + severity hold (one gate). A fault-class
                    // message (sev 2) interrupts at once -- whether it replaces info
                    // or another fault -- so the TPMS/FAULT path is unchanged. Anything
                    // else (info) waits until the showing message has had its dwell, so
                    // a fast ECU rotation stays readable. Severity is only info=1 /
                    // fault=2 here, so "interrupt" reduces to "candidate is a fault".
                    // canAsciiDwell fires at dwell-end and re-runs this settle.
                    if (show && canAsciiText.text && show !== canAsciiText.text
                        && cl.canAsciiSeverity(show) !== 2 && canAsciiDwell.running)
                        return;                              // hold current message through its dwell
                    canAsciiClearTimer.stop();
                    if (show !== canAsciiText.text) {
                        canAsciiText.text = show;
                        if (show) canAsciiDwell.restart(); else canAsciiDwell.stop();
                    }
                }
            }
        }
        Timer {
            id: canAsciiClearTimer
            interval: 3000; repeat: false
            onTriggered: { canAsciiText.text = ""; canAsciiText.canAsciiAwaitFault = false; canAsciiText.canAsciiInFault = false; }   // quiet ends the context
        }
        Timer {                                          // minimum on-screen dwell for a committed message
            id: canAsciiDwell
            interval: canAsciiText.canAsciiDwellMs; repeat: false
            onTriggered: canAsciiSettle.restart()        // re-evaluate the latest pending now the dwell elapsed
        }
    }

    // ---- bottom line ----
    Text {
        x: 18; y: 448
        text: "ODO " + Math.floor(cl.odometer)   // whole units, never rounded up (like the other GARW dashes)
        color: "#8c939c"; font.family: labfont.name; font.pixelSize: 18
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 18; y: 448
        text: "TRIP " + (cl.trip/10).toFixed(1)
        color: "#8c939c"; font.family: labfont.name; font.pixelSize: 18
    }
}
