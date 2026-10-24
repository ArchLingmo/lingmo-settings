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

// The computers as they sit on the desk, each drawn with its own monitors.
// Drag one next to another: the edges that touch are where the cursor
// crosses (like Settings › Display does for monitors).
Item {
    id: arrangement

    // [{ key, label, x, y, w, h, screens: [[x,y,w,h]], self, connected, online, active }]
    property var computers: []
    property bool editable: true
    signal moved(string key, int x, int y)

    implicitHeight: 230

    readonly property rect bounds: {
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        for (let i = 0; i < computers.length; ++i) {
            const c = computers[i]
            x0 = Math.min(x0, c.x)
            y0 = Math.min(y0, c.y)
            x1 = Math.max(x1, c.x + c.w)
            y1 = Math.max(y1, c.y + c.h)
        }
        // Room around them to drag into
        if (x1 <= x0)
            return Qt.rect(0, 0, 1, 1)
        const padX = (x1 - x0) * 0.12, padY = (y1 - y0) * 0.12
        return Qt.rect(x0 - padX, y0 - padY, x1 - x0 + 2 * padX, y1 - y0 + 2 * padY)
    }
    readonly property real factor: Math.min(width / bounds.width, height / bounds.height)
    readonly property real offsetX: (width - bounds.width * factor) / 2
    readonly property real offsetY: (height - bounds.height * factor) / 2

    // Where a computer dropped with its top-left at (px, py) lands: touching
    // another one along an edge (aligned to its top/bottom or left/right, or
    // where it was dropped along that edge), never overlapping
    function snap(index, px, py) {
        const me = computers[index]
        const w = me.w, h = me.h
        const others = computers.filter((c, i) => i !== index)
        function overlaps(x, y) {
            for (const o of others) {
                if (x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y)
                    return true
            }
            return false
        }
        let best = null, bestDistance = Infinity
        for (const o of others) {
            // Slide along the edge, but keep at least a fifth of it shared
            const yAlong = Math.max(o.y - h * 0.8, Math.min(o.y + o.h - h * 0.2, py))
            const xAlong = Math.max(o.x - w * 0.8, Math.min(o.x + o.w - w * 0.2, px))
            const spots = [
                [o.x + o.w, o.y], [o.x + o.w, o.y + o.h - h], [o.x + o.w, yAlong],
                [o.x - w, o.y], [o.x - w, o.y + o.h - h], [o.x - w, yAlong],
                [o.x, o.y - h], [o.x + o.w - w, o.y - h], [xAlong, o.y - h],
                [o.x, o.y + o.h], [o.x + o.w - w, o.y + o.h], [xAlong, o.y + o.h]
            ]
            for (const s of spots) {
                const d = Math.hypot(s[0] - px, s[1] - py)
                if (d < bestDistance && !overlaps(s[0], s[1])) {
                    bestDistance = d
                    best = Qt.point(Math.round(s[0]), Math.round(s[1]))
                }
            }
        }
        return best
    }

    // Where two computers touch, the cursor crosses: a glowing seam there
    readonly property var seams: {
        const out = []
        const cs = computers
        for (let i = 0; i < cs.length; ++i) {
            for (let j = i + 1; j < cs.length; ++j) {
                const a = cs[i], b = cs[j]
                const y0 = Math.max(a.y, b.y), y1 = Math.min(a.y + a.h, b.y + b.h)
                const x0 = Math.max(a.x, b.x), x1 = Math.min(a.x + a.w, b.x + b.w)
                if (y1 - y0 > 4 && Math.abs(a.x + a.w - b.x) <= 8)
                    out.push({ vertical: true, at: b.x, from: y0, to: y1 })
                else if (y1 - y0 > 4 && Math.abs(b.x + b.w - a.x) <= 8)
                    out.push({ vertical: true, at: a.x, from: y0, to: y1 })
                else if (x1 - x0 > 4 && Math.abs(a.y + a.h - b.y) <= 8)
                    out.push({ vertical: false, at: b.y, from: x0, to: x1 })
                else if (x1 - x0 > 4 && Math.abs(b.y + b.h - a.y) <= 8)
                    out.push({ vertical: false, at: a.y, from: x0, to: x1 })
            }
        }
        return out
    }

    Repeater {
        model: arrangement.seams

        Rectangle {
            required property var modelData
            readonly property real f: arrangement.factor
            z: 3
            radius: 2
            color: LingmoUI.Theme.highlightColor
            opacity: 0.85
            x: modelData.vertical ? arrangement.offsetX + (modelData.at - arrangement.bounds.x) * f - 2
                                  : arrangement.offsetX + (modelData.from - arrangement.bounds.x) * f + 10
            y: modelData.vertical ? arrangement.offsetY + (modelData.from - arrangement.bounds.y) * f + 10
                                  : arrangement.offsetY + (modelData.at - arrangement.bounds.y) * f - 2
            width: modelData.vertical ? 4 : Math.max(0, (modelData.to - modelData.from) * f - 20)
            height: modelData.vertical ? Math.max(0, (modelData.to - modelData.from) * f - 20) : 4
        }
    }

    Repeater {
        id: repeater
        model: arrangement.computers

        delegate: Rectangle {
            id: box
            required property var modelData
            required property int index
            readonly property var c: modelData

            property real dragX: 0
            property real dragY: 0
            z: mouseArea.pressed ? 2 : (c.self ? 1 : 0)

            x: arrangement.offsetX + (c.x - arrangement.bounds.x) * arrangement.factor + 3 + dragX
            y: arrangement.offsetY + (c.y - arrangement.bounds.y) * arrangement.factor + 3 + dragY
            width: c.w * arrangement.factor - 6
            height: c.h * arrangement.factor - 6
            radius: LingmoUI.Theme.mediumRadius
            opacity: c.self || c.online ? 1 : 0.55
            color: LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035)
            border.width: c.active ? 2 : 1
            border.color: c.active ? LingmoUI.Theme.highlightColor
                                   : (LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14))

            Behavior on opacity { NumberAnimation { duration: LingmoUI.Units.shortDuration } }

            // Its monitors
            Repeater {
                model: box.c.screens

                Rectangle {
                    required property var modelData
                    readonly property real sx0: {
                        let m = Infinity
                        for (const s of box.c.screens) m = Math.min(m, s[0])
                        return m
                    }
                    readonly property real sy0: {
                        let m = Infinity
                        for (const s of box.c.screens) m = Math.min(m, s[1])
                        return m
                    }
                    readonly property real f: Math.min((box.width - 8) / box.c.w, (box.height - 8) / box.c.h)
                    x: 4 + (modelData[0] - sx0) * f + 1
                    y: 4 + (modelData[1] - sy0) * f + 1
                    width: modelData[2] * f - 2
                    height: modelData[3] * f - 2
                    radius: LingmoUI.Theme.smallRadius
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: box.c.self ? Qt.lighter(LingmoUI.Theme.highlightColor, 1.25) : (LingmoUI.Theme.darkMode ? "#4b5563" : "#cfd8e3")
                        }
                        GradientStop {
                            position: 1
                            color: box.c.self ? LingmoUI.Theme.highlightColor : (LingmoUI.Theme.darkMode ? "#374151" : "#b4c0cf")
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - LingmoUI.Units.largeSpacing
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: box.c.label
                    font.bold: true
                    color: box.c.self ? "white" : LingmoUI.Theme.textColor
                    style: box.c.self ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.25)
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Rectangle {
                        visible: !box.c.self
                        width: 7
                        height: 7
                        radius: 3.5
                        color: box.c.connected ? LingmoUI.Theme.greenColor
                             : box.c.online ? LingmoUI.Theme.orangeColor : LingmoUI.Theme.disabledTextColor
                    }

                    Label {
                        text: box.c.self ? qsTr("This computer")
                              : box.c.connected ? qsTr("Connected")
                              : box.c.online ? qsTr("Not connected") : qsTr("Offline")
                        font.pointSize: LingmoUI.Units.fontCaption
                        color: box.c.self ? Qt.rgba(1, 1, 1, 0.9) : LingmoUI.Theme.secondaryTextColor
                        elide: Text.ElideRight
                        Layout.maximumWidth: box.width - 28
                    }
                }
            }

            // Where the cursor is now
            Rectangle {
                visible: box.c.active && arrangement.computers.length > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                width: 18
                height: 18
                radius: 9
                color: LingmoUI.Theme.highlightColor

                LingmoUI.IconItem {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    source: "input-mouse-symbolic"
                    color: "white"
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                enabled: arrangement.editable && arrangement.computers.length > 1
                cursorShape: !enabled ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                // The page scrolls: don't let it take the drag away
                preventStealing: true
                property point start

                onCanceled: {
                    box.dragX = 0
                    box.dragY = 0
                }

                onPressed: (mouse) => start = mapToItem(arrangement, mouse.x, mouse.y)
                onPositionChanged: (mouse) => {
                    const p = mapToItem(arrangement, mouse.x, mouse.y)
                    const baseX = box.x - box.dragX, baseY = box.y - box.dragY
                    box.dragX = Math.max(-baseX, Math.min(arrangement.width - box.width - baseX, p.x - start.x))
                    box.dragY = Math.max(-baseY, Math.min(arrangement.height - box.height - baseY, p.y - start.y))
                }
                onReleased: {
                    const moved = Math.abs(box.dragX) + Math.abs(box.dragY) > 4
                    const px = box.c.x + box.dragX / arrangement.factor
                    const py = box.c.y + box.dragY / arrangement.factor
                    box.dragX = 0
                    box.dragY = 0
                    if (!moved)
                        return
                    const spot = arrangement.snap(box.index, px, py)
                    if (spot && (spot.x !== box.c.x || spot.y !== box.c.y))
                        arrangement.moved(box.c.key, spot.x, spot.y)
                }
            }
        }
    }
}
