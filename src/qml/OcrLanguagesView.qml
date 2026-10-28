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
import Lingmo.Settings 1.0 as Settings

// Language › Reading languages: the OCR packs (tesseract-data-*) used by
// "Ask about the screen" and Copy text in Screenshots. Nothing ships with the
// system but Portuguese and English: the rest is downloaded here, when wanted.
ColumnLayout {
    id: view

    readonly property var langs: Settings.OcrLanguages

    signal back()

    spacing: LingmoUI.Units.largeSpacing

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
        Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
        Layout.topMargin: LingmoUI.Units.largeSpacing
        spacing: LingmoUI.Units.largeSpacing

        LingmoUI.IconButton {
            iconColor: LingmoUI.Theme.textColor
            size: 32; iconSize: 18
            iconName: "go-previous"
            tipText: qsTr("Back to Language")
            onClicked: view.back()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: qsTr("Reading languages (OCR)")
                font.pointSize: LingmoUI.Units.fontSubheading
                font.bold: true
                color: LingmoUI.Theme.textColor
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: LingmoUI.Theme.secondaryTextColor
                font.pointSize: LingmoUI.Units.fontCaption
                text: qsTr("The languages Screenshots can read in an image (Copy text, Ask about the screen). The script of the text is detected on its own: install the languages you come across. Everything is read on this computer.")
            }
        }
    }

    LingmoUI.Banner {
        Layout.fillWidth: true
        Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
        Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
        visible: !view.langs.available
        closable: false
        type: LingmoUI.Banner.Warning
        title: qsTr("Screenshots is not installed")
        text: qsTr("Reading languages are managed by Lingmo Screenshots. Install it from the Store.")
    }

    TextField {
        id: search
        Layout.fillWidth: true
        Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
        Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
        visible: view.langs.available
        placeholderText: qsTr("Search languages")
        onTextChanged: view.langs.filter = text
    }

    ListView {
        id: list

        LingmoUI.WheelHandler { target: list }

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: view.langs.available
        clip: true
        model: view.langs
        leftMargin: LingmoUI.Units.largeSpacing * 2
        rightMargin: LingmoUI.Units.largeSpacing * 2
        spacing: 2

        ScrollBar.vertical: ScrollBar {}

        section.property: "group"
        section.criteria: ViewSection.FullString
        section.delegate: Label {
            required property string section
            width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
            topPadding: LingmoUI.Units.largeSpacing
            bottomPadding: LingmoUI.Units.smallSpacing
            text: section === "popular" ? qsTr("Most used") : qsTr("All languages")
            color: LingmoUI.Theme.secondaryTextColor
            font.pointSize: LingmoUI.Units.fontCaption
            font.bold: true
        }

        LingmoUI.Spinner {
            anchors.centerIn: parent
            size: 28
            running: view.langs.loading && list.count === 0
            visible: running
        }

        Label {
            anchors.centerIn: parent
            visible: !view.langs.loading && list.count === 0
            text: search.text.length > 0 ? qsTr("No language matches “%1”.").arg(search.text)
                                         : qsTr("The language list is not available. Check the internet connection and the package database.")
            color: LingmoUI.Theme.secondaryTextColor
            wrapMode: Text.Wrap
            width: list.width * 0.8
            horizontalAlignment: Text.AlignHCenter
        }

        delegate: MouseArea {
            id: row

            required property string code
            required property string name
            required property bool installed
            required property string size
            required property bool removable
            required property bool recommended
            required property bool selected

            // Installed and needed (Portuguese, English): nothing to choose
            readonly property bool locked: installed && !removable

            width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
            height: 44
            hoverEnabled: true
            enabled: !view.langs.busy
            cursorShape: locked ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!locked) view.langs.toggle(code)

            Rectangle {
                anchors.fill: parent
                radius: LingmoUI.Theme.smallRadius
                color: row.selected ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                                              LingmoUI.Theme.highlightColor.b, 0.12)
                     : row.containsMouse && !row.locked ? LingmoUI.Theme.hoverColor : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: LingmoUI.Units.smallSpacing
                anchors.rightMargin: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.largeSpacing

                CheckBox {
                    checked: row.selected || row.locked
                    enabled: !row.locked && !view.langs.busy
                    onClicked: view.langs.toggle(row.code)
                }

                Label {
                    text: row.name
                    color: LingmoUI.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: !recommendedBadge.visible
                }

                LingmoUI.Badge {
                    id: recommendedBadge
                    visible: row.recommended
                    text: qsTr("recommended")
                }

                Item { Layout.fillWidth: recommendedBadge.visible }

                Label {
                    text: row.locked ? qsTr("Installed · needed by the system")
                        : row.installed ? (row.selected ? qsTr("Will be removed") : qsTr("Installed"))
                        : row.selected ? qsTr("Will be installed")
                        : qsTr("Not installed")
                    color: row.installed && !row.selected ? LingmoUI.Theme.greenColor
                         : row.selected ? LingmoUI.Theme.highlightColor
                         : LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                }

                Label {
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                    text: row.size
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                }
            }
        }
    }

    // ------------------------------------------------ actions
    LingmoUI.Card {
        Layout.fillWidth: true
        Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
        Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
        Layout.bottomMargin: LingmoUI.Units.largeSpacing * 2
        visible: view.langs.available
        implicitHeight: actions.implicitHeight + LingmoUI.Units.largeSpacing * 2

        ColumnLayout {
            id: actions
            anchors.fill: parent
            anchors.margins: LingmoUI.Units.largeSpacing
            spacing: LingmoUI.Units.smallSpacing

            ProgressBar {
                Layout.fillWidth: true
                visible: view.langs.busy
                value: view.langs.progress
                indeterminate: view.langs.progress <= 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LingmoUI.Units.largeSpacing

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: LingmoUI.Theme.secondaryTextColor
                    text: view.langs.busy ? view.langs.busyText
                        : view.langs.toInstall + view.langs.toRemove === 0
                          ? qsTr("Select the languages to install or remove.")
                          : [view.langs.toInstall > 0 ? qsTr("%n to install (%1)", "", view.langs.toInstall).arg(view.langs.selectionSize) : "",
                             view.langs.toRemove > 0 ? qsTr("%n to remove", "", view.langs.toRemove) : ""]
                            .filter(function (s) { return s.length > 0 }).join(" · ")
                }

                LingmoUI.ActionButton {
                    text: qsTr("Remove")
                    visible: view.langs.toRemove > 0
                    enabled: !view.langs.busy
                    onClicked: view.langs.removeSelected()
                }

                LingmoUI.ActionButton {
                    text: qsTr("Install selected")
                    primary: true
                    enabled: view.langs.toInstall > 0 && !view.langs.busy
                    busy: view.langs.busy
                    onClicked: view.langs.installSelected()
                }
            }
        }
    }

    Connections {
        target: view.langs
        function onFinished(ok, message) {
            if (message.length > 0 && typeof rootWindow !== "undefined" && rootWindow.showPassiveNotification)
                rootWindow.showPassiveNotification(message, "long")
        }
    }

    Component.onCompleted: view.langs.refresh()
}
