/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef HELPAPPS_H
#define HELPAPPS_H

#include <QObject>

// Settings › Help & tips: which Lingmo apps are installed, the shortcut each one has
// right now (the user may have changed it) and opening them
class HelpApps : public QObject
{
    Q_OBJECT

public:
    explicit HelpApps(QObject *parent = nullptr);

    Q_INVOKABLE bool installed(const QString &binary) const;
    // The keys bound to `exec` in lingmoglobalshortcutsrc ("Meta+Shift+T"), empty when none
    Q_INVOKABLE QString shortcutFor(const QString &exec) const;
    Q_INVOKABLE void launch(const QString &command) const;
};

#endif
