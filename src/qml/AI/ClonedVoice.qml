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

// Settings › IA › "Cloned voice": which engine speaks with a cloned voice in every
// Lingmo app (live translation, Voice Studio, Studio, podcasts, Tutor). One choice
// for the whole system, kept in ~/.config/lingmoos/voice.conf by VoiceEngineModule.
RoundedItem {
    id: card

    // what the apps really use: OmniVoice only while Voice Studio has it on
    readonly property string inUse: VoiceEngineModule.cloneEngine === "omnivoice" && VoiceEngineModule.omniVoiceReady ? "omnivoice" : "chatterbox"
    readonly property var engines: [
        { id: "chatterbox", name: "Chatterbox", detail: qsTr("Free for commercial use"), enabled: true },
        { id: "omnivoice", name: "OmniVoice", detail: qsTr("More faithful and faster · personal, non-commercial use only"),
          enabled: VoiceEngineModule.omniVoiceReady }
    ]

    Connections {
        target: rootWindow
        function onActiveChanged() {
            if (rootWindow.active)
                VoiceEngineModule.refresh()
        }
    }

    Label {
        text: qsTr("Cloned voice")
        font.pointSize: LingmoUI.Units.fontSubheading
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("The engine that speaks with a voice cloned from a recording, in every app: live translation, Voice Studio, Studio, podcasts and the Tutor.")
    }

    Repeater {
        model: card.engines

        RowLayout {
            required property var modelData
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true

            RadioButton {
                checked: card.inUse === modelData.id
                enabled: modelData.enabled
                Layout.alignment: Qt.AlignVCenter
                onClicked: VoiceEngineModule.setCloneEngine(modelData.id)
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                TapHandler {
                    enabled: modelData.enabled
                    onTapped: VoiceEngineModule.setCloneEngine(modelData.id)
                }

                Label {
                    // the engine that suits this computer (hardware.conf) is always marked
                    text: modelData.name + (VoiceEngineModule.recommendedEngine === modelData.id ? " " + qsTr("(recommended)") : "")
                    color: modelData.enabled ? LingmoUI.Theme.textColor : LingmoUI.Theme.disabledTextColor
                    Layout.fillWidth: true
                }

                Label {
                    text: modelData.detail
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // OmniVoice is turned on (licence and download) in Voice Studio, never here
            LingmoUI.ActionButton {
                visible: modelData.id === "omnivoice" && !VoiceEngineModule.omniVoiceReady
                text: qsTr("Turn on in Voice Studio")
                flat: true
                enabled: VoiceEngineModule.voiceStudioInstalled
                tipText: VoiceEngineModule.voiceStudioInstalled ? "" : qsTr("Install lingmo-voicestudio to use OmniVoice.")
                onClicked: VoiceEngineModule.openVoiceStudioEngines()
            }
        }
    }

    Label {
        visible: VoiceEngineModule.cloneEngine === "omnivoice" && !VoiceEngineModule.omniVoiceReady
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: LingmoUI.Theme.secondaryTextColor
        font.pointSize: LingmoUI.Units.fontCaption
        text: VoiceEngineModule.chosen
              ? qsTr("OmniVoice is chosen but not turned on in Voice Studio: the apps use Chatterbox meanwhile.")
              : qsTr("OmniVoice suits this computer best (it fits beside the most accurate speech recognition). Turn it on in Voice Studio; the apps use Chatterbox meanwhile.")
    }

    // a cloned voice on the processor (no CUDA graphics card, or too little video memory)
    Label {
        visible: !VoiceEngineModule.cloneRecommended
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: LingmoUI.Theme.orangeColor
        font.pointSize: LingmoUI.Units.fontCaption
        text: VoiceEngineModule.cloneOnGpu
              ? qsTr("On this computer a cloned voice barely fits in the video memory: piper voices are recommended for live translation.")
              : qsTr("On this computer a cloned voice runs on the processor, several seconds per sentence: piper voices are recommended for live translation.")
    }

    RowLayout {
        visible: VoiceEngineModule.chosen && VoiceEngineModule.cloneEngine !== VoiceEngineModule.recommendedEngine
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: LingmoUI.Theme.secondaryTextColor
            font.pointSize: LingmoUI.Units.fontCaption
            text: qsTr("You chose an engine other than the one recommended for this computer.")
        }
        LingmoUI.ActionButton {
            text: qsTr("Use recommended")
            flat: true
            onClicked: VoiceEngineModule.useRecommended()
        }
    }
}
