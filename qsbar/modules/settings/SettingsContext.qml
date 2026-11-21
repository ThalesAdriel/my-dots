pragma Singleton

import QtQuick
import Quickshell

// Shared search state and palette constants for lazily loaded settings pages.
Singleton {
    id: root

    property string query: ""
    readonly property bool searching: root.query.trim() !== ""
    readonly property string needle: root.query.trim().toLowerCase()

    // One palette for the bar and the panels, so a colour picked for one is there to pick for the other.
    readonly property var surfaceColors: ["#000000", "#11121a", "#141414", "#1b1b1b", "#202020", "#1c2226", "#2e3436", "#241f31", "#3d3846", "#613583", "#813d9c", "#9c1d5e", "#c2407a"]
    // The last two are libadwaita's purple and pink accents, bright enough to read as an accent and still dark enough for the white text drawn on top of it.
    readonly property var accentColors: ["#3584e4", "#2ec27e", "#f5c211", "#ff7800", "#e01b24", "#986a44", "#9141ac", "#d56199"]

    // What the picture fields list when browsing: what Qt, with qt6-imageformats, can draw.
    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]

    // Whether a row stays up for the current query.
    function shows(item: Item, label: string): bool {
        if (!root.searching)
            return true;
        let text = label;
        for (let node = item.parent; node; node = node.parent) {
            if (node.searchTitle !== undefined)
                text += " " + node.searchTitle;
        }
        return text.toLowerCase().indexOf(root.needle) !== -1;
    }

    // Whether anything among these children is a row that matched.
    function anyHit(children: var): bool {
        for (let index = 0; index < children.length; index++) {
            if (children[index].hit === true)
                return true;
        }
        return false;
    }
}
