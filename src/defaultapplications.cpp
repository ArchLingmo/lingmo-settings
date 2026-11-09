/*
 * Copyright (C) 2021 - 2026 LingmoOS Team.
 *
 * Author:     Kate Leet <kate@lingmoos.com>
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

#include "defaultapplications.h"

#include <QSettings>
#include <QVariantMap>

#include <KApplicationTrader>
#include <KService>

static const QString s_terminal = QStringLiteral("terminal");

DefaultApplications::DefaultApplications(QObject *parent)
    : QObject(parent)
{
    reload();
}

QList<DefaultApplications::Category> DefaultApplications::definitions() const
{
    return {
        {QStringLiteral("browser"), tr("Web Browser"),
         {QStringLiteral("x-scheme-handler/https"), QStringLiteral("x-scheme-handler/http"), QStringLiteral("text/html"),
          QStringLiteral("application/xhtml+xml")}},
        {QStringLiteral("email"), tr("Email Client"), {QStringLiteral("x-scheme-handler/mailto"), QStringLiteral("message/rfc822")}},
        {QStringLiteral("filemanager"), tr("File Manager"), {QStringLiteral("inode/directory")}},
        {s_terminal, tr("Terminal"), {}},
        {QStringLiteral("documents"), tr("Documents"),
         {QStringLiteral("application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
          QStringLiteral("application/msword"), QStringLiteral("application/vnd.oasis.opendocument.text"),
          QStringLiteral("application/rtf")}},
        {QStringLiteral("spreadsheets"), tr("Spreadsheets"),
         {QStringLiteral("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
          QStringLiteral("application/vnd.ms-excel"), QStringLiteral("application/vnd.oasis.opendocument.spreadsheet"),
          QStringLiteral("text/csv")}},
        {QStringLiteral("presentations"), tr("Presentations"),
         {QStringLiteral("application/vnd.openxmlformats-officedocument.presentationml.presentation"),
          QStringLiteral("application/vnd.ms-powerpoint"), QStringLiteral("application/vnd.oasis.opendocument.presentation")}},
        {QStringLiteral("pdf"), tr("PDF"), {QStringLiteral("application/pdf")}},
        {QStringLiteral("text"), tr("Text Editor"), {QStringLiteral("text/plain"), QStringLiteral("text/markdown")}},
        {QStringLiteral("images"), tr("Images"),
         {QStringLiteral("image/jpeg"), QStringLiteral("image/png"), QStringLiteral("image/gif"), QStringLiteral("image/webp"),
          QStringLiteral("image/bmp"), QStringLiteral("image/tiff"), QStringLiteral("image/svg+xml"),
          QStringLiteral("image/heif"), QStringLiteral("image/avif")}},
        {QStringLiteral("video"), tr("Videos"),
         {QStringLiteral("video/mp4"), QStringLiteral("video/x-matroska"), QStringLiteral("video/webm"),
          QStringLiteral("video/quicktime"), QStringLiteral("video/x-msvideo"), QStringLiteral("video/mpeg")}},
        {QStringLiteral("music"), tr("Music"),
         {QStringLiteral("audio/mpeg"), QStringLiteral("audio/flac"), QStringLiteral("audio/ogg"),
          QStringLiteral("audio/x-wav"), QStringLiteral("audio/mp4"), QStringLiteral("audio/x-vorbis+ogg")}},
        {QStringLiteral("archives"), tr("Archives"),
         {QStringLiteral("application/zip"), QStringLiteral("application/x-7z-compressed"),
          QStringLiteral("application/x-compressed-tar"), QStringLiteral("application/vnd.rar"),
          QStringLiteral("application/x-xz-compressed-tar")}},
    };
}

// Every app that opens one of the kind's types, the preferred ones first (the
// first is the current default); hidden helpers (NoDisplay) left out
QStringList DefaultApplications::candidates(const Category &category) const
{
    QStringList ids;
    if (category.id == s_terminal) {
        const KService::List terminals = KApplicationTrader::query([](const KService::Ptr &service) {
            return service->categories().contains(QLatin1String("TerminalEmulator"));
        });
        for (const KService::Ptr &service : terminals)
            ids << service->storageId();
        return ids;
    }

    for (const QString &mimeType : category.mimeTypes) {
        for (const KService::Ptr &service : KApplicationTrader::queryByMimeType(mimeType)) {
            if (!service->noDisplay() && !ids.contains(service->storageId()))
                ids << service->storageId();
        }
    }
    return ids;
}

void DefaultApplications::reload()
{
    m_categories.clear();
    m_apps.clear();

    QSettings lingmoDefaults(QStringLiteral("lingmoos"), QStringLiteral("defaultApps"));

    for (const Category &category : definitions()) {
        const QStringList ids = candidates(category);
        if (ids.isEmpty())
            continue;

        QString current;
        if (category.id == s_terminal) {
            // Not chosen yet: Lingmo's terminal when it's there (what the file manager
            // falls back to is the first one it finds)
            current = lingmoDefaults.value(s_terminal).toString();
            if (!ids.contains(current))
                current = ids.contains(QLatin1String("lingmo-terminal.desktop")) ? QStringLiteral("lingmo-terminal.desktop")
                                                                                  : ids.first();
        } else if (const KService::Ptr preferred = KApplicationTrader::preferredService(category.mimeTypes.first())) {
            current = preferred->storageId();
        }

        QVariantList apps;
        for (const QString &id : ids) {
            const KService::Ptr service = KService::serviceByStorageId(id);
            if (!service)
                continue;
            apps << QVariantMap{{QStringLiteral("name"), service->name()},
                                {QStringLiteral("icon"), service->icon()},
                                {QStringLiteral("id"), id}};
        }

        m_apps.insert(category.id, ids);
        m_categories << QVariantMap{{QStringLiteral("id"), category.id},
                                    {QStringLiteral("title"), category.title},
                                    {QStringLiteral("apps"), apps},
                                    {QStringLiteral("current"), ids.indexOf(current)}};
    }

    emit loadFinished();
}

void DefaultApplications::setDefault(const QString &category, int index)
{
    const QStringList ids = m_apps.value(category);
    if (index < 0 || index >= ids.size())
        return;

    if (category == s_terminal) {
        QSettings(QStringLiteral("lingmoos"), QStringLiteral("defaultApps")).setValue(s_terminal, ids.at(index));
        return;
    }

    const KService::Ptr service = KService::serviceByStorageId(ids.at(index));
    if (!service)
        return;

    // Every type of the kind the app opens (a browser takes http, https and HTML)
    for (const Category &definition : definitions()) {
        if (definition.id != category)
            continue;
        for (const QString &mimeType : definition.mimeTypes) {
            if (service->hasMimeType(mimeType))
                KApplicationTrader::setPreferredService(mimeType, service);
        }
    }
}
