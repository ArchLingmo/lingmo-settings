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

#include "translatemodule.h"
#include "aimodule.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QFutureWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QtConcurrent>

namespace {

const QString Group = QStringLiteral("Translate");
const QString DefaultVoice = QStringLiteral("piper:/usr/share/piper-voices/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx");

const QStringList Modes = {QStringLiteral("subtitles"), QStringLiteral("dubbed"), QStringLiteral("speak"), QStringLiteral("call")};
const QStringList Sources = {QStringLiteral("system"), QStringLiteral("app"), QStringLiteral("mic")};
const QStringList FromLanguages = {QStringLiteral("auto"), QStringLiteral("en"), QStringLiteral("pt"),
                                   QStringLiteral("es"), QStringLiteral("fr"), QStringLiteral("it"),
                                   QStringLiteral("de"), QStringLiteral("ja"), QStringLiteral("zh"), QStringLiteral("ko")};
const QStringList ToLanguages = {QStringLiteral("pt"), QStringLiteral("en"), QStringLiteral("es"),
                                 QStringLiteral("fr"), QStringLiteral("it")};
const QStringList Qualities = {QStringLiteral("quality"), QStringLiteral("fast")};
const QStringList SttModels = {QStringLiteral("small-q5_1"), QStringLiteral("base"), QStringLiteral("small"),
                               QStringLiteral("large-v3-turbo-q5_0"), QStringLiteral("large-v3-turbo")};

// Each mode keeps its own pair ([Translate] <mode>/from, <mode>/to, as lingmo-translate
// writes them): listening translates anything into Portuguese, speaking turns my
// Portuguese into English; a call keeps from = their language, to = mine.
// "from"/"to" in `config` are the current mode's pair.
QString defaultFrom(const QString &mode)
{
    return mode == QLatin1String("speak") ? QStringLiteral("pt") : QStringLiteral("auto");
}

QString defaultTo(const QString &mode)
{
    return mode == QLatin1String("speak") ? QStringLiteral("en") : QStringLiteral("pt");
}

QVariantMap defaults()
{
    return {
        {QStringLiteral("mode"), Modes.first()},
        {QStringLiteral("source"), Sources.first()},
        {QStringLiteral("sourceApp"), QString()},
        {QStringLiteral("from"), QStringLiteral("auto")},
        {QStringLiteral("to"), QStringLiteral("pt")},
        {QStringLiteral("quality"), QStringLiteral("quality")},
        {QStringLiteral("llmModel"), QStringLiteral("qwen3.5:4b")},
        {QStringLiteral("voice"), DefaultVoice},
        {QStringLiteral("voiceQuality"), QStringLiteral("quality")},
        {QStringLiteral("duck"), 0.3},
        {QStringLiteral("showOriginal"), true},
        {QStringLiteral("overlayFontScale"), 1.0},
        {QStringLiteral("sttModel"), SttModels.first()},
        {QStringLiteral("endSilenceMs"), 400},
        {QStringLiteral("debugPanel"), false},
    };
}

bool validProfileName(const QString &name)
{
    return !name.isEmpty() && name != QLatin1String(".") && name != QLatin1String("..")
           && !name.contains(QLatin1Char('/')) && !name.contains(QChar(0));
}

bool toBool(const QVariant &value, bool *ok)
{
    *ok = true;
    if (value.typeId() == QMetaType::Bool)
        return value.toBool();
    const QString s = value.toString().trimmed().toLower();
    if (s == QLatin1String("true") || s == QLatin1String("1"))
        return true;
    if (s == QLatin1String("false") || s == QLatin1String("0"))
        return false;
    *ok = false;
    return false;
}

// The value written for `key`, or an invalid QVariant when it breaks the contract
QVariant validated(const QString &key, const QVariant &value)
{
    const QString text = value.toString().trimmed();
    auto oneOf = [&](const QStringList &list) { return list.contains(text) ? QVariant(text) : QVariant(); };
    bool ok = false;

    if (key == QLatin1String("mode"))
        return oneOf(Modes);
    if (key == QLatin1String("source"))
        return oneOf(Sources);
    if (key == QLatin1String("from"))
        return oneOf(FromLanguages);
    if (key == QLatin1String("to"))
        return oneOf(ToLanguages);
    if (key == QLatin1String("quality") || key == QLatin1String("voiceQuality"))
        return oneOf(Qualities);
    if (key == QLatin1String("sttModel"))
        return oneOf(SttModels);
    if (key == QLatin1String("sourceApp"))
        return text.left(200);
    if (key == QLatin1String("llmModel")) {
        static const QRegularExpression re(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$"));
        return re.match(text).hasMatch() ? QVariant(text) : QVariant();
    }
    if (key == QLatin1String("voice")) {
        if (text == QLatin1String("espeak"))
            return text;
        if (text.startsWith(QLatin1String("piper:"))) {
            const QString path = text.mid(6);
            return QDir::isAbsolutePath(path) && path.endsWith(QLatin1String(".onnx")) ? QVariant(text) : QVariant();
        }
        if (text.startsWith(QLatin1String("profile:")))
            return validProfileName(text.mid(8)) ? QVariant(text) : QVariant();
        return {};
    }
    if (key == QLatin1String("duck")) {
        const double d = value.toDouble(&ok);
        return ok ? QVariant(qRound(qBound(0.1, d, 1.0) * 100) / 100.0) : QVariant();
    }
    if (key == QLatin1String("overlayFontScale")) {
        const double d = value.toDouble(&ok);
        return ok ? QVariant(qRound(qBound(0.5, d, 2.5) * 100) / 100.0) : QVariant();
    }
    if (key == QLatin1String("endSilenceMs")) {
        const int ms = qRound(value.toDouble(&ok));
        return ok ? QVariant(qBound(250, ms, 900)) : QVariant();
    }
    if (key == QLatin1String("showOriginal") || key == QLatin1String("debugPanel")) {
        const bool b = toBool(value, &ok);
        return ok ? QVariant(b) : QVariant();
    }
    return {};
}

qint64 pathSize(const QString &path)
{
    const QFileInfo info(path);
    if (!info.isDir() || info.isSymLink())
        return info.exists() ? info.size() : 0;
    qint64 total = 0;
    QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const QFileInfo file = it.fileInfo();
        if (!file.isSymLink())
            total += file.size();
    }
    return total;
}

QString sizeText(qint64 size)
{
    return QLocale().formattedDataSize(size, 1, QLocale::DataSizeSIFormat);
}

} // namespace

TranslateModule::TranslateModule(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    // The app (or a second Settings window) changed the config or added a profile
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
        loadConfig();
        watchFiles();
    });
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &dir) {
        if (dir == voicesDir()) {
            scanVoices();
        } else {
            loadConfig();
            watchFiles();
        }
    });
    refresh();
}

QString TranslateModule::configPath()
{
    return QDir::homePath() + QStringLiteral("/.config/lingmo/translate.conf");
}

QString TranslateModule::voicesDir()
{
    return QDir::homePath() + QStringLiteral("/.local/share/lingmo/voices");
}

QString TranslateModule::translateDataDir()
{
    return QDir::homePath() + QStringLiteral("/.local/share/lingmo/translate");
}

void TranslateModule::refresh()
{
    // what suits this computer (~/.config/lingmoos/hardware.conf, recomputed when the GPU changed)
    m_hw = HwProfile::current();
    const QString binary = QStandardPaths::findExecutable(QStringLiteral("lingmo-translate"));
    if (binary != m_appBinary) {
        m_appBinary = binary;
        emit appChanged();
    }
    loadConfig();
    scanVoices();
    scanModels();
    watchFiles();
}

void TranslateModule::watchFiles()
{
    const QStringList paths = {configPath(), QFileInfo(configPath()).absolutePath(), voicesDir()};
    for (const QString &path : paths) {
        if (QFileInfo::exists(path) && !m_watcher->files().contains(path) && !m_watcher->directories().contains(path))
            m_watcher->addPath(path);
    }
}

void TranslateModule::loadConfig()
{
    const QVariantMap defs = defaults();
    QSettings settings(configPath(), QSettings::IniFormat);
    settings.beginGroup(Group);
    QVariantMap config;
    for (auto it = defs.cbegin(); it != defs.cend(); ++it) {
        QVariant value;
        if (settings.contains(it.key()))
            value = validated(it.key(), settings.value(it.key()));
        config.insert(it.key(), value.isValid() ? value : it.value());
    }
    // the current mode's pair (the old global keys until lingmo-translate migrates them)
    const QString mode = config.value(QStringLiteral("mode")).toString();
    for (const QString &k : {QStringLiteral("from"), QStringLiteral("to")}) {
        QVariant value;
        for (const QString &stored : {mode + QLatin1Char('/') + k, k}) {
            if (!value.isValid() && settings.contains(stored))
                value = validated(k, settings.value(stored));
        }
        config.insert(k, value.isValid() ? value : QVariant(k == QLatin1String("from") ? defaultFrom(mode) : defaultTo(mode)));
    }
    // the source is per mode too (lingmo-translate: <mode>/source, the whole system by default)
    const QVariant source = validated(QStringLiteral("source"), settings.value(mode + QStringLiteral("/source")));
    config.insert(QStringLiteral("source"), source.isValid() ? source : QVariant(Sources.first()));

    // the translation and the speech model are per mode; not set, the hardware recommendation
    const HwProfile::ModePlan rec = m_hw.mode(mode);
    const QString recQuality = rec.quality.isEmpty() ? QStringLiteral("fast") : rec.quality;
    const QString recStt = rec.sttModel.isEmpty() ? SttModels.first() : rec.sttModel;
    QVariant quality = validated(QStringLiteral("quality"), settings.value(mode + QStringLiteral("/quality")));
    if (!quality.isValid() && settings.value(QStringLiteral("quality")).toString() == QLatin1String("fast"))
        quality = QStringLiteral("fast"); // the old global choice, until lingmo-translate moves it into each mode
    QVariant stt = validated(QStringLiteral("sttModel"), settings.value(mode + QStringLiteral("/sttModel")));
    if (!stt.isValid() && settings.value(QStringLiteral("sttModel")).toString() != SttModels.first())
        stt = validated(QStringLiteral("sttModel"), settings.value(QStringLiteral("sttModel")));
    config.insert(QStringLiteral("quality"), quality.isValid() ? quality : QVariant(recQuality));
    config.insert(QStringLiteral("sttModel"), stt.isValid() ? stt : QVariant(recStt));

    // the voice: dubbed listening has its own (piper only), speaking and calls share one
    QString recVoice;
    if (mode != QLatin1String("subtitles")) {
        if (rec.voice == QLatin1String("clone"))
            recVoice = firstReadyProfile();
        if (recVoice.isEmpty()) {
            const QString lang = mode == QLatin1String("call") ? (config.value(QStringLiteral("from")).toString() == QLatin1String("auto")
                                                                       ? QStringLiteral("en") : config.value(QStringLiteral("from")).toString())
                                                               : config.value(QStringLiteral("to")).toString();
            recVoice = piperFor(lang);
        }
    }
    const bool dubbed = mode == QLatin1String("dubbed");
    const QString voiceKey = dubbed ? QStringLiteral("dubbed/voice") : QStringLiteral("voice");
    QVariant voice = validated(QStringLiteral("voice"), settings.value(voiceKey));
    if (dubbed && voice.toString().startsWith(QLatin1String("profile:")))
        voice = QVariant();
    if (!voice.isValid())
        voice = !dubbed && recVoice.startsWith(QLatin1String("profile:")) ? recVoice : DefaultVoice;
    config.insert(QStringLiteral("voice"), voice);

    config.insert(QStringLiteral("recQuality"), recQuality);
    config.insert(QStringLiteral("recSttModel"), recStt);
    config.insert(QStringLiteral("recVoice"), recVoice);
    config.insert(QStringLiteral("recVoiceKind"), rec.voice);
    config.insert(QStringLiteral("cloneAllowed"), rec.cloneAllowed);
    config.insert(QStringLiteral("recVramMb"), rec.vramMb);
    config.insert(QStringLiteral("tier"), m_hw.tier);
    config.insert(QStringLiteral("gpuName"), m_hw.gpuName);
    config.insert(QStringLiteral("vramTotalMb"), m_hw.vramMb);
    config.insert(QStringLiteral("follows"), !settings.contains(mode + QStringLiteral("/quality")) && !settings.contains(mode + QStringLiteral("/sttModel"))
                                                 && (mode == QLatin1String("subtitles") || !settings.contains(voiceKey)));
    if (config != m_config) {
        m_config = config;
        emit configChanged();
        // The chosen voice may be one that isn't on the list
        scanVoices();
    }
}

void TranslateModule::setValue(const QString &key, const QVariant &value)
{
    static const QStringList derived = {QStringLiteral("recQuality"), QStringLiteral("recSttModel"), QStringLiteral("recVoice"),
                                        QStringLiteral("recVoiceKind"), QStringLiteral("cloneAllowed"), QStringLiteral("recVramMb"),
                                        QStringLiteral("tier"), QStringLiteral("gpuName"), QStringLiteral("vramTotalMb"), QStringLiteral("follows")};
    if (!m_config.contains(key) || derived.contains(key))
        return;
    const QVariant v = validated(key, value);
    if (!v.isValid() || v == m_config.value(key))
        return;
    const QString mode = m_config.value(QStringLiteral("mode")).toString();
    // dubbed listening speaks with piper only (a cloned voice and the AI translator don't fit together)
    if (key == QLatin1String("voice") && mode == QLatin1String("dubbed") && v.toString().startsWith(QLatin1String("profile:")))
        return;
    QDir().mkpath(QFileInfo(configPath()).absolutePath());
    {
        QSettings settings(configPath(), QSettings::IniFormat);
        settings.beginGroup(Group);
        // per mode, as lingmo-translate keeps them
        const bool perMode = key == QLatin1String("from") || key == QLatin1String("to") || key == QLatin1String("source")
            || key == QLatin1String("quality") || key == QLatin1String("sttModel");
        QString stored = perMode ? mode + QLatin1Char('/') + key : key;
        if (key == QLatin1String("voice") && mode == QLatin1String("dubbed"))
            stored = QStringLiteral("dubbed/voice");
        settings.setValue(stored, v);
        settings.endGroup();
        settings.sync();
        if (settings.status() != QSettings::NoError) {
            setError(tr("Could not save %1.").arg(configPath()));
            return;
        }
    }
    m_config.insert(key, v);
    emit configChanged();
    if (key == QLatin1String("mode") || key == QLatin1String("quality") || key == QLatin1String("sttModel") || key == QLatin1String("voice")
        || key == QLatin1String("from") || key == QLatin1String("to"))
        loadConfig(); // the new mode's values, what follows the recommendation
    if (key == QLatin1String("voice"))
        scanVoices();
    watchFiles();
}

void TranslateModule::useRecommended()
{
    const QString mode = m_config.value(QStringLiteral("mode")).toString();
    {
        QSettings settings(configPath(), QSettings::IniFormat);
        settings.beginGroup(Group);
        settings.remove(mode + QStringLiteral("/quality"));
        settings.remove(mode + QStringLiteral("/sttModel"));
        if (mode == QLatin1String("dubbed"))
            settings.remove(QStringLiteral("dubbed/voice"));
        else if (mode != QLatin1String("subtitles"))
            settings.remove(QStringLiteral("voice"));
        settings.endGroup();
        settings.sync();
    }
    loadConfig();
    scanVoices();
}

QString TranslateModule::firstReadyProfile()
{
    // the most recent profile that is ready, as lingmo-translate picks it
    const QFileInfoList dirs = QDir(voicesDir()).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time);
    for (const QFileInfo &dir : dirs) {
        if (!dir.isSymLink() && validProfileName(dir.fileName()) && QFileInfo::exists(dir.absoluteFilePath() + QStringLiteral("/conds-v3.pt")))
            return QStringLiteral("profile:") + dir.fileName();
    }
    return {};
}

QString TranslateModule::piperFor(const QString &lang)
{
    // the voice lingmo-translate speaks the language with when none is chosen
    if (lang == QLatin1String("pt")) {
        const QString system = QStringLiteral("/usr/share/piper-voices/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx");
        return QStringLiteral("piper:") + (QFileInfo::exists(system) ? system : translateDataDir() + QStringLiteral("/piper/pt_BR-faber-medium.onnx"));
    }
    if (lang == QLatin1String("en"))
        return QStringLiteral("piper:") + translateDataDir() + QStringLiteral("/piper/en_US-joe-medium.onnx");
    return QStringLiteral("espeak");
}

QString TranslateModule::piperLicense(const QString &onnx)
{
    QFile card(QFileInfo(onnx).absolutePath() + QStringLiteral("/MODEL_CARD"));
    if (!card.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    static const QRegularExpression re(QStringLiteral("^\\W*licen[cs]e\\s*:\\s*(.+)$"),
                                       QRegularExpression::CaseInsensitiveOption);
    while (!card.atEnd()) {
        const auto m = re.match(QString::fromUtf8(card.readLine()).trimmed());
        if (m.hasMatch())
            return m.captured(1).trimmed();
    }
    return {};
}

void TranslateModule::scanVoices()
{
    const QLocale locale;
    QVariantList voices;
    QVariantList profiles;

    // Piper voices: name like pt_BR-faber-medium
    static const QRegularExpression piperName(QStringLiteral("^([a-z]{2,3}_[A-Z]{2})-([^-]+)-(\\w+)$"));
    const QStringList piperDirs = {QStringLiteral("/usr/share/piper-voices"), translateDataDir() + QStringLiteral("/piper")};
    for (const QString &dir : piperDirs) {
        QDirIterator it(dir, {QStringLiteral("*.onnx")}, QDir::Files, QDirIterator::Subdirectories);
        QStringList files;
        while (it.hasNext())
            files << it.next();
        files.sort();
        for (const QString &file : std::as_const(files)) {
            const QString stem = QFileInfo(file).completeBaseName();
            const auto m = piperName.match(stem);
            QString name = stem;
            if (m.hasMatch()) {
                const QString speaker = m.captured(2);
                name = QStringLiteral("%1 (%2, %3)").arg(speaker.left(1).toUpper() + speaker.mid(1),
                                                         m.captured(1), m.captured(3));
            }
            voices << QVariantMap{{QStringLiteral("id"), QStringLiteral("piper:") + file},
                                  {QStringLiteral("name"), tr("Piper: %1").arg(name)},
                                  {QStringLiteral("kind"), QStringLiteral("piper")},
                                  {QStringLiteral("license"), piperLicense(file)},
                                  {QStringLiteral("ready"), true},
                                  {QStringLiteral("missing"), false}};
        }
    }

    voices << QVariantMap{{QStringLiteral("id"), QStringLiteral("espeak")},
                          {QStringLiteral("name"), tr("eSpeak NG (robotic)")},
                          {QStringLiteral("kind"), QStringLiteral("espeak")},
                          {QStringLiteral("license"), QString()},
                          {QStringLiteral("ready"), true},
                          {QStringLiteral("missing"), false}};

    // Cloned voice profiles
    const QFileInfoList dirs = QDir(voicesDir()).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo &dir : dirs) {
        const QString name = dir.fileName();
        if (!validProfileName(name) || dir.isSymLink())
            continue;
        QJsonObject json;
        QFile file(dir.absoluteFilePath() + QStringLiteral("/profile.json"));
        if (file.open(QIODevice::ReadOnly))
            json = QJsonDocument::fromJson(file.read(64 * 1024)).object();
        const bool ready = QFileInfo::exists(dir.absoluteFilePath() + QStringLiteral("/conds-v3.pt"));
        const bool hasWav = QFileInfo::exists(dir.absoluteFilePath() + QStringLiteral("/voice.wav"));
        const QString display = json.value(QStringLiteral("name")).toString(name);

        QString created;
        const QString iso = json.value(QStringLiteral("created")).toString();
        QDateTime when = QDateTime::fromString(iso, Qt::ISODateWithMs);
        if (!when.isValid())
            when = QDateTime::fromString(iso, Qt::ISODate);
        if (when.isValid())
            created = locale.toString(when.toLocalTime().date(), QLocale::ShortFormat);
        else if (const QDate d = QDate::fromString(iso, Qt::ISODate); d.isValid())
            created = locale.toString(d, QLocale::ShortFormat);

        const double seconds = json.value(QStringLiteral("seconds")).toDouble(0);
        profiles << QVariantMap{{QStringLiteral("name"), name},
                                {QStringLiteral("displayName"), display},
                                {QStringLiteral("created"), created},
                                {QStringLiteral("seconds"), seconds},
                                {QStringLiteral("lengthText"), seconds > 0 ? tr("%1 s").arg(locale.toString(seconds, 'f', seconds < 10 ? 1 : 0))
                                                                           : QString()},
                                {QStringLiteral("snrDb"), json.value(QStringLiteral("snrDb")).toDouble(0)},
                                {QStringLiteral("model"), json.value(QStringLiteral("model")).toString()},
                                {QStringLiteral("hasRecording"), hasWav},
                                {QStringLiteral("ready"), ready}};
        voices << QVariantMap{{QStringLiteral("id"), QStringLiteral("profile:") + name},
                              {QStringLiteral("name"), ready ? tr("Your voice: %1").arg(display)
                                                             : tr("Your voice: %1 (not ready)").arg(display)},
                              {QStringLiteral("kind"), QStringLiteral("profile")},
                              {QStringLiteral("license"), QString()},
                              {QStringLiteral("ready"), ready},
                              {QStringLiteral("missing"), false}};
    }

    // The configured voice is gone (removed package or profile): keep it visible
    const QString current = m_config.value(QStringLiteral("voice")).toString();
    bool found = false;
    for (const QVariant &v : std::as_const(voices))
        found = found || v.toMap().value(QStringLiteral("id")).toString() == current;
    if (!found && !current.isEmpty()) {
        QString label = current;
        if (current.startsWith(QLatin1String("piper:")))
            label = QFileInfo(current.mid(6)).completeBaseName();
        else if (current.startsWith(QLatin1String("profile:")))
            label = current.mid(8);
        voices.prepend(QVariantMap{{QStringLiteral("id"), current},
                                   {QStringLiteral("name"), tr("%1 (not found)").arg(label)},
                                   {QStringLiteral("kind"), current.section(QLatin1Char(':'), 0, 0)},
                                   {QStringLiteral("license"), QString()},
                                   {QStringLiteral("ready"), false},
                                   {QStringLiteral("missing"), true}});
    }

    if (voices != m_voices || profiles != m_profiles) {
        m_voices = voices;
        m_profiles = profiles;
        emit voicesChanged();
    }
}

void TranslateModule::scanModels()
{
    QList<ModelEntry> entries;

    // Whisper (shared with the Assistant and Lingmo Studio)
    const QDir whisper(AIModule::whisperModelsDir());
    QVariantList stt;
    for (const QString &id : SttModels) {
        stt << QVariantMap{{QStringLiteral("id"), id},
                           {QStringLiteral("installed"), whisper.exists(QStringLiteral("ggml-%1.bin").arg(id))}};
    }
    if (stt != m_sttModels)
        m_sttModels = stt;
    const QFileInfoList ggml = whisper.entryInfoList({QStringLiteral("ggml-*.bin")}, QDir::Files, QDir::Name);
    for (const QFileInfo &f : ggml) {
        const QString name = f.completeBaseName().mid(5);
        entries << ModelEntry{f.absoluteFilePath(), QStringLiteral("whisper"), name, false, -1};
    }

    // Opus-MT translation models, one directory per language pair
    const QDir models(translateDataDir() + QStringLiteral("/models"));
    static const QRegularExpression pair(QStringLiteral("^mt-([a-z]{2,3})-([a-z]{2,3})$"));
    const QFileInfoList mt = models.entryInfoList({QStringLiteral("mt-*")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &d : mt) {
        const auto m = pair.match(d.fileName());
        const QString name = m.hasMatch() ? QStringLiteral("%1 → %2").arg(m.captured(1), m.captured(2)) : d.fileName();
        entries << ModelEntry{d.absoluteFilePath(), QStringLiteral("mt"), name, true, -1};
    }

    const QFileInfo vad(models.filePath(QStringLiteral("silero_vad.onnx")));
    if (vad.isFile())
        entries << ModelEntry{vad.absoluteFilePath(), QStringLiteral("vad"), QStringLiteral("Silero VAD"), false, -1};

    const QFileInfo venv(translateDataDir() + QStringLiteral("/venv"));
    if (venv.isDir())
        entries << ModelEntry{venv.absoluteFilePath(), QStringLiteral("venv"), QString(), true, -1};

    // Keep the sizes already measured; measure again in the background
    for (ModelEntry &e : entries) {
        for (const ModelEntry &old : std::as_const(m_entries)) {
            if (old.key == e.key)
                e.size = old.size;
        }
    }
    m_entries = entries;
    m_measuring = !entries.isEmpty();
    publishModels();

    const int generation = ++m_measureGeneration;
    QStringList paths;
    for (const ModelEntry &e : std::as_const(entries))
        paths << e.key;
    auto *watcher = new QFutureWatcher<QList<qint64>>(this);
    connect(watcher, &QFutureWatcher<QList<qint64>>::finished, this, [this, watcher, generation, paths] {
        watcher->deleteLater();
        if (generation != m_measureGeneration)
            return;
        const QList<qint64> sizes = watcher->result();
        for (int i = 0; i < m_entries.size() && i < sizes.size(); ++i) {
            if (m_entries[i].key == paths.value(i))
                m_entries[i].size = sizes.at(i);
        }
        m_measuring = false;
        publishModels();
    });
    watcher->setFuture(QtConcurrent::run([paths] {
        QList<qint64> sizes;
        for (const QString &path : paths)
            sizes << pathSize(path);
        return sizes;
    }));
}

void TranslateModule::publishModels()
{
    QVariantList list;
    qint64 total = 0;
    for (const ModelEntry &e : std::as_const(m_entries)) {
        QString family;
        QString name = e.name;
        if (e.family == QLatin1String("whisper"))
            family = tr("Speech recognition (Whisper) · shared with the Assistant and Lingmo Studio");
        else if (e.family == QLatin1String("mt"))
            family = tr("Translation (Opus-MT)");
        else if (e.family == QLatin1String("vad"))
            family = tr("Speech detection");
        else {
            name = tr("Speech engine");
            family = tr("Python environment with Chatterbox (cloned voice) and the translation runtime");
        }
        if (e.size > 0)
            total += e.size;
        list << QVariantMap{{QStringLiteral("key"), e.key},
                            {QStringLiteral("family"), e.family},
                            {QStringLiteral("name"), name},
                            {QStringLiteral("detail"), family},
                            {QStringLiteral("sizeText"), e.size >= 0 ? sizeText(e.size) : QString()},
                            {QStringLiteral("shared"), e.family == QLatin1String("whisper")}};
    }
    m_models = list;
    m_totalSizeText = total > 0 ? sizeText(total) : QString();
    emit modelsChanged();
}

void TranslateModule::openApp(const QString &page)
{
    if (m_appBinary.isEmpty())
        return;
    QStringList args;
    if (page == QLatin1String("voices") || page == QLatin1String("models"))
        args << QStringLiteral("--page") << page;
    if (!QProcess::startDetached(m_appBinary, args))
        setError(tr("Could not open Live translation."));
}

void TranslateModule::removeProfile(const QString &name)
{
    if (!validProfileName(name))
        return;
    const QFileInfo dir(voicesDir() + QLatin1Char('/') + name);
    // Only a real directory right inside voicesDir() (never a symlink to elsewhere)
    if (!dir.isDir() || dir.isSymLink()
        || QFileInfo(dir.canonicalFilePath()).absolutePath() != QFileInfo(voicesDir()).canonicalFilePath())
        return;
    clearError();
    if (!QDir(dir.absoluteFilePath()).removeRecursively())
        setError(tr("Could not remove the voice profile %1.").arg(name));
    if (m_config.value(QStringLiteral("voice")).toString() == QStringLiteral("profile:") + name)
        setValue(QStringLiteral("voice"), DefaultVoice);
    scanVoices();
}

void TranslateModule::removeModel(const QString &key)
{
    for (const ModelEntry &e : std::as_const(m_entries)) {
        if (e.key != key)
            continue;
        clearError();
        const bool ok = e.isDir ? QDir(e.key).removeRecursively() : QFile::remove(e.key);
        if (!ok)
            setError(tr("Could not remove %1.").arg(e.key));
        scanModels();
        return;
    }
}

void TranslateModule::setError(const QString &text)
{
    m_errorText = text;
    emit messageChanged();
}

void TranslateModule::clearError()
{
    if (m_errorText.isEmpty())
        return;
    m_errorText.clear();
    emit messageChanged();
}
