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

#include "ocrlanguages.h"

#include <QCollator>
#include <QFileInfo>
#include <QLocale>
#include <QRegularExpression>

#include <unicode/locid.h>
#include <unicode/unistr.h>

#include <algorithm>

namespace {

const char *TOOL = "/usr/lib/lingmo-screenshot/lingmo-ocr-languages";

// The packs people ask for most (first in the list, in this order)
const QStringList POPULAR = {
    QStringLiteral("heb"), QStringLiteral("ara"), QStringLiteral("rus"), QStringLiteral("ukr"),
    QStringLiteral("chi_sim"), QStringLiteral("chi_tra"), QStringLiteral("jpn"), QStringLiteral("kor"),
    QStringLiteral("spa"), QStringLiteral("fra"), QStringLiteral("deu"), QStringLiteral("ita"),
    QStringLiteral("ell"), QStringLiteral("hin"), QStringLiteral("tha"),
};

QString icuLanguage(const QString &code, const QString &uiLocale)
{
    icu::Locale display(uiLocale.toUtf8().constData());
    icu::Locale locale(code.toUtf8().constData());
    icu::UnicodeString name;
    locale.getDisplayLanguage(display, name);
    std::string utf8;
    name.toUTF8String(utf8);
    const QString result = QString::fromStdString(utf8);
    // ICU returns the code itself when it doesn't know the language
    return result == code ? QString() : result;
}

QString capitalized(QString text)
{
    if (!text.isEmpty())
        text[0] = text.at(0).toUpper();
    return text;
}

// Folded for searching: lower case, no accents ("Árabe" matches "arabe")
QString folded(const QString &text)
{
    const QString d = text.normalized(QString::NormalizationForm_D).toLower();
    QString out;
    out.reserve(d.size());
    for (const QChar c : d) {
        if (c.category() != QChar::Mark_NonSpacing)
            out.append(c);
    }
    return out;
}

}

OcrLanguages::OcrLanguages(QObject *parent)
    : QAbstractListModel(parent)
    , m_uiLocale(QLocale().name())
{
    m_recommended = codeForLocale(m_uiLocale);
    refresh();
}

QString OcrLanguages::toolPath()
{
    const QString override = qEnvironmentVariable("LINGMO_OCR_LANGUAGES_TOOL");
    return override.isEmpty() ? QString::fromLatin1(TOOL) : override;
}

bool OcrLanguages::available() const
{
    return QFileInfo(toolPath()).isExecutable();
}

QString OcrLanguages::codeForLocale(const QString &locale)
{
    if (locale.startsWith(QLatin1String("zh"))) {
        const bool traditional = locale.contains(QLatin1String("TW")) || locale.contains(QLatin1String("HK"))
                || locale.contains(QLatin1String("Hant"));
        return traditional ? QStringLiteral("chi_tra") : QStringLiteral("chi_sim");
    }
    icu::Locale l(locale.toUtf8().constData());
    const QString iso3 = QString::fromLatin1(l.getISO3Language());
    // tesseract uses the terminology codes; ICU's ISO3 for these differ
    static const QHash<QString, QString> fix = {
        {QStringLiteral("nob"), QStringLiteral("nor")}, {QStringLiteral("zsm"), QStringLiteral("msa")},
    };
    return fix.value(iso3, iso3);
}

QString OcrLanguages::displayName(const QString &code, const QString &uiLocale)
{
    if (code.startsWith(QLatin1String("script/")))
        return tr("%1 script").arg(code.mid(7).replace(QLatin1Char('_'), QLatin1Char(' ')));
    if (code == QLatin1String("equ"))
        return tr("Math equations");
    if (code == QLatin1String("osd"))
        return tr("Script detection");
    if (code == QLatin1String("frk"))
        return tr("%1 (Fraktur)").arg(capitalized(icuLanguage(QStringLiteral("de"), uiLocale)));
    if (code.startsWith(QLatin1String("chi_"))) {
        const QString chinese = capitalized(icuLanguage(QStringLiteral("zh"), uiLocale));
        QString variant = code.contains(QLatin1String("_tra")) ? tr("%1 (traditional)").arg(chinese)
                                                               : tr("%1 (simplified)").arg(chinese);
        if (code.endsWith(QLatin1String("_vert")))
            variant = tr("%1, vertical").arg(variant);
        return variant;
    }

    QStringList parts = code.split(QLatin1Char('_'));
    const QString base = parts.takeFirst();
    QString name = capitalized(icuLanguage(base, uiLocale));
    if (name.isEmpty())
        name = base;
    for (const QString &suffix : std::as_const(parts)) {
        if (suffix == QLatin1String("vert"))
            name = tr("%1 (vertical)").arg(name);
        else if (suffix == QLatin1String("frak"))
            name = tr("%1 (Fraktur)").arg(name);
        else if (suffix == QLatin1String("old"))
            name = tr("%1 (old)").arg(name);
        else if (suffix == QLatin1String("cyrl"))
            name = tr("%1 (Cyrillic)").arg(name);
        else if (suffix == QLatin1String("latn"))
            name = tr("%1 (Latin)").arg(name);
        else
            name = QStringLiteral("%1 (%2)").arg(name, suffix);
    }
    return name;
}

int OcrLanguages::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_visible.size());
}

QVariant OcrLanguages::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_visible.size())
        return {};
    const Pack &p = m_all.at(m_visible.at(index.row()));
    switch (role) {
    case CodeRole: return p.code;
    case Qt::DisplayRole:
    case NameRole: return p.name;
    case InstalledRole: return p.installed;
    case SizeRole: return p.download > 0 ? QLocale().formattedDataSize(p.download, 1, QLocale::DataSizeTraditionalFormat)
                                         : QString();
    case RemovableRole: return p.removable;
    case PopularRole: return p.popular;
    case RecommendedRole: return p.code == m_recommended;
    case SelectedRole: return m_selected.contains(p.code);
    case GroupRole: return p.popular ? QStringLiteral("popular") : QStringLiteral("all");
    }
    return {};
}

QHash<int, QByteArray> OcrLanguages::roleNames() const
{
    return {
        {CodeRole, "code"}, {NameRole, "name"}, {InstalledRole, "installed"}, {SizeRole, "size"},
        {RemovableRole, "removable"}, {PopularRole, "popular"}, {RecommendedRole, "recommended"},
        {SelectedRole, "selected"}, {GroupRole, "group"},
    };
}

void OcrLanguages::setFilter(const QString &filter)
{
    if (filter == m_filter)
        return;
    m_filter = filter;
    emit filterChanged();
    rebuild();
}

void OcrLanguages::refresh()
{
    if (m_lister || !available())
        return;
    m_lister = new QProcess(this);
    connect(m_lister, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus status) {
        const QByteArray out = m_lister->readAllStandardOutput();
        m_lister->deleteLater();
        m_lister = nullptr;
        if (status == QProcess::NormalExit && exitCode == 0)
            parse(out);
        emit loadingChanged();
    });
    connect(m_lister, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || !m_lister)
            return;
        m_lister->deleteLater();
        m_lister = nullptr;
        emit loadingChanged();
    });
    m_lister->start(toolPath(), {QStringLiteral("list")});
    emit loadingChanged();
}

void OcrLanguages::parse(const QByteArray &output)
{
    QList<Pack> packs;
    const QList<QByteArray> lines = output.split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> cols = line.split('\t');
        if (cols.size() < 5)
            continue;
        Pack p;
        p.code = QString::fromUtf8(cols.at(0)).trimmed();
        if (p.code.isEmpty() || p.code == QLatin1String("osd"))
            continue;
        p.installed = cols.at(1) == "1";
        p.download = cols.at(2).toLongLong();
        p.installedSize = cols.at(3).toLongLong();
        p.removable = cols.at(4).trimmed() == "1";
        p.popular = POPULAR.contains(p.code) || p.code == m_recommended;
        p.name = displayName(p.code, m_uiLocale);
        packs.append(p);
    }

    QCollator collator{QLocale(m_uiLocale)};
    std::sort(packs.begin(), packs.end(), [&](const Pack &a, const Pack &b) {
        if (a.popular != b.popular)
            return a.popular;
        if (a.popular) {
            // The system language first, then the order of POPULAR
            if ((a.code == m_recommended) != (b.code == m_recommended))
                return a.code == m_recommended;
            return POPULAR.indexOf(a.code) < POPULAR.indexOf(b.code);
        }
        return collator.compare(a.name, b.name) < 0;
    });

    beginResetModel();
    m_all = packs;
    // Keep only selections that still make sense
    QSet<QString> still;
    for (const Pack &p : std::as_const(m_all)) {
        if (m_selected.contains(p.code) && (!p.installed || p.removable))
            still.insert(p.code);
    }
    m_selected = still;
    m_visible.clear();
    endResetModel();
    rebuild();
    emit selectionChanged();
}

void OcrLanguages::rebuild()
{
    beginResetModel();
    m_visible.clear();
    const QString needle = folded(m_filter.trimmed());
    for (int i = 0; i < m_all.size(); ++i) {
        const Pack &p = m_all.at(i);
        if (needle.isEmpty() || folded(p.name).contains(needle) || p.code.contains(needle))
            m_visible.append(i);
    }
    endResetModel();
}

void OcrLanguages::toggle(const QString &code)
{
    for (int row = 0; row < m_visible.size(); ++row) {
        const Pack &p = m_all.at(m_visible.at(row));
        if (p.code != code)
            continue;
        if (p.installed && !p.removable)
            return;   // needed by the system: never offered for removal
        if (m_selected.contains(code))
            m_selected.remove(code);
        else
            m_selected.insert(code);
        const QModelIndex i = index(row);
        emit dataChanged(i, i, {SelectedRole});
        emit selectionChanged();
        return;
    }
}

void OcrLanguages::clearSelection()
{
    if (m_selected.isEmpty())
        return;
    m_selected.clear();
    if (!m_visible.isEmpty())
        emit dataChanged(index(0), index(int(m_visible.size()) - 1), {SelectedRole});
    emit selectionChanged();
}

int OcrLanguages::toInstall() const
{
    int n = 0;
    for (const Pack &p : m_all)
        n += m_selected.contains(p.code) && !p.installed;
    return n;
}

int OcrLanguages::toRemove() const
{
    int n = 0;
    for (const Pack &p : m_all)
        n += m_selected.contains(p.code) && p.installed && p.removable;
    return n;
}

QString OcrLanguages::selectionSize() const
{
    qint64 bytes = 0;
    for (const Pack &p : m_all) {
        if (m_selected.contains(p.code) && !p.installed)
            bytes += p.download;
    }
    return bytes > 0 ? QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeTraditionalFormat) : QString();
}

int OcrLanguages::installedCount() const
{
    int n = 0;
    for (const Pack &p : m_all)
        n += p.installed;
    return n;
}

void OcrLanguages::installSelected()
{
    QStringList codes;
    for (const Pack &p : std::as_const(m_all)) {
        if (m_selected.contains(p.code) && !p.installed)
            codes << p.code;
    }
    run(QStringLiteral("install"), codes);
}

void OcrLanguages::removeSelected()
{
    QStringList codes;
    for (const Pack &p : std::as_const(m_all)) {
        if (m_selected.contains(p.code) && p.installed && p.removable)
            codes << p.code;
    }
    run(QStringLiteral("remove"), codes);
}

// One transaction for all of them, through the shared tool (polkit)
void OcrLanguages::run(const QString &verb, const QStringList &codes)
{
    if (m_worker || codes.isEmpty())
        return;
    m_worker = new QProcess(this);
    m_worker->setProcessChannelMode(QProcess::MergedChannels);
    m_progress = 0;
    m_busyText = tr("Waiting for authorization…");
    const bool installing = verb == QLatin1String("install");

    connect(m_worker, &QProcess::readyRead, this, [this, installing] {
        if (!m_worker)
            return;
        // "@@STEP install", "(2/3) installing tesseract-data-heb", " tesseract-data-heb… downloading…"
        static const QRegularExpression step(QStringLiteral("^\\((\\d+)/(\\d+)\\) (installing|removing) tesseract-data-(\\S+)"));
        while (m_worker->canReadLine()) {
            const QString line = QString::fromUtf8(m_worker->readLine()).trimmed();
            const QRegularExpressionMatch m = step.match(line);
            if (m.hasMatch()) {
                const int i = m.captured(1).toInt(), n = qMax(1, m.captured(2).toInt());
                m_progress = 0.3 + 0.7 * i / n;
                const QString name = displayName(m.captured(4), m_uiLocale);
                m_busyText = installing ? tr("Installing %1 (%2 of %3)…").arg(name).arg(i).arg(n)
                                        : tr("Removing %1 (%2 of %3)…").arg(name).arg(i).arg(n);
                emit busyChanged();
            } else if (line.contains(QLatin1String("downloading"))) {
                m_progress = qMax(m_progress, 0.15);
                m_busyText = tr("Downloading…");
                emit busyChanged();
            } else if (line.startsWith(QLatin1String("@@STEP install")) || line.startsWith(QLatin1String("@@STEP remove"))) {
                m_progress = qMax(m_progress, 0.05);
                m_busyText = installing ? tr("Installing…") : tr("Removing…");
                emit busyChanged();
            }
        }
    });
    connect(m_worker, &QProcess::finished, this, [this, installing, codes](int exitCode, QProcess::ExitStatus status) {
        const QByteArray rest = m_worker->readAll();
        m_worker->deleteLater();
        m_worker = nullptr;
        m_busyText.clear();
        m_progress = 0;
        emit busyChanged();
        const bool ok = status == QProcess::NormalExit && exitCode == 0;
        QString message;
        if (ok) {
            for (const QString &code : codes)
                m_selected.remove(code);
            message = installing ? tr("%n reading language(s) installed.", "", int(codes.size()))
                                 : tr("%n reading language(s) removed.", "", int(codes.size()));
        } else if (exitCode == 126 || exitCode == 127) {
            message = tr("The change was cancelled.");
        } else if (exitCode == 3 || rest.contains("@@ERROR protected")) {
            message = tr("This language is needed by the system and can't be removed.");
        } else if (rest.contains("@@ERROR lock")) {
            message = tr("Another installation is running. Try again when it finishes.");
        } else {
            message = installing ? tr("The reading languages could not be installed. Check the internet connection.")
                                 : tr("The reading languages could not be removed.");
        }
        emit selectionChanged();
        emit finished(ok, message);
        refresh();
    });
    connect(m_worker, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || !m_worker)
            return;
        m_worker->deleteLater();
        m_worker = nullptr;
        m_busyText.clear();
        emit busyChanged();
        emit finished(false, tr("The reading languages tool is missing. Reinstall lingmo-screenshots."));
    });

    m_worker->start(toolPath(), QStringList{verb} + codes);
    emit busyChanged();
}
