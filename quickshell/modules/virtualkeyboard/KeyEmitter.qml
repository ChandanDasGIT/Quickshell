pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool shiftHeld: false
    property bool ctrlHeld: false
    property bool superHeld: false
    property bool altHeld: false

    // Explicit Linux input-event-codes
    readonly property var keyCodes: ({
        "Escape": "1",
        "BackSpace": "14",
        "Tab": "15",
        "Return": "28",
        "Space": "57",
        "Up": "103",
        "Left": "105",
        "Right": "106",
        "Down": "108",
        "Delete": "111",
        "Insert": "110",
        "Home": "102",
        "End": "107",
        "Prior": "104", // Page Up
        "Next": "109",  // Page Down
        "KP_0": "82", "KP_1": "79", "KP_2": "80", "KP_3": "81",
        "KP_4": "75", "KP_5": "76", "KP_6": "77", "KP_7": "71",
        "KP_8": "72", "KP_9": "73",
        "KP_Divide": "98", "KP_Multiply": "55",
        "KP_Subtract": "74", "KP_Add": "78",
        "KP_Decimal": "83", "KP_Enter": "96",
        "F1": "59", "F2": "60", "F3": "61", "F4": "62",
        "F5": "63", "F6": "64", "F7": "65", "F8": "66",
        "F9": "67", "F10": "68", "F11": "87", "F12": "88"
    })

    function getAlphaKeyCode(c) {
        const letters = {
            "a": "30", "b": "48", "c": "46", "d": "32", "e": "18", "f": "33",
            "g": "34", "h": "35", "i": "23", "j": "36", "k": "37", "l": "38",
            "m": "50", "n": "49", "o": "24", "p": "25", "q": "16", "r": "19",
            "s": "31", "t": "20", "u": "22", "v": "47", "w": "17", "x": "45",
            "y": "21", "z": "44",
            "1": "2", "2": "3", "3": "4", "4": "5", "5": "6",
            "6": "7", "7": "8", "8": "9", "9": "10", "0": "11",
            "-": "12", "=": "13", "[": "26", "]": "27", ";": "39",
            "'": "40", "`": "41", "\\": "43", ",": "51", ".": "52", "/": "53"
        };
        return letters[c] || null;
    }

    function getShiftedChar(c) {
        const map = {
            "`": "~", "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
            "6": "^", "7": "&", "8": "*", "9": "(", "0": ")", "-": "_",
            "=": "+", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"",
            ",": "<", ".": ">", "/": "?"
        };
        return map[c] ? map[c] : c.toUpperCase();
    }

    // Purely internal toggle: avoids sending global keydown to the system
    function toggleSuper() {
        root.superHeld = !root.superHeld;
    }

    // Toggle Ctrl (Keycode 29)
    function toggleCtrl() {
        root.ctrlHeld = !root.ctrlHeld;
        if (root.ctrlHeld) {
            Quickshell.execDetached(["ydotool", "key", "29:1"]);
        } else {
            Quickshell.execDetached(["ydotool", "key", "29:0"]);
        }
    }

    // Toggle Alt (Keycode 56)
    function toggleAlt() {
        root.altHeld = !root.altHeld;
        if (root.altHeld) {
            Quickshell.execDetached(["ydotool", "key", "56:1"]);
        } else {
            Quickshell.execDetached(["ydotool", "key", "56:0"]);
        }
    }

    // Toggle Shift (Keycode 42)
    function toggleShift() {
        root.shiftHeld = !root.shiftHeld;
        if (root.shiftHeld) {
            Quickshell.execDetached(["ydotool", "key", "42:1"]);
        } else {
            Quickshell.execDetached(["ydotool", "key", "42:0"]);
        }
    }

    function resetModifiers() {
        if (root.ctrlHeld)  Quickshell.execDetached(["ydotool", "key", "29:0"]);
        if (root.altHeld)   Quickshell.execDetached(["ydotool", "key", "56:0"]);
        if (root.shiftHeld) Quickshell.execDetached(["ydotool", "key", "42:0"]);

        shiftHeld = false;
        ctrlHeld = false;
        superHeld = false;
        altHeld = false;
    }

    function emitKey(char, specialName) {
        let isSuperActive = root.superHeld;

        // Special keys (Return, Tab, Arrows, Space, BackSpace, etc.)
        if (specialName && root.keyCodes[specialName]) {
            let code = root.keyCodes[specialName];

            if (isSuperActive) {
                // Burst: Press Super -> Press Key -> Release Key -> Release Super
                Quickshell.execDetached(["ydotool", "key", "125:1", `${code}:1`, `${code}:0`, "125:0"]);
                root.superHeld = false;
            } else {
                Quickshell.execDetached(["ydotool", "key", `${code}:1`, `${code}:0`]);
            }
            return;
        }

        // Alphanumeric keys (letters, numbers, symbols)
        if (char && char.length > 0) {
            let code = root.getAlphaKeyCode(char.toLowerCase());

            if (isSuperActive && code) {
                // Burst combo with Super
                Quickshell.execDetached(["ydotool", "key", "125:1", `${code}:1`, `${code}:0`, "125:0"]);
                root.superHeld = false;
                return;
            }

            if (root.ctrlHeld || root.altHeld) {
                if (code) {
                    Quickshell.execDetached(["ydotool", "key", `${code}:1`, `${code}:0`]);
                    return;
                }
            }

            // Normal typing
            let outChar = char;
            if (root.shiftHeld && char.length === 1) {
                outChar = root.getShiftedChar(char);
                root.toggleShift();
            }
            Quickshell.execDetached(["ydotool", "type", outChar]);
        }
    }
}
