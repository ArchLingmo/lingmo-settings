/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import Lingmo.Settings 1.0
import "../"

// Help & tips: what each Lingmo app does and how to use it, with the shortcut it has
// right now. Apps that are not installed are left out.
ItemPage {
    id: page
    headerTitle: qsTranslate("HelpPage", "Help & tips")

    HelpApps { id: help }

    // bin: to check it is installed; exec: the command a shortcut runs; open: the Open button
    readonly property var apps: [
        { name: qsTranslate("HelpPage", "File actions"), icon: "lingmo-fileaction", bin: "lingmo-fileaction",
          open: "lingmo-fileaction --settings",
          keys: [{ exec: "lingmo-fileaction --keyboard", what: qsTranslate("HelpPage", "Wheel for the selected files") }],
          text: qsTranslate("HelpPage", "Convert, compress and act on files without opening any app."),
          tips: [qsTranslate("HelpPage", "Start dragging a file and, without letting go, tap Shift (convert), Ctrl (tools) or Alt (actions). Drop it on a slice; drop it in the middle to cancel."),
                 qsTranslate("HelpPage", "In the file manager: right-click › Convert… or File actions…"),
                 qsTranslate("HelpPage", "The result is saved next to the original, which is never changed.")] },
        { name: qsTranslate("HelpPage", "Live translation"), icon: "lingmo-translate", bin: "lingmo-translate",
          open: "lingmo-translate",
          keys: [{ exec: "lingmo-translate --toggle", what: qsTranslate("HelpPage", "Start or stop, in the last mode") }],
          text: qsTranslate("HelpPage", "Subtitles and dubbing for videos and calls, and your own speech translated, all on this computer."),
          tips: [qsTranslate("HelpPage", "Modes: Subtitles, Listen dubbed, Speak translated and Call. Each mode keeps its own languages."),
                 qsTranslate("HelpPage", "In OBS, Meet, Teams or Discord, pick the microphone \"Lingmo Tradutor\" to send the translated voice."),
                 qsTranslate("HelpPage", "The Island card changes the mode and the languages while it runs; it turns green when you can talk.")] },
        { name: qsTranslate("HelpPage", "Dictation"), icon: "audio-input-microphone", bin: "lingmo-dictation",
          open: "lingmo-voicestudio",
          keys: [{ exec: "lingmo-dictation --toggle", what: qsTranslate("HelpPage", "Start or stop dictating") }],
          text: qsTranslate("HelpPage", "Type by speaking, in any text field."),
          tips: [qsTranslate("HelpPage", "The text appears while you speak and is typed at each pause."),
                 qsTranslate("HelpPage", "Say \"vírgula\", \"ponto\", \"nova linha\" or \"apagar última palavra\".")] },
        { name: qsTranslate("HelpPage", "Voice Studio"), icon: "lingmo-voicestudio", bin: "lingmo-voicestudio",
          open: "lingmo-voicestudio", keys: [],
          text: qsTranslate("HelpPage", "Create and clone voices, read texts aloud and export audio."),
          tips: [qsTranslate("HelpPage", "Engines › Find the best configuration: picks the best settings for your graphics card."),
                 qsTranslate("HelpPage", "The engine for cloned voices is chosen in Settings › AI › Cloned voice.")] },
        { name: qsTranslate("HelpPage", "Ask about the screen"), icon: "lingmo-screenshot", bin: "lingmo-screenshot",
          open: "lingmo-screenshot ask",
          keys: [{ exec: "lingmo-screenshot ask", what: qsTranslate("HelpPage", "Circle anything and ask") },
                 { exec: "lingmo-screenshot gui", what: qsTranslate("HelpPage", "Screenshot") },
                 { exec: "lingmo-screenshot full", what: qsTranslate("HelpPage", "All screens") },
                 { exec: "lingmo-screenshot record", what: qsTranslate("HelpPage", "Record the screen") }],
          text: qsTranslate("HelpPage", "Screenshots, recordings, and questions to the local AI about what is on the screen."),
          tips: [qsTranslate("HelpPage", "Reads text in images in any language; it offers to install the reading of a new language when needed.")] },
        { name: qsTranslate("HelpPage", "Assistant"), icon: "lingmo-assistant", bin: "lingmo-assistant",
          open: "lingmo-assistant",
          keys: [{ exec: "lingmo-assistant", what: qsTranslate("HelpPage", "Open the Assistant") },
                 { exec: "lingmo-assistant --voice", what: qsTranslate("HelpPage", "Ask by voice") }],
          text: qsTranslate("HelpPage", "An AI that runs on your computer: answers, flows and actions in the apps."),
          tips: [qsTranslate("HelpPage", "It can use the apps' actions: convert a file, translate, read a document aloud…")] },
        { name: qsTranslate("HelpPage", "Search"), icon: "lingmo-spotlight", bin: "lingmo-spotlight",
          open: "lingmo-spotlight",
          keys: [{ exec: "lingmo-spotlight", what: qsTranslate("HelpPage", "Search apps, files and actions") },
                 { exec: "lingmo-clipboard --history", what: qsTranslate("HelpPage", "Clipboard history") }],
          text: qsTranslate("HelpPage", "Find anything and run app actions from one place."), tips: [] },
        { name: qsTranslate("HelpPage", "Reader"), icon: "lingmo-reader", bin: "lingmo-reader",
          open: "lingmo-reader", keys: [],
          text: qsTranslate("HelpPage", "PDF, EPUB, DOCX and ODT, read aloud with the words highlighted."),
          tips: [qsTranslate("HelpPage", "Listen: the voice reads from the sentence you click."),
                 qsTranslate("HelpPage", "Learning mode: click a word to translate it, and slow the reading down.")] },
        { name: qsTranslate("HelpPage", "Lingmo Tutor"), icon: "lingmo-tutor", bin: "lingmo-tutor",
          open: "lingmo-tutor", keys: [],
          text: qsTranslate("HelpPage", "Learn by asking: by voice, text, photo or PDF, and practise languages."),
          tips: [qsTranslate("HelpPage", "It teaches with questions and hints; the parents' mode has a PIN.")] },
        { name: qsTranslate("HelpPage", "Lingmo Studio"), icon: "lingmo-studio", bin: "lingmo-studio",
          open: "lingmo-studio", keys: [],
          text: qsTranslate("HelpPage", "Video editor with Shorts and Reels cuts, captions and dubbing."), tips: [] },
        { name: qsTranslate("HelpPage", "Podcast dubbing"), icon: "lingmo-podcast", bin: "lingmo-podcast",
          open: "lingmo-podcast", keys: [],
          text: qsTranslate("HelpPage", "Dubs podcasts and interviews keeping each speaker's voice."), tips: [] }
    ]

    function prettyKeys(keys) {
        return keys.replace(/Meta/g, "⊞").replace(/\+/g, " + ")
    }

    Scrollable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight

        ColumnLayout {
            id: layout
            anchors.fill: parent
            spacing: LingmoUI.Units.largeSpacing * 2

            // The desktop shortcuts everyone should know
            RoundedItem {
                Label {
                    text: qsTranslate("HelpPage", "Desktop")
                    font.pointSize: LingmoUI.Units.fontSubheading
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: [
                        { exec: "lingmo-launcher", what: qsTranslate("HelpPage", "Open the launcher (tap the key)") },
                        { exec: "lingmo-screenlocker", what: qsTranslate("HelpPage", "Lock the screen") },
                        { exec: "lingmo-reload", what: qsTranslate("HelpPage", "Reload the desktop when something looks wrong") }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        readonly property string keys: help.shortcutFor(modelData.exec)
                        visible: keys.length > 0
                        Layout.fillWidth: true
                        Label { text: modelData.what; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        Label { text: page.prettyKeys(parent.keys); font.weight: Font.DemiBold; color: LingmoUI.Theme.highlightColor }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: LingmoUI.Theme.secondaryTextColor
                    font.pointSize: LingmoUI.Units.fontCaption
                    text: qsTranslate("HelpPage", "Every shortcut can be changed in Settings › Shortcuts.")
                }
            }

            Repeater {
                model: page.apps
                delegate: RoundedItem {
                    id: card
                    required property var modelData
                    visible: help.installed(modelData.bin)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: LingmoUI.Units.largeSpacing
                        LingmoUI.IconItem {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            source: card.modelData.icon
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: card.modelData.name
                                font.pointSize: LingmoUI.Units.fontSubheading
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: card.modelData.text
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: LingmoUI.Theme.secondaryTextColor
                            }
                        }
                        Button {
                            text: qsTranslate("HelpPage", "Open")
                            onClicked: help.launch(card.modelData.open)
                        }
                    }

                    Repeater {
                        model: card.modelData.keys
                        delegate: RowLayout {
                            required property var modelData
                            readonly property string keys: help.shortcutFor(modelData.exec)
                            visible: keys.length > 0
                            Layout.fillWidth: true
                            Label { text: modelData.what; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Label { text: page.prettyKeys(parent.keys); font.weight: Font.DemiBold; color: LingmoUI.Theme.highlightColor }
                        }
                    }

                    Repeater {
                        model: card.modelData.tips
                        delegate: Label {
                            required property string modelData
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "• " + modelData
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: LingmoUI.Units.largeSpacing }
        }
    }
}
