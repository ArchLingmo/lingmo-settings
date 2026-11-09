/*
 * Copyright (C) 2021 LingmoOS Team.
 *
 * Author:     Kate Leet <lingmoos@foxmail.com>
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

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import LingmoUI.CompatibleModule 3.0 as LingmoUI

import Lingmo.Settings 1.0
import "../"

ItemPage {
    headerTitle: qsTr("Default Applications")

    DefaultApplications {
        id: defaultApps
    }

    Scrollable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight

        ColumnLayout {
            id: layout
            anchors.fill: parent

            RoundedItem {
                GridLayout {
                    columns: 2
                    columnSpacing: LingmoUI.Units.largeSpacing * 2

                    // One row per kind of thing: web links, e-mail, folders, the
                    // terminal, documents, pictures, videos... (only kinds some
                    // installed app opens)
                    Repeater {
                        model: defaultApps.categories

                        delegate: Label {
                            required property var modelData
                            required property int index
                            text: modelData.title
                            Layout.row: index
                            Layout.column: 0
                        }
                    }

                    Repeater {
                        model: defaultApps.categories

                        delegate: AppComboBox {
                            required property var modelData
                            required property int index
                            Layout.row: index
                            Layout.column: 1
                            Layout.fillWidth: true
                            textRole: "name"
                            model: modelData.apps
                            currentIndex: modelData.current
                            onActivated: defaultApps.setDefault(modelData.id, currentIndex)
                        }
                    }
                }
            }
        }
    }
}
