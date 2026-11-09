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

#ifndef DEFAULTAPPLICATIONS_H
#define DEFAULTAPPLICATIONS_H

#include <QObject>
#include <QStringList>
#include <QVariantList>

// The app that opens each kind of thing (web links, e-mail, folders, documents,
// pictures...). Apps come from every XDG applications folder through KService
// (system, ~/.local, Flatpak); the choice is written to mimeapps.list for all the
// file types of the kind the app opens. The terminal is Lingmo's own setting.
class DefaultApplications : public QObject
{
    Q_OBJECT
    // [{id, title, apps: [{name, icon, id}], current}]
    Q_PROPERTY(QVariantList categories READ categories NOTIFY loadFinished)

public:
    explicit DefaultApplications(QObject *parent = nullptr);

    QVariantList categories() const { return m_categories; }

    Q_INVOKABLE void setDefault(const QString &category, int index);
    Q_INVOKABLE void reload();

signals:
    void loadFinished();

private:
    struct Category {
        QString id;
        QString title;
        QStringList mimeTypes;      // the first one decides which app is the current default
    };
    QList<Category> definitions() const;
    QStringList candidates(const Category &category) const;   // desktop ids (storage ids)

    QVariantList m_categories;
    QHash<QString, QStringList> m_apps;   // category id → desktop ids, in the combo box order
};

#endif // DEFAULTAPPLICATIONS_H
