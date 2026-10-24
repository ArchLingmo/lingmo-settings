/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "../"

// Phone and devices: the page comes from Lingmo Share (Lingmo.Share QML module,
// package lingmo-share), so it follows the app; without it, say how to get it
ItemPage {
    headerTitle: qsTr("Phone and devices")

    Scrollable {
        anchors.fill: parent
        contentHeight: loader.height + LingmoUI.Units.largeSpacing * 2

        Loader {
            id: loader
            width: parent.width
            height: item ? item.implicitHeight : 0
            source: "SharePage.qml"
            onStatusChanged: if (status === Loader.Error) sourceComponent = missing
        }
    }

    Component {
        id: missing
        LingmoUI.EmptyState {
            implicitHeight: 320
            iconName: "smartphone"
            title: qsTr("Phone and devices is not installed")
            text: qsTr("Install the lingmo-share package to connect phones and send files to nearby devices.")
        }
    }
}
