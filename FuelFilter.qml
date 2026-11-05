import QtQuick 2.3

// Fuel slosh filter -- the same two stages as GTDash:
//  1. trimmed-mean (median-window) filter: every 250 ms a raw sample goes into
//     a ring buffer; the buffer is sorted and only the centre ~40 % averaged,
//     so slosh spikes / dropouts sort to the ends and are thrown away (no
//     matching opposite transient needed to cancel them).
//  2. a velocity-limited glide from the shown value to that filtered value.
// damp: 0 = raw / off, 1 = light (6 samples, ~1.5 s window, fast glide)
//       ... 9 = heavy (30 samples, ~7.5 s window, slow glide). Default 3.
// level is what every fuel readout should use.
Item {
    id: ff
    property real raw: 0                 // live sender reading (bound by the dash)
    property int  damp: 3

    readonly property real level: damp <= 0 ? raw : display
    readonly property real vel: Math.max(8.0, 75.0 - (damp - 1) * 8.0)    // %/s for damp 1..9
    property real display: 0
    Behavior on display { SmoothedAnimation { velocity: ff.vel } }

    property var  buf: []
    readonly property int win: damp <= 0 ? 1 : (3 + damp * 3)
    property real filtered: 0
    onFilteredChanged: display = filtered

    // sample straight from the firmware when it is there (some IC7 builds
    // update values without a change signal, which would leave `raw` stale)
    function current() {
        if (typeof rpmtest !== "undefined" && rpmtest && rpmtest.fueldata !== undefined) {
            var v = Number(rpmtest.fueldata)
            if (!isNaN(v)) return v
        }
        return raw
    }
    function tick() {
        if (damp <= 0) return                           // raw mode: filter idle
        var b = buf
        b.push(current())
        while (b.length > win) b.shift()
        buf = b
        var n = b.length
        var a = b.slice().sort(function(x, y){ return x - y })
        var center = Math.max(1, Math.round(n * 0.4))  // keep ~40 % of the window
        var trim = Math.floor((n - center) / 2)        // drop the low / high ends
        var sum = 0, cnt = 0
        for (var i = trim; i < n - trim; i++) { sum += a[i]; cnt++ }
        filtered = cnt > 0 ? sum / cnt : a[Math.floor(n / 2)]
    }
    Timer { interval: 250; repeat: true; running: ff.damp > 0; onTriggered: ff.tick() }
    Component.onCompleted: { display = current(); filtered = display }   // start at the live level
}
