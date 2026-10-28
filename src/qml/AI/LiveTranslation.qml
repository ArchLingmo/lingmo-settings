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

// Settings › IA › "Live translation" (lingmo-translate). Everything is read from and
// written to ~/.config/lingmo/translate.conf by TranslateModule.
ColumnLayout {
    id: section
    spacing: LingmoUI.Units.largeSpacing * 2

    readonly property var cfg: TranslateModule.config
    readonly property bool speaks: cfg.mode !== "subtitles"
    readonly property var currentVoice: {
        const list = TranslateModule.voices
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === cfg.voice)
                return list[i]
        return ({})
    }

    readonly property var modes: [
        { id: "subtitles", text: qsTr("Subtitles"), help: qsTr("Translated subtitles over the screen while the original audio keeps playing.") },
        { id: "dubbed", text: qsTr("Dubbed"), help: qsTr("A voice reads the translation and the original audio is lowered while it speaks.") },
        { id: "speak", text: qsTr("Speak"), help: qsTr("Translates what you say into the microphone and speaks it out loud.") },
        { id: "call", text: qsTr("Call"), help: qsTr("Both ways in a call: subtitles for the other person, your translated voice for them.") }
    ]
    readonly property var sources: [
        { id: "system", text: qsTr("System audio") },
        { id: "app", text: qsTr("One app") },
        { id: "mic", text: qsTr("Microphone") }
    ]
    readonly property var fromLanguages: [
        { id: "auto", name: qsTr("Detect automatically") },
        { id: "en", name: qsTr("English") },
        { id: "pt", name: qsTr("Portuguese") },
        { id: "es", name: qsTr("Spanish") },
        { id: "fr", name: qsTr("French") },
        { id: "it", name: qsTr("Italian") },
        { id: "de", name: qsTr("German") },
        { id: "ja", name: qsTr("Japanese") },
        { id: "zh", name: qsTr("Chinese") },
        { id: "ko", name: qsTr("Korean") }
    ]
    readonly property var toLanguages: fromLanguages.slice(1, 6)
    // each mode keeps its own pair; speaking, my own language is never detected
    readonly property var modeFromLanguages: cfg.mode === "speak" ? fromLanguages.slice(1) : fromLanguages
    readonly property var sttNames: ({
        "small-q5_1": qsTr("Small, compressed (fast)"),
        "base": qsTr("Base (fastest, less accurate)"),
        "small": qsTr("Small"),
        "large-v3-turbo-q5_0": qsTr("Large v3 Turbo, compressed (accurate)"),
        "large-v3-turbo": qsTr("Large v3 Turbo (most accurate)")
    })
    // the hardware recommendation for the current mode (hardware.conf) is always marked
    readonly property string recMark: " " + qsTr("(recommended)")
    // dubbed listening speaks with piper only: no cloned voice there
    readonly property var modeVoices: TranslateModule.voices.filter(v => cfg.mode !== "dubbed" || v.kind !== "profile")

    // estimates in GB of 1000 MB, as the measurements are quoted (4602 MB → "4.6 GB")
    function gb(mb) {
        return Number(mb / 1000).toLocaleString(Qt.locale(), 'f', 1)
    }

    function recSummary() {
        const where = cfg.tier === "cpu" ? qsTr("no NVIDIA graphics card with CUDA")
                                         : qsTr("%1, %2 GB").arg(cfg.gpuName).arg(Math.round(cfg.vramTotalMb / 1024))
        const parts = ["Whisper " + cfg.recSttModel,
                       cfg.recQuality === "quality" ? qsTr("instant draft refined by the AI model") : qsTr("instant translation only")]
        if (cfg.recVoiceKind === "clone")
            parts.push(qsTr("your cloned voice"))
        else if (cfg.recVoiceKind === "piper")
            parts.push(qsTr("a piper voice"))
        return qsTr("Recommended for this computer (%1): %2.").arg(where).arg(parts.join(" · "))
               + " " + (cfg.recVramMb > 0 ? qsTr("About %1 GB of video memory.").arg(gb(cfg.recVramMb)) : qsTr("Everything runs on the processor."))
    }
    // Installed Ollama models (from AIModule, which asks /api/tags), plus the configured one
    readonly property var llmModels: {
        const names = [cfg.llmModel]
        const installed = AIModule.installedModels
        for (let i = 0; i < installed.length; ++i)
            if (!installed[i].embedding && names.indexOf(installed[i].name) < 0)
                names.push(installed[i].name)
        return names
    }
    readonly property bool llmInstalled: {
        const installed = AIModule.installedModels
        for (let i = 0; i < installed.length; ++i)
            if (installed[i].name === cfg.llmModel)
                return true
        return false
    }

    function indexOfId(list, id) {
        return Math.max(0, list.findIndex(item => item.id === id))
    }

    Component.onCompleted: TranslateModule.refresh()

    // Coming back from lingmo-translate (a recorded profile, a downloaded model)
    Connections {
        target: typeof rootWindow !== "undefined" ? rootWindow : null
        function onActiveChanged() {
            if (rootWindow.active)
                TranslateModule.refresh()
        }
    }

    // A label with an explanation under it; the control goes to the right
    component SettingRow: RowLayout {
        property alias title: titleLabel.text
        property alias description: descriptionLabel.text

        spacing: LingmoUI.Units.largeSpacing * 2
        Layout.fillWidth: true

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Label {
                id: titleLabel
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Label {
                id: descriptionLabel
                visible: text !== ""
                color: LingmoUI.Theme.secondaryTextColor
                font.pointSize: LingmoUI.Units.fontCaption
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    component CardTitle: Label {
        font.pointSize: LingmoUI.Units.fontSubheading
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    component Caption: Label {
        color: LingmoUI.Theme.secondaryTextColor
        font.pointSize: LingmoUI.Units.fontCaption
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // ---------------------------------------------------------- Live translation
    RoundedItem {
        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true

            CardTitle {
                text: qsTr("Live translation")
            }

            LingmoUI.ActionButton {
                text: qsTr("Open Live translation")
                iconName: "preferences-desktop-locale"
                primary: true
                enabled: TranslateModule.appInstalled
                tipText: TranslateModule.appInstalled ? "" : qsTr("Install lingmo-translate to use it.")
                onClicked: TranslateModule.openApp("")
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Hear videos, calls and meetings in your language, with subtitles or a translated voice. Meta+Shift+T starts/stops live translation.")
        }

        LingmoUI.Banner {
            Layout.fillWidth: true
            visible: !TranslateModule.appInstalled
            type: 2
            closable: false
            title: qsTr("Live translation is not installed")
            text: qsTr("Install the “lingmo-translate” package. These settings are kept and used once it is installed.")
        }

        LingmoUI.SegmentedControl {
            Layout.fillWidth: true
            fillWidth: true
            model: section.modes.map(m => m.text)
            currentIndex: section.indexOfId(section.modes, section.cfg.mode)
            onActivated: (index) => TranslateModule.setValue("mode", section.modes[index].id)
        }

        Caption {
            text: section.modes[section.indexOfId(section.modes, section.cfg.mode)].help
        }

        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true

            Caption {
                text: section.recSummary()
            }

            LingmoUI.ActionButton {
                visible: !section.cfg.follows
                text: qsTr("Use recommended")
                flat: true
                tipText: qsTr("Forget what you changed in this mode and use what suits this computer")
                onClicked: TranslateModule.useRecommended()
            }
        }

        SettingRow {
            title: section.cfg.mode === "call" ? qsTr("They speak") : section.cfg.mode === "speak" ? qsTr("I speak") : qsTr("Translate from")
            description: qsTr("Each mode remembers its own languages.")

            ComboBox {
                Layout.preferredWidth: 220
                model: section.modeFromLanguages
                textRole: "name"
                valueRole: "id"
                currentIndex: section.indexOfId(section.modeFromLanguages, section.cfg.mode === "speak" && section.cfg.from === "auto" ? "pt" : section.cfg.from)
                onActivated: TranslateModule.setValue("from", currentValue)
            }
        }

        SettingRow {
            title: section.cfg.mode === "call" ? qsTr("I speak") : section.cfg.mode === "speak" ? qsTr("They hear") : qsTr("Translate to")

            ComboBox {
                Layout.preferredWidth: 220
                model: section.toLanguages
                textRole: "name"
                valueRole: "id"
                currentIndex: section.indexOfId(section.toLanguages, section.cfg.to)
                onActivated: TranslateModule.setValue("to", currentValue)
            }
        }

        SettingRow {
            title: qsTr("Listen to")
            description: section.cfg.source === "app" ? qsTr("Only this app is translated: type its name as it shows in the volume mixer.") : ""

            LingmoUI.SegmentedControl {
                model: section.sources.map(s => s.text)
                currentIndex: section.indexOfId(section.sources, section.cfg.source)
                onActivated: (index) => TranslateModule.setValue("source", section.sources[index].id)
            }
        }

        TextField {
            visible: section.cfg.source === "app"
            Layout.fillWidth: true
            placeholderText: qsTr("App name, e.g. Firefox")
            text: section.cfg.sourceApp
            onEditingFinished: TranslateModule.setValue("sourceApp", text)
        }

        SettingRow {
            title: qsTr("Translation")
            description: section.cfg.quality === "fast"
                         ? qsTr("Fastest: Opus-MT only, about 60 ms per sentence. Good for following along, a bit literal.")
                         : qsTr("Best quality: Opus-MT shows a draft instantly and the local AI model refines it, about 1.1 s more per sentence.")

            LingmoUI.SegmentedControl {
                model: [qsTr("Best quality") + (section.cfg.recQuality === "quality" ? section.recMark : ""),
                        qsTr("Fastest") + (section.cfg.recQuality === "fast" ? section.recMark : "")]
                currentIndex: section.cfg.quality === "fast" ? 1 : 0
                onActivated: (index) => TranslateModule.setValue("quality", index === 1 ? "fast" : "quality")
            }
        }

        SettingRow {
            visible: section.cfg.quality !== "fast"
            title: qsTr("AI model that refines the translation")
            description: !section.llmInstalled && AIModule.ollamaState === AIModule.Running
                         ? qsTr("%1 is not downloaded: download it above or pick another model.").arg(section.cfg.llmModel)
                         : AIModule.ollamaState !== AIModule.Running
                           ? qsTr("Ollama is not running: only the instant draft is shown.") : ""

            ComboBox {
                Layout.preferredWidth: 220
                model: section.llmModels
                currentIndex: 0
                onActivated: TranslateModule.setValue("llmModel", currentText)
            }
        }

        Caption {
            text: qsTr("Everything runs on this computer: no audio, text or voice is uploaded.")
        }
    }

    // ---------------------------------------------------------- Subtitles and recognition
    RoundedItem {
        CardTitle {
            text: qsTr("Subtitles and speech recognition")
        }

        SettingRow {
            title: qsTr("Show the original text")
            description: qsTr("A smaller line with what was said, above the translation.")

            Switch {
                checked: section.cfg.showOriginal
                rightPadding: 0
                onToggled: TranslateModule.setValue("showOriginal", checked)
            }
        }

        SettingRow {
            title: qsTr("Subtitle size")

            Slider {
                id: fontScaleSlider
                Layout.preferredWidth: 220
                from: 0.5
                to: 2.5
                stepSize: 0.05
                value: section.cfg.overlayFontScale
                onPressedChanged: if (!pressed) TranslateModule.setValue("overlayFontScale", value)
            }

            Label {
                text: Math.round(fontScaleSlider.value * 100) + "%"
                color: LingmoUI.Theme.secondaryTextColor
                Layout.minimumWidth: percentMetrics.width
                horizontalAlignment: Text.AlignRight
            }
        }

        SettingRow {
            title: qsTr("Recognition model")
            description: {
                const list = TranslateModule.sttModels
                for (let i = 0; i < list.length; ++i)
                    if (list[i].id === section.cfg.sttModel && !list[i].installed)
                        return qsTr("For this mode. Not downloaded yet: Live translation fetches it when the mode starts, or use “Download / set up” below.")
                return qsTr("For this mode. Whisper, shared with the Assistant and transcription.")
            }

            ComboBox {
                Layout.preferredWidth: 380
                model: TranslateModule.sttModels.map(m => ({ id: m.id, name: (section.sttNames[m.id] || m.id)
                                                                                + (m.id === section.cfg.recSttModel ? section.recMark : "")
                                                                                + (m.installed ? "" : " · " + qsTr("not downloaded")) }))
                textRole: "name"
                valueRole: "id"
                currentIndex: section.indexOfId(TranslateModule.sttModels, section.cfg.sttModel)
                onActivated: TranslateModule.setValue("sttModel", currentValue)
            }
        }

        SettingRow {
            title: qsTr("Pause before a sentence is finished")
            description: qsTr("Lower is faster, but may cut sentences in the middle.")

            Slider {
                id: silenceSlider
                Layout.preferredWidth: 220
                from: 250
                to: 900
                stepSize: 50
                value: section.cfg.endSilenceMs
                onPressedChanged: if (!pressed) TranslateModule.setValue("endSilenceMs", value)
            }

            Label {
                text: qsTr("%1 ms").arg(Math.round(silenceSlider.value))
                color: LingmoUI.Theme.secondaryTextColor
                Layout.minimumWidth: msMetrics.width
                horizontalAlignment: Text.AlignRight
            }
        }

        SettingRow {
            title: qsTr("Show timings")
            description: qsTr("A panel in the app with how long each step takes (recognition, translation, voice).")

            Switch {
                checked: section.cfg.debugPanel
                rightPadding: 0
                onToggled: TranslateModule.setValue("debugPanel", checked)
            }
        }
    }

    // ---------------------------------------------------------- Voice
    RoundedItem {
        CardTitle {
            text: qsTr("Translated voice")
        }

        Caption {
            visible: !section.speaks
            text: qsTr("Used in the Dubbed, Speak and Call modes.")
        }

        SettingRow {
            title: section.cfg.mode === "dubbed" ? qsTr("Voice for dubbing") : qsTr("Voice")
            description: section.currentVoice.missing
                         ? qsTr("This voice is not on this computer anymore: choose another one.")
                         : section.currentVoice.kind === "profile" && !section.cfg.cloneAllowed
                           ? qsTr("A cloned voice is not recommended on this computer: without room on a CUDA graphics card it is slow.")
                           : section.cfg.mode === "dubbed"
                             ? qsTr("Dubbing uses piper voices, so the AI translator fits beside them.")
                             : section.currentVoice.kind === "piper" && section.currentVoice.license
                               ? qsTr("Voice licence: %1").arg(section.currentVoice.license)
                               : section.currentVoice.kind === "profile" && !section.currentVoice.ready
                                 ? qsTr("Being prepared: the first sentence takes longer.") : ""

            ComboBox {
                Layout.preferredWidth: 320
                model: section.modeVoices.map(v => ({ id: v.id, name: v.name + (v.id === section.cfg.recVoice ? section.recMark : "") }))
                textRole: "name"
                valueRole: "id"
                currentIndex: section.indexOfId(section.modeVoices, section.cfg.voice)
                onActivated: TranslateModule.setValue("voice", currentValue)
            }
        }

        SettingRow {
            visible: section.currentVoice.kind === "profile"
            title: qsTr("Cloned voice")
            description: section.cfg.voiceQuality === "fast"
                         ? qsTr("Fastest: one take per sentence.")
                         : qsTr("Best quality: up to 3 takes per sentence, keeping the one with the most natural speed.")

            LingmoUI.SegmentedControl {
                model: [qsTr("Best quality"), qsTr("Fastest")]
                currentIndex: section.cfg.voiceQuality === "fast" ? 1 : 0
                onActivated: (index) => TranslateModule.setValue("voiceQuality", index === 1 ? "fast" : "quality")
            }
        }

        SettingRow {
            title: qsTr("Original audio while the voice speaks")
            description: qsTr("How loud the original stays under the translated voice.")

            Slider {
                id: duckSlider
                Layout.preferredWidth: 220
                from: 0.1
                to: 1.0
                stepSize: 0.05
                value: section.cfg.duck
                onPressedChanged: if (!pressed) TranslateModule.setValue("duck", value)
            }

            Label {
                text: Math.round(duckSlider.value * 100) + "%"
                color: LingmoUI.Theme.secondaryTextColor
                Layout.minimumWidth: percentMetrics.width
                horizontalAlignment: Text.AlignRight
            }
        }

        // ---- Voice profiles
        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true
            Layout.topMargin: LingmoUI.Units.smallSpacing

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Label {
                    text: qsTr("Your voice profiles")
                    font.weight: Font.DemiBold
                }

                Caption {
                    text: qsTr("Speak in the translated language with your own voice. Only clone your own voice.")
                }
            }

            LingmoUI.ActionButton {
                text: qsTr("Record new profile")
                iconName: "audio-input-microphone"
                enabled: TranslateModule.appInstalled
                tipText: TranslateModule.appInstalled ? "" : qsTr("Install lingmo-translate to record a voice.")
                onClicked: TranslateModule.openApp("voices")
            }
        }

        Caption {
            visible: TranslateModule.profiles.length === 0
            text: qsTr("No voice profile yet. Recording takes about a minute of reading aloud.")
        }

        Repeater {
            model: TranslateModule.profiles

            LingmoUI.Card {
                id: profileCard
                Layout.fillWidth: true
                hoverEnabled: true
                color: LingmoUI.Theme.alternateBackgroundColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: profileCard.padding
                    anchors.rightMargin: LingmoUI.Units.smallSpacing
                    anchors.topMargin: LingmoUI.Units.smallSpacing
                    anchors.bottomMargin: LingmoUI.Units.smallSpacing
                    spacing: LingmoUI.Units.largeSpacing

                    LingmoUI.IconItem {
                        width: LingmoUI.Units.iconSizes.small
                        height: width
                        source: "audio-input-microphone-symbolic"
                        color: LingmoUI.Theme.textColor
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: LingmoUI.Units.smallSpacing

                            Label {
                                text: modelData.displayName
                                elide: Text.ElideRight
                                Layout.maximumWidth: profileCard.width / 2
                            }

                            LingmoUI.Badge {
                                text: modelData.ready ? qsTr("Ready") : qsTr("Not ready")
                                tint: modelData.ready ? LingmoUI.Theme.successColor : LingmoUI.Theme.warningColor
                            }

                            LingmoUI.Badge {
                                visible: section.cfg.voice === "profile:" + modelData.name
                                text: qsTr("In use")
                                tint: LingmoUI.Theme.highlightColor
                            }
                        }

                        Caption {
                            text: [modelData.created !== "" ? qsTr("Recorded %1").arg(modelData.created) : "",
                                   modelData.lengthText,
                                   modelData.ready ? "" : qsTr("prepared on first use")]
                                  .filter(p => p !== "").join(" · ")
                        }
                    }

                    Button {
                        text: qsTr("Re-record")
                        flat: true
                        enabled: TranslateModule.appInstalled
                        onClicked: TranslateModule.openApp("voices")
                    }

                    LingmoUI.IconButton {
                        iconName: "edit-delete"
                        tipText: qsTr("Delete")
                        onClicked: {
                            confirmDialog.kind = "profile"
                            confirmDialog.key = modelData.name
                            confirmDialog.label = modelData.displayName
                            confirmDialog.shared = false
                            confirmDialog.open()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- Models
    RoundedItem {
        RowLayout {
            spacing: LingmoUI.Units.largeSpacing
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                CardTitle {
                    text: qsTr("Translation models")
                }

                Caption {
                    text: TranslateModule.totalSizeText !== ""
                          ? qsTr("%1 on disk. Removed models can be downloaded again.").arg(TranslateModule.totalSizeText)
                          : qsTr("Downloaded the first time you use Live translation.")
                }
            }

            LingmoUI.Spinner {
                size: LingmoUI.Units.iconSizes.small
                visible: TranslateModule.measuring
                running: visible
            }

            LingmoUI.ActionButton {
                text: qsTr("Download / set up")
                iconName: "folder-download"
                enabled: TranslateModule.appInstalled
                tipText: TranslateModule.appInstalled ? "" : qsTr("Install lingmo-translate to download the models.")
                onClicked: TranslateModule.openApp("models")
            }
        }

        Label {
            visible: TranslateModule.errorText !== ""
            text: TranslateModule.errorText
            color: LingmoUI.Theme.errorColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: TranslateModule.models

            RowLayout {
                spacing: LingmoUI.Units.largeSpacing
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Label {
                        text: modelData.name
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Caption {
                        text: modelData.detail
                    }
                }

                Label {
                    text: modelData.sizeText
                    color: LingmoUI.Theme.secondaryTextColor
                }

                Button {
                    text: qsTr("Remove")
                    onClicked: {
                        confirmDialog.kind = "model"
                        confirmDialog.key = modelData.key
                        confirmDialog.label = modelData.name
                        confirmDialog.shared = modelData.shared
                        confirmDialog.open()
                    }
                }
            }
        }

        // Licences of everything Live translation uses
        ColumnLayout {
            spacing: LingmoUI.Units.smallSpacing / 2
            Layout.fillWidth: true
            Layout.topMargin: LingmoUI.Units.smallSpacing

            Label {
                text: qsTr("Licences")
                font.pointSize: LingmoUI.Units.fontCaption
                font.weight: Font.DemiBold
                color: LingmoUI.Theme.secondaryTextColor
            }

            Repeater {
                model: [
                    qsTr("Whisper (speech recognition): MIT"),
                    qsTr("Opus-MT (translation): CC-BY 4.0, Helsinki-NLP / University of Helsinki"),
                    qsTr("Silero VAD (speech detection): MIT"),
                    qsTr("Piper (voices): engine MIT; each voice has its own licence, shown with the voice"),
                    qsTr("Chatterbox (cloned voice): MIT"),
                    qsTr("qwen3.5 (refines the translation): Apache-2.0")
                ]

                Caption {
                    text: modelData
                }
            }
        }
    }

    TextMetrics {
        id: percentMetrics
        text: "250%"
    }

    TextMetrics {
        id: msMetrics
        text: qsTr("%1 ms").arg(900)
    }

    Dialog {
        id: confirmDialog
        parent: Overlay.overlay
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        title: kind === "profile" ? qsTr("Delete the voice profile %1?").arg(label) : qsTr("Remove %1?").arg(label)

        property string kind: ""
        property string key: ""
        property string label: ""
        property bool shared: false

        ColumnLayout {
            spacing: LingmoUI.Units.largeSpacing * 1.5

            Label {
                text: confirmDialog.kind === "profile"
                      ? qsTr("The recording and everything prepared from it are deleted from this computer. This cannot be undone.")
                      : confirmDialog.shared
                        ? qsTr("This Whisper model is shared: the Assistant and transcription in Lingmo Studio may use it too. You can download it again later.")
                        : qsTr("It frees up disk space. You can download it again later.")
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 340
            }

            RowLayout {
                spacing: LingmoUI.Units.largeSpacing

                LingmoUI.ActionButton {
                    text: qsTr("Cancel")
                    Layout.fillWidth: true
                    onClicked: confirmDialog.reject()
                }

                LingmoUI.ActionButton {
                    text: confirmDialog.kind === "profile" ? qsTr("Delete") : qsTr("Remove")
                    destructive: true
                    Layout.fillWidth: true
                    onClicked: {
                        confirmDialog.accept()
                        if (confirmDialog.kind === "profile")
                            TranslateModule.removeProfile(confirmDialog.key)
                        else
                            TranslateModule.removeModel(confirmDialog.key)
                    }
                }
            }
        }
    }
}
