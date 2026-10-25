import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Qt5Compat.GraphicalEffects


import LingmoUI.CompatibleModule 3.0 as LingmoUI

import Lingmo.Settings 1.0 as Settings

ItemPage {
    headerTitle: qsTr("Language")

    Settings.Language {
        id: language
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: LingmoUI.Units.smallSpacing

        LingmoUI.Banner {
            visible: language.needsRelogin
            type: LingmoUI.Banner.Info
            closable: false
            title: qsTr("Log out to finish changing the language")
            text: qsTr("Apps already open keep the previous language until you log out and back in. Save your work first.")
            Layout.fillWidth: true
            Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
            Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
            Layout.topMargin: LingmoUI.Units.largeSpacing

            LingmoUI.ActionButton {
                text: qsTr("Log out now")
                onClicked: language.logout()
            }
        }

        ListView {
            id: listView

            LingmoUI.WheelHandler {
                target: listView
            }

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: language.languages
            clip: true

            topMargin: LingmoUI.Units.largeSpacing
            leftMargin: LingmoUI.Units.largeSpacing * 2
            rightMargin: LingmoUI.Units.largeSpacing * 2
            bottomMargin: LingmoUI.Units.largeSpacing
            spacing: LingmoUI.Units.largeSpacing

            currentIndex: language.currentLanguage

            ScrollBar.vertical: ScrollBar {
                bottomPadding: LingmoUI.Theme.smallRadius
            }

            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            highlightResizeDuration : 0
            highlight: Rectangle {
                color: LingmoUI.Theme.highlightColor
                radius: LingmoUI.Theme.smallRadius
            }

            delegate: MouseArea {
                property bool isSelected: index == listView.currentIndex

                id: item
                width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                height: 36
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                onClicked: {
                    language.setCurrentLanguage(index)
                }

                Rectangle {
                    anchors.fill: parent
                    color: !isSelected && item.containsMouse ? LingmoUI.Theme.hoverColor : "transparent"
                    radius: LingmoUI.Theme.smallRadius

                    Behavior on color {
                        ColorAnimation { duration: LingmoUI.Units.veryShortDuration }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: LingmoUI.Units.smallSpacing
                    anchors.rightMargin: LingmoUI.Units.largeSpacing

                    Label {
                        color: isSelected ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
                        text: modelData
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Image {
                        width: item.height * 0.45
                        height: width
                        sourceSize: Qt.size(width, height)
                        source: "qrc:/images/dark/checked.svg"
                        visible: isSelected
                        smooth: false
                    }
                }
            }
        }

        // Personal folders follow the language (lingmo-userdirs)
        LingmoUI.Card {
            id: foldersCard
            Layout.fillWidth: true
            Layout.leftMargin: LingmoUI.Units.largeSpacing * 2
            Layout.rightMargin: LingmoUI.Units.largeSpacing * 2
            Layout.bottomMargin: LingmoUI.Units.largeSpacing * 2
            visible: language.userDirsAvailable

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: foldersCard.padding
                anchors.rightMargin: foldersCard.padding
                anchors.topMargin: LingmoUI.Units.largeSpacing
                anchors.bottomMargin: LingmoUI.Units.largeSpacing
                spacing: LingmoUI.Units.smallSpacing

                Label {
                    text: qsTr("Personal folders")
                    font.pointSize: LingmoUI.Units.fontSubheading
                    font.bold: true
                    color: LingmoUI.Theme.textColor
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    text: language.duplicateFolders > 0
                          ? qsTr("%n folder(s) exist twice, in different languages (for example Videos and Vídeos). Merging moves the files into one folder without overwriting anything.", "", language.duplicateFolders)
                          : qsTr("Documents, Music, Pictures and the other personal folders can use the names of the selected language. Files are moved, never deleted.")
                }

                RowLayout {
                    Layout.topMargin: LingmoUI.Units.smallSpacing
                    spacing: LingmoUI.Units.largeSpacing

                    LingmoUI.ActionButton {
                        text: qsTr("Rename folders…")
                        iconName: "folder"
                        onClicked: language.renameFolders()
                    }

                    LingmoUI.ActionButton {
                        visible: language.duplicateFolders > 0
                        primary: true
                        text: qsTr("Merge duplicate folders…")
                        iconName: "folder-copy"
                        onClicked: language.mergeDuplicateFolders()
                    }
                }
            }
        }
    }

    // The dialogs run apart from Settings: pick up their result
    Timer {
        interval: 4000
        repeat: true
        running: foldersCard.visible && Qt.application.state === Qt.ApplicationActive
        triggeredOnStart: true
        onTriggered: language.refreshDuplicateFolders()
    }
}
