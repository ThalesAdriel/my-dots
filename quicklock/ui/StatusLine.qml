import QtQuick

// A Loader rather than a direct use, so a Quickshell built without UPower leaves the corner blank instead of failing the import that the surface, and with it the lock, is built out of. A missing battery reading is cosmetic; a lock screen that will not start is a session nobody locked.
Loader {
    // Absoluto a partir da raiz do shell: um caminho relativo aqui resolve
    // contra a raiz, nao contra ui/, e o Loader so diz "File not found" em
    // runtime -- nada no carregamento da config denuncia.
    source: "root:/ui/BatteryLabel.qml"
}
