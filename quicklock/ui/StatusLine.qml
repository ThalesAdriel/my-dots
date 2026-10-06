import QtQuick

// A Loader rather than a direct use.
Loader {
    // Absoluto a partir da raiz do shell: um caminho relativo aqui resolve.
    // contra a raiz, nao contra ui/, e o Loader so diz "File not found" em.
    // runtime -- nada no carregamento da config denuncia.
    source: "root:/ui/BatteryLabel.qml"
}
