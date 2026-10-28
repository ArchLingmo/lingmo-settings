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

#ifndef OCRLANGUAGES_H
#define OCRLANGUAGES_H

#include <QAbstractListModel>
#include <QPointer>
#include <QProcess>
#include <QSet>

// Settings › Language › Reading languages (OCR): the tesseract-data-* packs.
// Listing, installing and removing go through lingmo-screenshot's tool
// (/usr/lib/lingmo-screenshot/lingmo-ocr-languages), the same one its "Ask
// about the screen" panel uses for its Install button, so both agree.
class OcrLanguages : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString busyText READ busyText NOTIFY busyChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY busyChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int toInstall READ toInstall NOTIFY selectionChanged)
    Q_PROPERTY(int toRemove READ toRemove NOTIFY selectionChanged)
    Q_PROPERTY(QString selectionSize READ selectionSize NOTIFY selectionChanged)
    Q_PROPERTY(int installedCount READ installedCount NOTIFY loadingChanged)
    Q_PROPERTY(QString recommended READ recommended CONSTANT)

public:
    enum Roles {
        CodeRole = Qt::UserRole + 1,
        NameRole,
        InstalledRole,
        SizeRole,          // download size, formatted
        RemovableRole,
        PopularRole,
        RecommendedRole,
        SelectedRole,
        GroupRole,         // "popular" or "all", for the list sections
    };

    explicit OcrLanguages(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool available() const;
    bool loading() const { return m_lister != nullptr; }
    bool busy() const { return m_worker != nullptr; }
    QString busyText() const { return m_busyText; }
    qreal progress() const { return m_progress; }
    QString filter() const { return m_filter; }
    void setFilter(const QString &filter);
    int toInstall() const;
    int toRemove() const;
    QString selectionSize() const;
    int installedCount() const;
    // The tesseract code of the system language ("por")
    QString recommended() const { return m_recommended; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void toggle(const QString &code);
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE void installSelected();
    Q_INVOKABLE void removeSelected();

    // The language in the UI language: "heb" → "Hebraico", "chi_tra" →
    // "Chinês (tradicional)", "deu_frak" → "Alemão (Fraktur)"
    static QString displayName(const QString &code, const QString &uiLocale);
    // The pack for a locale: pt_BR → por, zh_TW → chi_tra
    static QString codeForLocale(const QString &locale);
    static QString toolPath();

signals:
    void loadingChanged();
    void busyChanged();
    void filterChanged();
    void selectionChanged();
    // ok, and a message for a toast
    void finished(bool ok, const QString &message);

private:
    struct Pack {
        QString code;
        QString name;
        bool installed = false;
        qint64 download = 0;
        qint64 installedSize = 0;
        bool removable = false;
        bool popular = false;
    };

    void parse(const QByteArray &output);
    void rebuild();
    void run(const QString &verb, const QStringList &codes);

    QList<Pack> m_all;
    QList<int> m_visible;            // indexes into m_all, popular group first
    QSet<QString> m_selected;
    QString m_filter;
    QString m_recommended;
    QString m_uiLocale;
    QPointer<QProcess> m_lister;
    QPointer<QProcess> m_worker;
    QString m_busyText;
    qreal m_progress = 0;
};

#endif // OCRLANGUAGES_H
