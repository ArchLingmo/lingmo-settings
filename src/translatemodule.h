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
#include <QVariantList>
#include <QVariantMap>

#include "hwprofile.h"

class QFileSystemWatcher;

// Settings › IA › "Live translation" (lingmo-translate). Reads and writes
// ~/.config/lingmo/translate.conf ([Translate], shared with the app), lists the
// cloned voice profiles (~/.local/share/lingmo/voices/<name>/) and the models the
// app keeps on disk, and opens the app for what Settings doesn't do itself
// (recording a voice, downloading models).
class TranslateModule : public QObject
{
    Q_OBJECT
    // Every key of [Translate], with the contract's defaults for missing ones. "quality",
    // "sttModel" and "voice" are the current mode's (per mode, as lingmo-translate keeps
    // them); not set, the hardware recommendation's (hwprofile.h, hardware.conf). Also:
    // recQuality, recSttModel, recVoice (id), recVoiceKind (none|piper|clone), cloneAllowed,
    // recVramMb, tier, gpuName, vramTotalMb and follows (nothing set by hand in this mode)
    Q_PROPERTY(QVariantMap config READ config NOTIFY configChanged)
    Q_PROPERTY(bool appInstalled READ appInstalled NOTIFY appChanged)
    // [{id: "piper:<path>"|"espeak"|"profile:<name>", name, detail, kind, license, missing}]
    Q_PROPERTY(QVariantList voices READ voices NOTIFY voicesChanged)
    // [{name, created, seconds, lengthText, snrDb, model, ready}]
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY voicesChanged)
    // [{id, name, installed}] for the sttModel choice
    Q_PROPERTY(QVariantList sttModels READ sttModels NOTIFY modelsChanged)
    // [{key, family, name, detail, sizeText, license, shared}]
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsChanged)
    Q_PROPERTY(bool measuring READ measuring NOTIFY modelsChanged)
    Q_PROPERTY(QString totalSizeText READ totalSizeText NOTIFY modelsChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY messageChanged)
    Q_PROPERTY(QString configPath READ configPath CONSTANT)

public:
    explicit TranslateModule(QObject *parent = nullptr);

    QVariantMap config() const { return m_config; }
    bool appInstalled() const { return !m_appBinary.isEmpty(); }
    QVariantList voices() const { return m_voices; }
    QVariantList profiles() const { return m_profiles; }
    QVariantList sttModels() const { return m_sttModels; }
    QVariantList models() const { return m_models; }
    bool measuring() const { return m_measuring; }
    QString totalSizeText() const { return m_totalSizeText; }
    QString errorText() const { return m_errorText; }

    static QString configPath();
    static QString voicesDir();
    static QString translateDataDir();

    // Validates and writes one key of [Translate]; invalid values are ignored
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);
    // Reads the config again and scans voices, profiles and models
    Q_INVOKABLE void refresh();
    // lingmo-translate --page <page> (detached)
    Q_INVOKABLE void openApp(const QString &page = QString());
    // Forgets what was set by hand in the current mode (model, translation, voice)
    Q_INVOKABLE void useRecommended();
    // Deletes ~/.local/share/lingmo/voices/<name>/
    Q_INVOKABLE void removeProfile(const QString &name);
    // Deletes one entry of `models` (a file or a directory)
    Q_INVOKABLE void removeModel(const QString &key);
    Q_INVOKABLE void clearError();

signals:
    void configChanged();
    void appChanged();
    void voicesChanged();
    void modelsChanged();
    void messageChanged();

private:
    struct ModelEntry {
        QString key;      // absolute path
        QString family;   // whisper, mt, vad, venv
        QString name;
        bool isDir = false;
        qint64 size = -1; // -1 while measuring
    };

    void loadConfig();
    void scanVoices();
    void scanModels();
    void publishModels();
    void watchFiles();
    void setError(const QString &text);
    static QString piperLicense(const QString &onnx);
    static QString firstReadyProfile();
    static QString piperFor(const QString &lang);

    HwProfile::Profile m_hw;

    QFileSystemWatcher *m_watcher;
    QVariantMap m_config;
    QString m_appBinary;
    QVariantList m_voices;
    QVariantList m_profiles;
    QVariantList m_sttModels;
    QList<ModelEntry> m_entries;
    QVariantList m_models;
    bool m_measuring = false;
    int m_measureGeneration = 0;
    QString m_totalSizeText;
    QString m_errorText;
};
