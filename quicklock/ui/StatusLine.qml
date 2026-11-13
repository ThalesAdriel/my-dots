import QtQuick

// A Loader rather than a direct use.
Loader {
    // Absolute from the shell root: a relative path here resolves against the
    // root, not against ui/, and the Loader only says "File not found" at
    // runtime; nothing while the config loads gives it away.
    source: "root:/ui/BatteryLabel.qml"
}
