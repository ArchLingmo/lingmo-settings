/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import Lingmo.Settings 1.0
import "../"

// Shared Keyboard and Mouse: one keyboard and mouse for computers side by
// side (Deskflow, run by lingmo-continuityd). This PC is the principal (its
// keyboard and mouse are shared) or a secundário (it uses another's).
ItemPage {
    id: page
    headerTitle: qsTr("Shared Keyboard and Mouse")

    readonly property var st: ContinuityModule.state
    readonly property bool on: !!st.enabled
    readonly property bool principal: st.role !== "client"
    readonly property var peers: st.peers || []
    readonly property var options: st.options || ({})
    readonly property var pairing: st.pairing || ({})
    readonly property var firewall: st.firewall || ({})
    readonly property var paired: peers.filter(p => p.paired)
    readonly property var others: peers.filter(p => !p.paired)
    readonly property var principals: paired.filter(p => p.role === "server" || p.os === "other")
    readonly property string address: (st.addresses || []).join(", ")

    Component.onCompleted: ContinuityModule.refresh()

    // Look for Lingmo PCs while the page is open (a query, answered right away)
    Timer {
        interval: 15000
        repeat: true
        running: page.on && page.visible
        triggeredOnStart: true
        onTriggered: ContinuityModule.discover()
    }

    function statusText() {
        switch (st.status) {
        case "off": return qsTr("Off")
        case "starting": return qsTr("Starting…")
        case "waiting": return qsTr("Ready: waiting for the other computers")
        case "connected":
            return principal ? qsTr("Sharing with %1").arg(st.connectedTo)
                             : qsTr("Using the keyboard and mouse of %1").arg(st.connectedTo)
        case "connecting": {
            const s = paired.find(p => p.isServer)
            return qsTr("Connecting to %1…").arg(s ? s.label : "")
        }
        case "noserver": return qsTr("Pair with a principal computer to use its keyboard and mouse")
        case "nodeskflow": return qsTr("Deskflow isn't installed")
        case "portinuse": return qsTr("Port %1 is used by another program").arg(st.ports ? st.ports.deskflow : 24800)
        case "error": return qsTr("Couldn't create this computer's certificate")
        }
        return ""
    }

    function statusColor() {
        switch (st.status) {
        case "connected": return LingmoUI.Theme.greenColor
        case "waiting": case "connecting": case "starting": return LingmoUI.Theme.orangeColor
        case "off": return LingmoUI.Theme.disabledTextColor
        }
        return LingmoUI.Theme.redColor
    }

    function peerText(p) {
        if (pairing.state === "waiting" && pairing.key === p.key)
            return p.os === "other" ? qsTr("Waiting for it to connect with Deskflow…") : qsTr("Waiting for confirmation…")
        if (p.connected)
            return qsTr("Connected")
        if (p.paired)
            return p.online || p.os === "other" ? qsTr("Paired") : qsTr("Paired · not on the network now")
        if (p.os === "other")
            return qsTr("Added by hand · Deskflow, Synergy or Input Leap")
        return qsTr("On the network")
    }

    // The layout: this PC plus every paired one
    readonly property var layoutComputers: {
        const s = st.self || ({ x: 0, y: 0, w: 1920, h: 1080, screens: [[0, 0, 1920, 1080]] })
        const list = [{ key: "self", label: st.label || "", x: s.x, y: s.y, w: s.w, h: s.h, screens: s.screens,
                        self: true, connected: true, online: true, active: !!s.active && paired.length > 0 }]
        for (const p of paired) {
            if (!p.placed)
                continue
            list.push({ key: p.key, label: p.label, x: p.x, y: p.y, w: p.w, h: p.h,
                        screens: p.screens.length > 0 ? p.screens : [[0, 0, p.w, p.h]],
                        self: false, connected: p.connected, online: p.online || p.connected, active: p.active })
        }
        return list
    }

    // Computers that touch no other one can't be reached with the mouse
    readonly property var isolated: {
        const out = []
        const cs = layoutComputers
        for (let i = 0; i < cs.length && cs.length > 1; ++i) {
            const a = cs[i]
            let touches = false
            for (let j = 0; j < cs.length && !touches; ++j) {
                if (i === j)
                    continue
                const b = cs[j]
                const t = 8
                const vOverlap = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) > 4
                const hOverlap = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) > 4
                touches = (vOverlap && (Math.abs(a.x + a.w - b.x) <= t || Math.abs(b.x + b.w - a.x) <= t))
                       || (hOverlap && (Math.abs(a.y + a.h - b.y) <= t || Math.abs(b.y + b.h - a.y) <= t))
            }
            if (!touches)
                out.push(a.label)
        }
        return out
    }

    component OptionRow: RowLayout {
        id: optionRow
        property string title
        property string text
        default property alias control: holder.data
        spacing: LingmoUI.Units.largeSpacing
        Layout.fillWidth: true

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Label {
                text: optionRow.title
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                visible: optionRow.text.length > 0
                text: optionRow.text
                color: LingmoUI.Theme.secondaryTextColor
                font.pointSize: LingmoUI.Theme.fontSize * 0.92
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item {
            id: holder
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    component SectionTitle: Label {
        font.pointSize: LingmoUI.Units.fontSubheading
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }

    Scrollable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight

        ColumnLayout {
            id: layout
            anchors.fill: parent
            spacing: LingmoUI.Units.largeSpacing * 2

            // ---------------------------------------------------------- Not installed
            RoundedItem {
                visible: !ContinuityModule.installed

                LingmoUI.EmptyState {
                    Layout.fillWidth: true
                    Layout.topMargin: LingmoUI.Units.largeSpacing
                    Layout.bottomMargin: LingmoUI.Units.largeSpacing
                    iconName: "input-mouse"
                    iconSize: LingmoUI.Units.iconSizes.large
                    text: qsTr("Install the lingmo-continuity package to use one keyboard and mouse across your computers.")
                }
            }

            // ---------------------------------------------------------- On / off
            RoundedItem {
                visible: ContinuityModule.installed

                RowLayout {
                    spacing: LingmoUI.Units.largeSpacing * 1.5
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.preferredWidth: LingmoUI.Units.iconSizes.large
                        Layout.preferredHeight: LingmoUI.Units.iconSizes.large
                        Layout.alignment: Qt.AlignTop
                        radius: LingmoUI.Theme.bigRadius
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#5AC8FA" }
                            GradientStop { position: 1; color: "#007AFF" }
                        }

                        LingmoUI.IconItem {
                            anchors.centerIn: parent
                            width: parent.width * 0.58
                            height: width
                            source: "input-mouse"
                            color: "white"
                        }
                    }

                    ColumnLayout {
                        spacing: LingmoUI.Units.smallSpacing
                        Layout.fillWidth: true

                        Label {
                            text: qsTr("One keyboard and mouse for all your computers")
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Label {
                            text: qsTr("Move the cursor past the edge of the screen and it goes on to the computer next to this one, with the same keyboard. Copy on one, paste on the other; drag files across to send them.")
                            color: LingmoUI.Theme.secondaryTextColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: LingmoUI.Units.smallSpacing
                            visible: ContinuityModule.ready
                            Layout.topMargin: LingmoUI.Units.smallSpacing

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: page.statusColor()
                            }

                            Label {
                                text: page.statusText()
                                color: LingmoUI.Theme.secondaryTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Switch {
                        Layout.alignment: Qt.AlignTop
                        checked: page.on
                        enabled: ContinuityModule.ready
                        onToggled: ContinuityModule.setEnabled(checked)
                    }
                }

                Label {
                    visible: ContinuityModule.ready && !(st.deskflow && st.deskflow.available)
                    text: qsTr("Deskflow, which moves the keyboard and mouse between computers, isn't installed (package deskflow).")
                    color: LingmoUI.Theme.orangeColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // ---------------------------------------------------------- This computer
            RoundedItem {
                visible: ContinuityModule.installed && page.on

                SectionTitle { text: qsTr("This computer") }

                OptionRow {
                    title: qsTr("Name")
                    text: qsTr("How the other computers show this one.")

                    TextField {
                        id: nameField
                        width: 220
                        text: st.label || ""
                        selectByMouse: true
                        onEditingFinished: if (text.trim().length > 0 && text !== st.label) ContinuityModule.setLabel(text)
                    }
                }

                HorizontalDivider {}

                Label {
                    text: qsTr("This computer is the")
                    Layout.fillWidth: true
                }

                LingmoUI.SegmentedControl {
                    fillWidth: true
                    Layout.fillWidth: true
                    model: [qsTr("Principal"), qsTr("Secondary")]
                    Binding on currentIndex { value: page.principal ? 0 : 1 }
                    onActivated: (index) => ContinuityModule.setRole(index === 0 ? "server" : "client")
                }

                Label {
                    text: page.principal
                          ? qsTr("Its keyboard and mouse are shared: the other computers follow it.")
                          : qsTr("It uses the keyboard and mouse of a principal computer. Arrange the computers on the principal.")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                OptionRow {
                    visible: !page.principal && page.principals.length > 1
                    title: qsTr("Principal computer")

                    ComboBox {
                        width: 220
                        model: page.principals.map(p => p.label)
                        currentIndex: Math.max(0, page.principals.findIndex(p => p.isServer))
                        onActivated: (index) => ContinuityModule.setServer(page.principals[index].key)
                    }
                }
            }

            // ---------------------------------------------------------- Layout
            RoundedItem {
                visible: ContinuityModule.installed && page.on

                SectionTitle { text: qsTr("Arrangement") }

                ContinuityLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230
                    visible: page.principal || page.paired.length === 0
                    computers: page.layoutComputers
                    editable: page.principal
                    onMoved: (key, x, y) => ContinuityModule.setPosition(key, x, y)
                }

                Label {
                    visible: page.principal
                    text: page.paired.length === 0
                          ? qsTr("Pair a computer below and drag it to the side where it sits on your desk.")
                          : qsTr("Drag the computers to match how they sit on your desk. The cursor crosses where their edges touch.")
                    color: LingmoUI.Theme.secondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Label {
                    visible: page.principal && page.isolated.length > 0
                    text: qsTr("%1 doesn't touch any other computer, so the cursor can't get there.").arg(page.isolated.join(", "))
                    color: LingmoUI.Theme.orangeColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Label {
                    visible: !page.principal && page.paired.length > 0
                    text: qsTr("The arrangement is set on the principal computer.")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // ---------------------------------------------------------- Computers
            RoundedItem {
                visible: ContinuityModule.installed && page.on

                RowLayout {
                    Layout.fillWidth: true

                    SectionTitle { text: qsTr("Computers") }

                    Button {
                        text: qsTr("Look Again")
                        flat: true
                        onClicked: ContinuityModule.discover()
                    }
                }

                Label {
                    visible: page.peers.length === 0
                    text: qsTr("Looking for Lingmo computers on this network… On the other computer, turn on Shared Keyboard and Mouse too.")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Repeater {
                    model: page.paired.concat(page.others)

                    ColumnLayout {
                        id: peerItem
                        required property var modelData
                        required property int index
                        readonly property var p: modelData
                        spacing: LingmoUI.Units.largeSpacing
                        Layout.fillWidth: true

                        HorizontalDivider { visible: peerItem.index > 0 }

                        RowLayout {
                            spacing: LingmoUI.Units.largeSpacing
                            Layout.fillWidth: true

                            Item {
                                Layout.preferredWidth: LingmoUI.Units.iconSizes.medium
                                Layout.preferredHeight: LingmoUI.Units.iconSizes.medium

                                LingmoUI.IconItem {
                                    anchors.fill: parent
                                    source: peerItem.p.os === "other" ? "computer" : "computer-laptop"
                                }

                                Rectangle {
                                    visible: peerItem.p.paired
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: 10
                                    height: 10
                                    radius: 5
                                    border.width: 2
                                    border.color: LingmoUI.Theme.secondBackgroundColor
                                    color: peerItem.p.connected ? LingmoUI.Theme.greenColor
                                         : peerItem.p.online ? LingmoUI.Theme.orangeColor : LingmoUI.Theme.disabledTextColor
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Label {
                                    text: peerItem.p.label
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: page.peerText(peerItem.p)
                                          + (peerItem.p.host ? " · " + peerItem.p.host : "")
                                          + (peerItem.p.paired && peerItem.p.os === "lingmo"
                                             ? " · " + (peerItem.p.role === "server" ? qsTr("principal") : qsTr("secondary")) : "")
                                    color: LingmoUI.Theme.secondaryTextColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            LingmoUI.Spinner {
                                visible: page.pairing.key === peerItem.p.key && !!page.pairing.state
                                running: visible
                                size: 20
                            }

                            LingmoUI.ActionButton {
                                visible: !peerItem.p.paired && !(page.pairing.key === peerItem.p.key && page.pairing.state)
                                text: qsTr("Pair…")
                                primary: true
                                onClicked: ContinuityModule.pair(peerItem.p.key)
                            }

                            Button {
                                visible: page.pairing.key === peerItem.p.key && !!page.pairing.state
                                text: qsTr("Cancel")
                                onClicked: ContinuityModule.cancelPairing()
                            }

                            Button {
                                visible: !peerItem.p.paired && peerItem.p.os === "other"
                                text: qsTr("Remove")
                                flat: true
                                onClicked: ContinuityModule.removePeer(peerItem.p.key)
                            }

                            Button {
                                visible: peerItem.p.paired
                                text: qsTr("Unpair…")
                                onClicked: {
                                    unpairDialog.key = peerItem.p.key
                                    unpairDialog.label = peerItem.p.label
                                    unpairDialog.open()
                                }
                            }
                        }

                        // A PC with Deskflow on another OS: what to do there
                        Label {
                            visible: peerItem.p.os === "other" && !peerItem.p.paired
                            text: page.principal
                                  ? qsTr("On %1, open Deskflow (or Synergy, Input Leap), choose “Use another computer's keyboard and mouse” (client), enter %2 and turn TLS on. When it connects, this computer asks you to confirm its fingerprint.").arg(peerItem.p.label).arg(page.address || qsTr("this computer's address"))
                                  : qsTr("On %1, open Deskflow (or Synergy, Input Leap) as the server, add this computer as “%2” and turn TLS on. Then pair: this computer asks you to confirm its fingerprint.").arg(peerItem.p.label).arg(st.name || "")
                            color: LingmoUI.Theme.secondaryTextColor
                            font.pointSize: LingmoUI.Theme.fontSize * 0.92
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: LingmoUI.Units.iconSizes.medium + LingmoUI.Units.largeSpacing
                        }
                    }
                }

                HorizontalDivider {}

                RowLayout {
                    spacing: LingmoUI.Units.largeSpacing
                    Layout.fillWidth: true

                    TextField {
                        id: addField
                        placeholderText: qsTr("Name or IP address of another computer")
                        selectByMouse: true
                        Layout.fillWidth: true
                        onAccepted: addButton.clicked()
                    }

                    Button {
                        id: addButton
                        text: qsTr("Add")
                        enabled: addField.text.trim().length > 0
                        onClicked: {
                            ContinuityModule.addPeer(addField.text)
                            addField.text = ""
                        }
                    }
                }

                Label {
                    text: qsTr("Computers with Windows, macOS or another Linux work too, with Deskflow, Synergy or Input Leap.")
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Theme.fontSize * 0.92
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // ---------------------------------------------------------- Options
            RoundedItem {
                visible: ContinuityModule.installed && page.on

                SectionTitle { text: qsTr("Options") }

                Label {
                    visible: !page.principal
                    text: qsTr("These options are set on the principal computer.")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                OptionRow {
                    enabled: page.principal
                    title: qsTr("Shared clipboard")
                    text: qsTr("Copy on one computer and paste on another.")

                    Switch {
                        checked: !!page.options.clipboard
                        onToggled: ContinuityModule.setOption("clipboard", checked)
                    }
                }

                HorizontalDivider {}

                OptionRow {
                    enabled: page.principal
                    title: qsTr("Crossing to the other computer")
                    text: page.options.switchMode === "delay"
                          ? qsTr("The cursor has to rest on the edge for a moment.")
                          : page.options.switchMode === "doubletap"
                            ? qsTr("Tap the edge twice quickly to cross.")
                            : qsTr("As soon as the cursor reaches the edge.")

                    ComboBox {
                        width: 220
                        model: [qsTr("Right away"), qsTr("After a pause at the edge"), qsTr("Double tap on the edge")]
                        currentIndex: Math.max(0, ["immediate", "delay", "doubletap"].indexOf(page.options.switchMode))
                        onActivated: (index) => ContinuityModule.setOption("switchMode", ["immediate", "delay", "doubletap"][index])
                    }
                }

                OptionRow {
                    visible: page.options.switchMode === "delay" || page.options.switchMode === "doubletap"
                    enabled: page.principal
                    title: page.options.switchMode === "delay" ? qsTr("Pause") : qsTr("Time between taps")
                    text: qsTr("%1 ms").arg(slider.value)

                    Slider {
                        id: slider
                        width: 220
                        from: 100
                        to: 1000
                        stepSize: 50
                        value: page.options.switchMode === "delay" ? (page.options.switchDelay || 250) : (page.options.doubleTap || 250)
                        onPressedChanged: if (!pressed) ContinuityModule.setOption(page.options.switchMode === "delay" ? "switchDelay" : "doubleTap", value)
                    }
                }

                HorizontalDivider {}

                OptionRow {
                    enabled: page.principal
                    title: qsTr("Keep the cursor on one computer")
                    text: qsTr("Press it to stop (and start again) crossing edges, e.g. in games.")

                    ComboBox {
                        width: 220
                        readonly property var keys: ["ScrollLock", "control+alt+L", "super+alt+L", ""]
                        model: [qsTr("Scroll Lock"), "Ctrl+Alt+L", "Super+Alt+L", qsTr("None")]
                        currentIndex: Math.max(0, keys.indexOf(page.options.lockHotkey))
                        onActivated: (index) => ContinuityModule.setOption("lockHotkey", keys[index])
                    }
                }

                OptionRow {
                    enabled: page.principal
                    title: qsTr("Go to the next computer")
                    text: qsTr("Moves the cursor to the next computer without reaching an edge.")

                    ComboBox {
                        width: 220
                        readonly property var keys: ["control+super+Right", "control+alt+Right", "super+alt+N", ""]
                        model: ["Ctrl+Super+→", "Ctrl+Alt+→", "Super+Alt+N", qsTr("None")]
                        currentIndex: Math.max(0, keys.indexOf(page.options.switchHotkey))
                        onActivated: (index) => ContinuityModule.setOption("switchHotkey", keys[index])
                    }
                }
            }

            // ---------------------------------------------------------- Security
            RoundedItem {
                visible: ContinuityModule.installed && page.on

                SectionTitle { text: qsTr("Security") }

                Label {
                    text: qsTr("Everything between the computers is encrypted (TLS), and only paired computers are let in: each one is known by its certificate, confirmed on both screens when pairing. When this is off, nothing listens on the network.")
                    color: LingmoUI.Theme.secondaryTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                OptionRow {
                    title: qsTr("This computer's fingerprint")
                    text: st.fingerprint || ""

                    Button {
                        text: qsTr("Copy")
                        flat: true
                        onClicked: ContinuityModule.copy(st.fingerprint)
                    }
                }

                ColumnLayout {
                    visible: !!page.firewall.name
                    spacing: LingmoUI.Units.smallSpacing
                    Layout.fillWidth: true

                    HorizontalDivider {}

                    Label {
                        text: qsTr("The firewall (%1) is on. For the other computers to reach this one, open %2. Nothing is changed without you:").arg(page.firewall.name).arg(page.firewall.ports)
                        color: LingmoUI.Theme.orangeColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: LingmoUI.Units.largeSpacing
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: commandLabel.implicitHeight + LingmoUI.Units.largeSpacing
                            radius: LingmoUI.Theme.smallRadius
                            color: LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)

                            Label {
                                id: commandLabel
                                anchors.fill: parent
                                anchors.margins: LingmoUI.Units.smallSpacing
                                verticalAlignment: Text.AlignVCenter
                                text: page.firewall.command || ""
                                font.family: "monospace"
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        Button {
                            text: qsTr("Copy")
                            onClicked: ContinuityModule.copy(page.firewall.command)
                        }
                    }
                }
            }

            Item {
                height: LingmoUI.Units.largeSpacing
            }
        }
    }

    Dialog {
        id: unpairDialog
        parent: Overlay.overlay
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        title: qsTr("Unpair %1?").arg(unpairDialog.label)

        property string key: ""
        property string label: ""

        ColumnLayout {
            spacing: LingmoUI.Units.largeSpacing * 1.5

            Label {
                text: qsTr("It stops sharing the keyboard and mouse right away and has to be paired again, with a new confirmation on both computers.")
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 340
            }

            RowLayout {
                spacing: LingmoUI.Units.largeSpacing

                Button {
                    text: qsTr("Cancel")
                    Layout.fillWidth: true
                    onClicked: unpairDialog.reject()
                }

                LingmoUI.ActionButton {
                    text: qsTr("Unpair")
                    destructive: true
                    Layout.fillWidth: true
                    onClicked: {
                        unpairDialog.accept()
                        ContinuityModule.unpair(unpairDialog.key)
                    }
                }
            }
        }
    }
}
