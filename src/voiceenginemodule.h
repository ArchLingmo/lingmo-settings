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

#pragma once

#include <QObject>

class QFileSystemWatcher;

// Settings › IA › "Cloned voice": the engine every Lingmo app uses for a cloned
// voice, one system-wide choice in ~/.config/lingmoos/voice.conf
// ([Voice] cloneEngine=chatterbox|omnivoice, docs/voices.md "Motor de voz clonada").
// Not chosen there, the hardware recommendation's engine (hwprofile.h,
// ~/.config/lingmoos/hardware.conf) is used when it can run, else Chatterbox.
//
// OmniVoice (CC-BY-NC weights: personal, non-commercial use) belongs to Voice
// Studio: it can be chosen only once Voice Studio has the licence accepted and
// the engine installed; Settings never downloads it.
class VoiceEngineModule : public QObject
{
    Q_OBJECT
    // what is saved, or the recommendation when nothing is: "chatterbox" or "omnivoice"
    Q_PROPERTY(QString cloneEngine READ cloneEngine NOTIFY changed)
    // the engine that suits this computer, marked "(recommended)"
    Q_PROPERTY(QString recommendedEngine READ recommendedEngine NOTIFY changed)
    // the cloned voice is recommended in the speaking modes (a CUDA GPU with room for it)
    Q_PROPERTY(bool cloneRecommended READ cloneRecommended NOTIFY changed)
    // the recommended engine fits on the graphics card
    Q_PROPERTY(bool cloneOnGpu READ cloneOnGpu NOTIFY changed)
    // [Voice] cloneEngine is in voice.conf (else the recommendation is followed)
    Q_PROPERTY(bool chosen READ chosen NOTIFY changed)
    // OmniVoice accepted and installed in Voice Studio
    Q_PROPERTY(bool omniVoiceReady READ omniVoiceReady NOTIFY changed)
    Q_PROPERTY(bool voiceStudioInstalled READ voiceStudioInstalled NOTIFY changed)

public:
    explicit VoiceEngineModule(QObject *parent = nullptr);

    QString cloneEngine() const { return m_engine; }
    QString recommendedEngine() const { return m_recommended; }
    bool cloneRecommended() const { return m_cloneRecommended; }
    bool cloneOnGpu() const { return m_cloneOnGpu; }
    bool chosen() const { return m_chosen; }
    bool omniVoiceReady() const { return m_omniReady; }
    bool voiceStudioInstalled() const { return !m_studio.isEmpty(); }

    static QString configPath();

    Q_INVOKABLE void setCloneEngine(const QString &engine);
    // Removes the choice: the recommendation is followed again
    Q_INVOKABLE void useRecommended();
    Q_INVOKABLE void refresh();
    // lingmo-voicestudio --section engines (where OmniVoice is turned on)
    Q_INVOKABLE void openVoiceStudioEngines();

signals:
    void changed();

private:
    void watch();

    QFileSystemWatcher *m_watcher;
    QString m_engine = QStringLiteral("chatterbox");
    bool m_omniReady = false;
    QString m_recommended = QStringLiteral("chatterbox");
    bool m_cloneRecommended = false;
    bool m_cloneOnGpu = false;
    bool m_chosen = false;
    QString m_studio;
};
