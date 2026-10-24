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
                        // The logo and wordmark stay an image; the release badge under the
                        // wordmark is drawn here from /etc/lingmo-release, in the place,
                        // shape and colour of the badge the SVG used to carry ("HELIUM")
                        Item {
                            id: logoBox
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 250
                            Layout.preferredHeight: 250 * 354 / 1364.06
                            // logo-2.svg units -> pixels
                            readonly property real unit: width / 1364.06

                            Image {
                                anchors.fill: parent
                                source: "qrc:/images/logo-2.svg"
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Rectangle {
                                id: codenameBadge
                                visible: about.releaseInfo.pretty !== ""
                                x: 464 * logoBox.unit
                                y: 233 * logoBox.unit
                                height: 121 * logoBox.unit
                                // At least the SVG's width; longer names grow to the right
                                width: Math.max(518 * logoBox.unit, badgeRow.implicitWidth + height * 1.1)
                                color: "#2779FF"
                                // Rounded corners but the bottom right, like the original badge
                                readonly property real corner: 34.3 * logoBox.unit
                                topLeftRadius: corner
                                topRightRadius: corner
                                bottomLeftRadius: corner
                                bottomRightRadius: 0

                                Row {
                                    id: badgeRow
                                    anchors.centerIn: parent
                                    spacing: codenameBadge.height * 0.32
                                    LayoutMirroring.enabled: false

                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: about.releaseInfo.pretty.toLocaleUpperCase()
                                        color: "#FFFFFF"
                                        // Room left for accents (SILÍCIO) inside the badge
                                        font.pixelSize: Math.round(codenameBadge.height * 0.6)
                                        font.weight: Font.Medium
                                        font.letterSpacing: font.pixelSize * 0.16
                                    }

                                    // The element, subtly: atomic number raised before the symbol
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: about.releaseInfo.symbol !== ""
                                        opacity: 0.72
                                        spacing: 1
                                        Label {
                                            text: about.releaseInfo.number
                                            color: "#FFFFFF"
                                            font.pixelSize: Math.round(codenameBadge.height * 0.3)
                                            font.weight: Font.Medium
                                        }
                                        Label {
                                            text: about.releaseInfo.symbol
                                            color: "#FFFFFF"
                                            font.pixelSize: Math.round(codenameBadge.height * 0.46)
                                            font.weight: Font.DemiBold
                                            topPadding: codenameBadge.height * 0.08
                                        }
                                    }
                                }
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
