import QtQuick 2.3
import FileIO 1.0

// MissionS: five-dial cluster with Normal / Sport / Track modes (see Cluster.qml).
// Built on the RaceX setup: FileIO config file, the RACEXUI settings page
// (list on the left, live preview on the right) and the same joystick use.
//
// Joystick on the dial:  DOWN = next mode (Normal > Sport > Track), UP = settings
// In the settings:       LEFT/RIGHT move, UP/DOWN change (hold to repeat)
// The mode is saved, so the cluster comes back in the last mode.
//
// Config: /opt/IC7/screen_configs/missions_config.txt, stored as key=value
// lines (hand-editable, any order; missing keys use the default, lines
// starting with # are ignored):
//   mode=0            0 Normal, 1 Sport, 2 Track
//   modeButton=1      1 = DOWN on the dial changes the mode
//   speedUnits=0      0 km/h, 1 mph
//   speedMax=300      top of the speed scale
//   revMax=8000       top of the rev scale (rpm)
//   redline=7000      rpm
//   shiftRpm=0        shift light rpm, 0 = off
//   coolantHigh=110   coolant warning
//   coolantUnits=1    1 C, 0 F
//   oilPressLow=1.0   oil pressure warning
//   oilPressUnits=1   1 bar, 0 psi
//   fuelLow=10        low fuel warning (%)
//   fuelDamp=3        fuel slosh filter, 0 = raw ... 9 = heavy (GTDash filter)
// An older file with one plain number per line (same order as above) is read
// once and rewritten in this format.
Item {
    id: root
    width: 800
    height: 480

    // ---- live data ----
    property var d: (typeof rpmtest !== 'undefined') ? rpmtest : null
    property int udp_message: d ? d.udp_packetdata : 0
    property bool udp_up: udp_message&0x01
    property bool udp_down: udp_message&0x02
    property bool udp_left: udp_message&0x04
    property bool udp_right: udp_message&0x08
    property real rpm: rpmtest.rpmdata
    property real speedRaw: rpmtest.speeddata            // km/h
    property real watertempRaw: rpmtest.watertempdata    // C
    property real oilpressureRaw: rpmtest.oilpressuredata // bar
    property real fuelRaw: rpmtest.fueldata              // %
    // fuel goes through the GTDash slosh filter (FuelFilter.qml): trimmed mean
    // of the middle ~40 % of a 250 ms sample window, then a speed-limited glide.
    property int  fueldamp: 3                            // 0 = raw ... 9 = heavy
    FuelFilter { id: fuelFilter; raw: root.fuelRaw; damp: root.fueldamp }
    readonly property real fuelLevel: fuelFilter.level
    property int  gearpos: rpmtest.geardata
    // ODO / trip: read by polling (see the input poll below) instead of a
    // plain binding. On the unit the odometer can be loaded/updated without a
    // change signal, which left the binding stuck on its first value (0) --
    // other GARW dashes only refreshed it as a side effect of other bindings.
    // Number() also copes with the value arriving as text.
    property real odometerRaw: 0
    property real tripRaw: 0
    function readDistances(){
        if(!root.d) return
        var o=Number(root.d.odometer0data);    if(!isNaN(o) && o!==odometerRaw) odometerRaw=o
        var t=Number(root.d.tripmileage0data); if(!isNaN(t) && t!==tripRaw) tripRaw=t
    }

    // ---- settings ----
    property int  drivemode: 0
    property int  modebutton: 1
    property int  speedunits: 0
    property real speedmax: 300
    property real revmax: 8000
    property real redline: 7000
    property real shiftrpm: 0
    property real waterhigh: 110
    property int  waterunits: 1
    property real oilplow: 1.0
    property int  oilpunits: 1
    property real fuellow: 10

    property bool settings_on_off: false
    property bool menu_on_off: rpmtest.settings_on_offdata&0x02
    onSettings_on_offChanged: { try { if(settings_on_off) rpmtest.settings_on_offdata=rpmtest.settings_on_offdata|0x01
                                      else rpmtest.settings_on_offdata=rpmtest.settings_on_offdata&~0x01 } catch(e) {} }

    // ---- display values ----
    property real speedDisp: speedunits===1 ? speedRaw*0.621371 : speedRaw
    property real coolDisp: waterunits===1 ? watertempRaw : watertempRaw*9/5+32
    property real oilDisp: oilpunits===1 ? oilpressureRaw : oilpressureRaw*14.5038
    property string gearText: gearpos===9 ? "P" : gearpos===10 ? "R" : (gearpos>=1 && gearpos<=8) ? String(gearpos) : "N"

    FontLoader { id: basicfont; source: "fonts/basic.ttf" }

    ///////////////////////////////
    // settings list (same format as RaceX): type "num": step/min/max/dec,
    // fast = step multiplier after holding ~1.5 s, unit = suffix or function;
    // type "opt": opts = [[value, text], ...]; type "act": a command.
    // min/max/step/dec may be functions.
    ///////////////////////////////
    function tempUnit(){ return root.waterunits===1 ? " C" : " F" }
    function oilUnit(){ return root.oilpunits===1 ? " bar" : " psi" }
    property var items: [
        {group:"",            label:"Save & exit",  type:"act", act:"save", help:"Save the settings and go back to the dial."},
        {group:"Mode",        label:"Mode",         key:"drivemode", type:"opt", opts:[[0,"Normal"],[1,"Sport"],[2,"Track"]], help:"Normal, Sport or Track. The preview shows the change."},
        {group:"Mode",        label:"DOWN changes mode", key:"modebutton", type:"opt", opts:[[1,"On"],[0,"Off"]], help:"On: pressing DOWN on the dial steps Normal > Sport > Track."},
        {group:"Speed",       label:"Units",        key:"speedunits", type:"opt", opts:[[0,"km/h"],[1,"mph"]], help:"Units for the speedometer."},
        {group:"Speed",       label:"Scale top",    key:"speedmax", type:"num", step:30, min:120, max:420, dec:0, unit:function(){return root.speedunits===1?" mph":" km/h"}, help:"Highest number on the speedometer scale."},
        {group:"Engine",      label:"Rev scale",    key:"revmax",   type:"num", step:1000, min:6000, max:12000, dec:0, unit:" rpm", help:"Highest number on the rev counter."},
        {group:"Engine",      label:"Redline",      key:"redline",  type:"num", step:100, min:1000, max:function(){return root.revmax}, dec:0, fast:5, unit:" rpm", help:"The redline marks on the rev counter start here."},
        {group:"Engine",      label:"Shift light",  key:"shiftrpm", type:"num", step:100, min:0, max:function(){return root.revmax}, dec:0, fast:5, unit:" rpm", help:"The gear box flashes from this rpm (0 = off)."},
        {group:"Coolant",     label:"High warning", key:"waterhigh", type:"num", step:1, min:0, max:300, dec:0, fast:10, unit:tempUnit, help:"Coolant flashes red above this temperature."},
        {group:"Coolant",     label:"Units",        key:"waterunits", type:"opt", opts:[[1,"Celsius"],[0,"Fahrenheit"]], help:"Coolant temperature units."},
        {group:"Oil pressure", label:"Low warning", key:"oilplow", type:"num", step:function(){return root.oilpunits===1?0.1:1}, min:0, max:function(){return root.oilpunits===1?10:150}, dec:function(){return root.oilpunits===1?1:0}, fast:5, unit:oilUnit, help:"Oil pressure flashes red below this (only with the engine running)."},
        {group:"Oil pressure", label:"Units",       key:"oilpunits", type:"opt", opts:[[1,"bar"],[0,"psi"]], help:"Oil pressure units."},
        {group:"Fuel",        label:"Low warning",  key:"fuellow", type:"num", step:1, min:0, max:50, dec:0, unit:" %", help:"Fuel flashes red below this."},
        {group:"Fuel",        label:"Damping",      key:"fueldamp", type:"num", step:1, min:0, max:9, dec:0, help:"Smooths fuel slosh: 0 = raw, 1 = light (~1.5 s window) ... 9 = heavy (~7.5 s). Same filter as GTDash."},
        {group:"",            label:"Discard changes", type:"act", act:"discard", help:"Go back to the dial without saving; the last saved settings are restored."}
    ]
    property int cur: 0

    function pv(it, k){ var v=it[k]; return (typeof v==="function") ? v() : v }
    function valueText(it){
        if(it.type==="act") return ""
        var v=root[it.key]
        if(it.type==="opt"){
            for(var i=0;i<it.opts.length;i++) if(it.opts[i][0]==v) return it.opts[i][1]
            return String(v)
        }
        var u=(typeof it.unit==="function") ? it.unit() : (it.unit||"")
        return Number(v).toFixed(pv(it,"dec"))+u
    }
    function warningText(it){
        if(it.key==="shiftrpm" && root.shiftrpm>0 && root.shiftrpm>root.redline) return "Shift light is above the redline"
        if(it.key==="redline" && root.redline>root.revmax) return "Redline is above the scale"
        return ""
    }
    function change(dir, mult){
        var it=items[cur]
        if(it.type==="opt"){
            var i=0
            for(var j=0;j<it.opts.length;j++) if(it.opts[j][0]==root[it.key]) i=j
            i=(i+dir+it.opts.length)%it.opts.length
            root[it.key]=it.opts[i][0]
        } else if(it.type==="num"){
            var v=Number(root[it.key])+dir*pv(it,"step")*mult
            v=Math.max(pv(it,"min"),Math.min(pv(it,"max"),v))
            root[it.key]=Number(v.toFixed(pv(it,"dec")))
        }
        if(it.key==="revmax") root.redline=Math.min(root.redline, root.revmax)
    }
    function openSettings(){ cur=0; settings_on_off=true }
    function act(it){
        if(it.act==="save"){ settings_on_off=false; save_settings() }
        else if(it.act==="discard"){ settings_on_off=false; applyConfig() }
    }

    property int holdDir: 0
    property int holdCount: 0
    Timer {
        id: valueTimer
        interval: 400; repeat: true
        onTriggered: { interval=100; holdCount++
                       var it=items[cur]
                       if(it.type==="num") change(holdDir, holdCount>15 ? (it.fast||1) : 1) }
    }
    property int navDir: 0
    Timer { id: navTimer; interval: 400; repeat: true; onTriggered: { interval=150; move(navDir) } }
    function move(dir){ cur=(cur+dir+items.length)%items.length }
    function valuePress(dir){
        var it=items[cur]
        if(it.type==="act"){ act(it); return }
        change(dir,1)
        if(it.type==="num"){ holdDir=dir; holdCount=0; valueTimer.interval=400; valueTimer.start() }
    }

    // DOWN on the dial: next mode, saved straight away
    function nextMode(){
        drivemode=(drivemode+1)%3
        save_settings()
    }

    ///////////////////////////////
    // settings page
    ///////////////////////////////
    Rectangle {
        id: settingspage
        anchors.fill: parent
        color: "#e0101418"
        z: 1
        visible: opacity>0
        opacity: settings_on_off ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle { x:0; y:0; width:800; height:44; color:"#1c232b"
            Text { x:16; anchors.verticalCenter: parent.verticalCenter; text:"Settings"; color:"#ffffff"; font.pixelSize:24; font.family: basicfont.name }
            Text { anchors.right: parent.right; anchors.rightMargin:16; anchors.verticalCenter: parent.verticalCenter
                   text:(cur+1)+" / "+items.length; color:"#8a96a3"; font.pixelSize:18; font.family: basicfont.name }
        }

        ListView {
            id: list
            x:0; y:48; width:396; height:392
            clip: true
            model: items.length
            currentIndex: root.cur
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 110
            preferredHighlightEnd: height-110
            highlightMoveDuration: 150
            interactive: false
            delegate: Item {
                property var it: root.items[index]
                property bool head: it.group!=="" && (index===0 || root.items[index-1].group!==it.group)
                property bool sel: index===root.cur
                width: list.width
                height: head ? 76 : 44
                Text { visible: head; x:16; y:10; text: it.group.toUpperCase(); color:"#6fa8dc"; font.pixelSize:15; font.bold:true; font.family: basicfont.name }
                Rectangle {
                    y: head ? 32 : 0; width: parent.width; height: 44
                    color: sel ? "#2e3b48" : "transparent"
                    Rectangle { visible: sel; width:5; height:parent.height; color: dial.cAccent }
                    Text { x:20; anchors.verticalCenter: parent.verticalCenter; text: it.label
                           color: it.type==="act" ? (it.act==="save" ? "#7fd67f" : "#e08a8a") : "#ffffff"
                           font.pixelSize:22; font.family: basicfont.name }
                    Text { id: val; anchors.right: parent.right; anchors.rightMargin: sel && it.type!=="act" ? 36 : 16; anchors.verticalCenter: parent.verticalCenter
                           text: root.valueText(it)
                           color: root.warningText(it)!=="" ? "#ff8c69" : (sel ? "#ffd75e" : "#c8d0d8")
                           font.pixelSize:22; font.family: basicfont.name }
                    Column { visible: sel && it.type!=="act"; anchors.right: parent.right; anchors.rightMargin:12; anchors.verticalCenter: parent.verticalCenter; spacing:4
                        Repeater { model: 2
                            Item { width:14; height:8; clip: true; property bool up: index===0
                                Rectangle { width:10; height:10; x:2; y: parent.up ? 3 : -5; rotation:45; color:"#ffd75e"; antialiasing: true } } }
                    }
                }
            }
        }

        // live preview frame (the cluster itself shrinks into it, see below)
        Rectangle { x:401; y:55; width:398; height:242; color:"transparent"; border.color:"#3a4654"; radius:4; z:3 }
        Text { x:410; y:304; text:"Preview"; color:"#8a96a3"; font.pixelSize:15; font.family: basicfont.name }

        Column {
            x:410; y:330; width:376; spacing:8
            Text { width:parent.width; wrapMode: Text.WordWrap; text: root.items[root.cur].help; color:"#dfe6ec"; font.pixelSize:18; font.family: basicfont.name }
            Text { width:parent.width; visible: text!==""; text: root.warningText(root.items[root.cur]); color:"#ff8c69"; font.pixelSize:16; font.family: basicfont.name }
        }

        Rectangle { x:0; y:444; width:800; height:36; color:"#1c232b"
            Text { anchors.centerIn: parent; color:"#aeb8c2"; font.pixelSize:16; font.family: basicfont.name
                   text: root.items[root.cur].type==="act" ? "LEFT / RIGHT  move        UP or DOWN  select"
                                                           : "LEFT / RIGHT  move        UP / DOWN  change (hold for faster)" }
        }
    }

    ///////////////////////////////
    // config file
    ///////////////////////////////
    FileIO {
        id: config_file
        source: "/opt/IC7/screen_configs/missions_config.txt"
        onError: console.log(msg)
    }
    // [key in the file, property]; the order is also the old one-number-per-line order
    property var cfgKeys: [
        ["mode",          "drivemode"],
        ["modeButton",    "modebutton"],
        ["speedUnits",    "speedunits"],
        ["speedMax",      "speedmax"],
        ["revMax",        "revmax"],
        ["redline",       "redline"],
        ["shiftRpm",      "shiftrpm"],
        ["coolantHigh",   "waterhigh"],
        ["coolantUnits",  "waterunits"],
        ["oilPressLow",   "oilplow"],
        ["oilPressUnits", "oilpunits"],
        ["fuelLow",       "fuellow"],
        ["fuelDamp",      "fueldamp"]
    ]
    property var cfgMap: ({})           // key -> value text, as last read or saved
    property bool cfgKeyValue: false    // the file on disk is already key=value

    function rline(i){
        config_file.openforreading()
        var s=config_file.readopenfile(i)
        config_file.close()
        return (s===undefined || s===null) ? "" : String(s)
    }
    function readConfig(){
        var map={}, lines=[], sawEq=false, i, s, eq
        for(i=0;i<40;i++){
            s=rline(i).trim()
            lines.push(s)
            if(s==="" || s.charAt(0)==="#") continue
            eq=s.indexOf("=")
            if(eq>0){ sawEq=true; map[s.slice(0,eq).trim()]=s.slice(eq+1).trim() }
        }
        if(!sawEq){   // old format: one number per line
            for(i=0;i<cfgKeys.length;i++) if(lines[i]!=="") map[cfgKeys[i][0]]=lines[i]
        }
        cfgMap=map
        cfgKeyValue=sawEq
    }
    function numOr(v, d){ var s=String(v===undefined || v===null ? "" : v).trim(); return (s==="" || isNaN(Number(s))) ? d : Number(s) }
    function cv(key, d){ return numOr(cfgMap[key], d) }
    function applyConfig(){
        root.drivemode=Math.max(0, Math.min(2, Math.round(cv("mode", 0))))
        root.modebutton=cv("modeButton", 1)===0 ? 0 : 1
        root.speedunits=cv("speedUnits", 0)===1 ? 1 : 0
        root.speedmax=cv("speedMax", root.speedunits===1 ? 180 : 300)
        root.revmax=cv("revMax", 8000)
        root.redline=cv("redline", root.revmax-1000)
        root.shiftrpm=cv("shiftRpm", 0)
        root.waterunits=cv("coolantUnits", 1)===0 ? 0 : 1
        root.waterhigh=cv("coolantHigh", root.waterunits===1 ? 110 : 230)
        root.oilpunits=cv("oilPressUnits", 1)===0 ? 0 : 1
        root.oilplow=cv("oilPressLow", root.oilpunits===1 ? 1.0 : 15)
        root.fuellow=cv("fuelLow", 10)
        root.fueldamp=Math.max(0, Math.min(9, Math.round(cv("fuelDamp", 3))))
    }
    function save_settings(){
        var out="", map={}, i, k, v
        for(i=0;i<cfgKeys.length;i++){
            k=cfgKeys[i][0]
            v=root[cfgKeys[i][1]]
            v=(k==="oilPressLow") ? Number(v).toFixed(1) : String(Math.round(Number(v)*10)/10)
            map[k]=v
            out+=k+"="+v+"\n"
        }
        config_file.open()
        config_file.writetoopenfile(out)
        config_file.close()
        cfgMap=map
        cfgKeyValue=true
    }
    Component.onCompleted: {
        readDistances()
        readConfig()           // missing file or keys -> defaults
        applyConfig()
        if(!cfgKeyValue) save_settings()   // first run, or migrate an old numbers-only file
        // Tell the firmware the warnings are handled here (strip at the bottom,
        // turn signals at the top), so it does NOT draw its own warning-light
        // bar over the dash. Same call as GTDash; guarded because the desktop
        // simulator doesn't have the property.
        if (root.d) { try { root.d.DISABLE_WARNING_OVERLAY = "YES_WARNINGS_HANDLED_LOCALLY"; } catch (e) {} }
    }

    ///////////////////////////////
    // joystick (same bits as RaceX)
    ///////////////////////////////
    property int inputs: d ? d.inputsdata : 0
    property int pollCount: 0
    // Some IC7 backends update inputsdata without a change signal (see the
    // GTDash notes), so also poll it every 50 ms. The D-pad handlers below are
    // edge-triggered on the derived bools, so polling never double-acts.
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: { if(root.d){ root.inputs=root.d.inputsdata; root.udp_message=root.d.udp_packetdata
                                   if(++root.pollCount%10===0) root.readDistances() } }   // ODO/trip every 0.5 s
    }
    property bool up_joystick:    inputs&0x20 || root.udp_up
    property bool down_joystick:  inputs&0x2000 || root.udp_down
    property bool left_joystick:  inputs&0x20000000 || root.udp_left
    property bool right_joystick: inputs&0x40000000 || root.udp_right

    property bool movedown: left_joystick
    property bool moveup: right_joystick
    property bool increament: up_joystick
    property bool decreament: down_joystick

    onMovedownChanged: if(movedown&&settings_on_off){move(-1);navDir=-1;navTimer.interval=400;navTimer.start()} else if(!moveup)navTimer.stop()
    onMoveupChanged:   if(moveup&&settings_on_off){move(1);navDir=1;navTimer.interval=400;navTimer.start()} else if(!movedown)navTimer.stop()

    onIncreamentChanged: if(increament&&!settings_on_off&&!menu_on_off)openSettings()
                         else if(increament&&!menu_on_off)valuePress(1)
                         else if(!increament&&!decreament)valueTimer.stop()
    onDecreamentChanged: if(decreament&&!settings_on_off&&!menu_on_off&&modebutton===1)nextMode()
                         else if(decreament&&settings_on_off)valuePress(-1)
                         else if(!increament&&!decreament)valueTimer.stop()

    ///////////////////////////////
    // the cluster; in the settings it shrinks into the preview frame and,
    // on the Engine rows, revs to just under the scale top
    ///////////////////////////////
    property bool revPreview: settings_on_off && items[cur].group==="Engine"

    Cluster {
        id: dial
        mode: root.drivemode
        rpm: root.revPreview ? root.revmax*0.94 : root.rpm
        revmax: root.revmax
        redline: root.redline
        shiftrpm: root.shiftrpm
        gear: root.gearText
        speed: root.speedDisp
        speedmax: root.speedmax
        speedunit: root.speedunits===1 ? "MPH" : "KM/H"
        oilp: root.oilDisp
        oilmax: root.oilpunits===1 ? 8 : 120
        oilunit: root.oilpunits===1 ? "BAR" : "PSI"
        oildec: root.oilpunits===1 ? 1 : 0
        coolant: root.coolDisp
        coolmin: root.waterunits===1 ? 40 : 100
        coolmax: root.waterunits===1 ? 140 : 280
        fuel: root.fuelLevel
        coolWarn: root.coolDisp>root.waterhigh
        oilWarn: root.rpm>400 && root.oilDisp<root.oilplow
        fuelWarn: root.fuelLevel<root.fuellow
        inputs: root.inputs
        canAsciiRaw: (root.d && root.d.canasciidata !== undefined) ? root.d.canasciidata : ""
        holdLabel: root.settings_on_off
        odometer: root.speedunits===1 ? root.odometerRaw*0.621371/10 : root.odometerRaw/10
        trip: root.speedunits===1 ? root.tripRaw*0.621371 : root.tripRaw

        transformOrigin: Item.TopLeft
        x: settings_on_off ? 401 : 0
        y: settings_on_off ? 56 : 0
        scale: settings_on_off ? 0.495 : 1.0
        Behavior on x { NumberAnimation { duration: 300 } }
        Behavior on y { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 300 } }
        z: settings_on_off ? 2 : 0
        clip: true
    }

    Rectangle { anchors.fill: parent; color: "#000000"; z: -1 }
}
