/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "helpapps.h"

#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

HelpApps::HelpApps(QObject *parent)
    : QObject(parent)
{
}

bool HelpApps::installed(const QString &binary) const
{
    return !QStandardPaths::findExecutable(binary).isEmpty();
}

QString HelpApps::shortcutFor(const QString &exec) const
{
    QSettings shortcuts(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/lingmoglobalshortcutsrc"),
                        QSettings::IniFormat);
    for (const QString &group : shortcuts.childGroups()) {
        if (shortcuts.value(group + QStringLiteral("/Exec")).toString() == exec)
            return group;
    }
    return QString();
}

void HelpApps::launch(const QString &command) const
{
    QStringList args = QProcess::splitCommand(command);
    if (!args.isEmpty())
        QProcess::startDetached(args.takeFirst(), args);
}
