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
#include <QVariantMap>

class QDBusServiceWatcher;

// Settings › Shared Keyboard and Mouse: a thin front for lingmo-continuityd
// (package lingmo-continuity), which runs Deskflow, finds and pairs the other
// computers and keeps the state. Everything goes over D-Bus
// (com.lingmo.Continuity, /Continuity); D-Bus starts the daemon when needed.
class ContinuityModule : public QObject
{
    Q_OBJECT
    // lingmo-continuity is installed (its D-Bus service can be started)
    Q_PROPERTY(bool installed READ installed NOTIFY stateChanged)
    // The daemon answered at least once
    Q_PROPERTY(bool ready READ ready NOTIFY stateChanged)
    // Everything the daemon reports (see lingmo-continuity's com.lingmo.Continuity.xml)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)

public:
    explicit ContinuityModule(QObject *parent = nullptr);

    bool installed() const { return m_installed; }
    bool ready() const { return m_ready; }
    QVariantMap state() const { return m_state; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setEnabled(bool enabled);
    Q_INVOKABLE void setRole(const QString &role);
    Q_INVOKABLE void setLabel(const QString &label);
    Q_INVOKABLE void setOption(const QString &key, const QVariant &value);
    Q_INVOKABLE void addPeer(const QString &address);
    Q_INVOKABLE void pair(const QString &key);
    Q_INVOKABLE void cancelPairing();
    Q_INVOKABLE void unpair(const QString &key);
    Q_INVOKABLE void removePeer(const QString &key);
    Q_INVOKABLE void setPosition(const QString &key, int x, int y);
    Q_INVOKABLE void setServer(const QString &key);
    Q_INVOKABLE void discover();
    Q_INVOKABLE void copy(const QString &text);

signals:
    void stateChanged();

private slots:
    void onStateChanged(const QString &json);

private:
    void call(const QString &method, const QVariantList &args = {});
    void setStateJson(const QString &json);

    QVariantMap m_state;
    bool m_installed = false;
    bool m_ready = false;
    QDBusServiceWatcher *m_watcher;
};
