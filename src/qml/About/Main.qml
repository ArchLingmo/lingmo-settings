import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Qt5Compat.GraphicalEffects

import Lingmo.System 1.0 as System
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import Lingmo.Settings 1.0
import "../"

ItemPage {
    id: control
    headerTitle: qsTr("About")

    About {
        id: about
        signal hostNameChanged(string newHostName)
    }

    System.Wallpaper {
        id: wallpaper
    }

    Scrollable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight

        ColumnLayout {
            id: layout
            anchors.fill: parent

            SysItem {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: LingmoUI.Units.largeSpacing * 2

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.largeSpacing
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 250
                            Layout.preferredHeight: 65
                            source: "qrc:/images/logo-2.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Rectangle {
                            visible: about.releaseInfo.pretty !== ""
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: badge.implicitWidth + 32
                            implicitHeight: 36
                            radius: 18
                            color: "#2779FF"
                            Label {
                                id: badge
                                anchors.centerIn: parent
                                text: about.releaseInfo.pretty.toLocaleUpperCase()
                                color: "white"
                                font.weight: Font.DemiBold
                                font.letterSpacing: 2
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            text: about.version
                            font.pointSize: LingmoUI.Units.fontTitle
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: about.releaseInfo.symbol !== ""
                            text: about.releaseInfo.symbol + " · " + about.releaseInfo.number
                            color: LingmoUI.Theme.secondaryTextColor
                            font.pointSize: LingmoUI.Units.fontSubheading
                        }
                        LingmoUI.ActionButton {
                            visible: about.releaseInfo.blog !== ""
                            text: qsTranslate("About", "What's new in this release")
                            onClicked: Qt.openUrlExternally(about.releaseInfo.blog)
                        }
                    }
                }
            }

            RoundedItem {
                id: lf
                PCname {
                    id: pcName
                    key: qsTr("PC Name")
                    value: about.hostName
                }

                Horizontalabt {}

                StandardItem {
                    key: qsTr("OS Version")
                    value: about.version
                }
            }

            Item {
                height: LingmoUI.Units.smallSpacing
            }

            RoundedItem {
                Repeater {
                    model: [
                        {label: qsTr("Linux Kernel Version"), value: about.kernelVersion},
                        {label: qsTr("System Type"), value: about.architecture},
                        {label: qsTr("RAM"), value: about.memorySize},
                        {label: qsTr("Disk"), value: about.internalStorage},
                        {label: qsTr("CPU"), value: about.cpuInfo}
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.largeSpacing
                        Label { text: modelData.label }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.value
                            color: LingmoUI.Theme.secondaryTextColor
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Item {
                height: LingmoUI.Units.smallSpacing
            }

            RoundedItem {
                
                LingmoUI.Card {
                    Layout.fillWidth: true
                    Layout.leftMargin: -LingmoUI.Units.smallSpacing * 1.5
                    Layout.rightMargin: -LingmoUI.Units.smallSpacing * 1.5
                    implicitHeight: LingmoUI.Units.controlHeight
                    clickable: true
                    borderEnabled: false
                    visible: about.checkForLingmoOS()
                    onClicked: {
                        about.openUpdator()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: LingmoUI.Units.smallSpacing * 1.5
                        anchors.rightMargin: LingmoUI.Units.smallSpacing * 1.5

                        Label {
                            text: qsTr("System Update")
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Label {
                            text: qsTr("→")
                            color: LingmoUI.Theme.secondaryTextColor
                        }
                    }
                }

                Horizontalabt {}

                StandardItem {
                    key: qsTr("Open Source Software Statement")
                }

            }

                    

            Item {
                height: LingmoUI.Units.smallSpacing
            }
        }
    }
}
