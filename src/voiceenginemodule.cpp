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

#include "voiceenginemodule.h"
#include "hwprofile.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

namespace {

QString configDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
}

QString dataDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
}

QString studioConfig()
{
    return configDir() + QStringLiteral("/lingmo/voicestudio.json");
}

// huggingface_hub: $HF_HOME, else $XDG_CACHE_HOME/huggingface, else ~/.cache/huggingface
QString omniWeights()
{
    QString hf = qEnvironmentVariable("HF_HOME");
    if (hf.isEmpty()) {
        const QString xdg = qEnvironmentVariable("XDG_CACHE_HOME");
        hf = (xdg.isEmpty() ? QDir::homePath() + QStringLiteral("/.cache") : xdg) + QStringLiteral("/huggingface");
    }
    return hf + QStringLiteral("/hub/models--k2-fsa--OmniVoice/snapshots");
}

// What Voice Studio reports as accepted ("omnivoiceAccepted") and installed: the
// acceptance in its config, its venv and the weights it downloaded
bool omniReady()
{
    QFile f(studioConfig());
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonObject cfg = QJsonDocument::fromJson(f.read(256 * 1024)).object();
    if (cfg.value(QStringLiteral("omnivoice")).toObject().value(QStringLiteral("accepted")).toString().isEmpty())
        return false;
    const QString venv = qEnvironmentVariable("LINGMO_OMNIVOICE_VENV", dataDir() + QStringLiteral("/lingmo/omnivoice-venv"));
    return QFileInfo::exists(venv + QStringLiteral("/bin/python")) && QFileInfo::exists(omniWeights());
}

} // namespace

VoiceEngineModule::VoiceEngineModule(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    // QSettings and Voice Studio save by replacing the file: watch the folders too
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &VoiceEngineModule::refresh);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &VoiceEngineModule::refresh);
    refresh();
}

QString VoiceEngineModule::configPath()
{
    return configDir() + QStringLiteral("/lingmoos/voice.conf");
}

void VoiceEngineModule::refresh()
{
    // what suits this computer (hardware.conf, recomputed when the GPU changed)
    const HwProfile::Profile hw = HwProfile::current();
    const QString recommended = hw.cloneEngine == QLatin1String("omnivoice") ? QStringLiteral("omnivoice") : QStringLiteral("chatterbox");
    const bool cloneRecommended = hw.mode(QStringLiteral("speak")).cloneAllowed;
    QSettings conf(configPath(), QSettings::IniFormat);
    const bool chosen = conf.contains(QStringLiteral("Voice/cloneEngine"));
    QString engine = conf.value(QStringLiteral("Voice/cloneEngine"), recommended).toString();
    if (engine != QLatin1String("omnivoice"))
        engine = QStringLiteral("chatterbox");
    const bool ready = omniReady();
    const QString studio = QStandardPaths::findExecutable(QStringLiteral("lingmo-voicestudio"));
    const bool differs = engine != m_engine || ready != m_omniReady || studio != m_studio || recommended != m_recommended
        || chosen != m_chosen || cloneRecommended != m_cloneRecommended || hw.cloneOnGpu != m_cloneOnGpu;
    m_engine = engine;
    m_omniReady = ready;
    m_studio = studio;
    m_recommended = recommended;
    m_chosen = chosen;
    m_cloneRecommended = cloneRecommended;
    m_cloneOnGpu = hw.cloneOnGpu;
    watch();
    if (differs)
        emit changed();
}

void VoiceEngineModule::watch()
{
    for (const QString &path : {configPath(), QFileInfo(configPath()).absolutePath(), studioConfig(), QFileInfo(studioConfig()).absolutePath()}) {
        if (QFileInfo::exists(path) && !m_watcher->files().contains(path) && !m_watcher->directories().contains(path))
            m_watcher->addPath(path);
    }
}

void VoiceEngineModule::setCloneEngine(const QString &engine)
{
    if (engine != QLatin1String("chatterbox") && engine != QLatin1String("omnivoice"))
        return;
    if (engine == QLatin1String("omnivoice") && !m_omniReady)
        return; // turned on in Voice Studio first (licence and download)
    QDir().mkpath(QFileInfo(configPath()).absolutePath());
    {
        QSettings conf(configPath(), QSettings::IniFormat);
        conf.setValue(QStringLiteral("Voice/cloneEngine"), engine);
        conf.sync();
    }
    refresh();
}

void VoiceEngineModule::useRecommended()
{
    {
        QSettings conf(configPath(), QSettings::IniFormat);
        conf.remove(QStringLiteral("Voice/cloneEngine"));
        conf.sync();
    }
    refresh();
}

void VoiceEngineModule::openVoiceStudioEngines()
{
    if (!m_studio.isEmpty())
        QProcess::startDetached(m_studio, {QStringLiteral("--section"), QStringLiteral("engines")});
}
