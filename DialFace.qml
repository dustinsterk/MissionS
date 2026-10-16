import QtQuick 2.3

// Round dial body: dark gap ring (separates overlapping dials), metal bezel,
// dark face and a faint tint in the mode colour.
Item {
    id: face
    property real radius: 100
    property color tint: "#000000"
    property real tintOpacity: 0.10
    width: radius*2
    height: radius*2

    Rectangle {
        anchors.centerIn: parent
        width: parent.width+16; height: width; radius: width/2
        color: "#000000"
        opacity: 0.85
    }
    Rectangle {
        anchors.fill: parent
        radius: width/2
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#6a7079" }
            GradientStop { position: 0.45; color: "#262a30" }
            GradientStop { position: 1.0; color: "#454b53" }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width-10; height: width; radius: width/2
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#181c22" }
            GradientStop { position: 1.0; color: "#06080b" }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width-10; height: width; radius: width/2
        color: face.tint
        opacity: face.tintOpacity
    }
}
