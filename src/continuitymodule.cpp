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

#include "continuitymodule.h"

#include <QClipboard>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QGuiApplication>
#include <QJsonDocument>

static const QString kService = QStringLiteral("com.lingmo.Continuity");
static const QString kPath = QStringLiteral("/Continuity");
static const QString kInterface = QStringLiteral("com.lingmo.Continuity");

ContinuityModule::ContinuityModule(QObject *parent)
    : QObject(parent)
    , m_watcher(new QDBusServiceWatcher(kService, QDBusConnection::sessionBus(),
                                        QDBusServiceWatcher::WatchForOwnerChange, this))
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(kService, kPath, kInterface, QStringLiteral("StateChanged"), this, SLOT(onStateChanged(QString)));
    // The daemon came (back): ask again
    connect(m_watcher, &QDBusServiceWatcher::serviceOwnerChanged, this,
            [this](const QString &, const QString &, const QString &newOwner) {
        if (!newOwner.isEmpty())
            refresh();
    });
    refresh();
}

void ContinuityModule::refresh()
{
    auto *iface = QDBusConnection::sessionBus().interface();
    const bool registered = iface && iface->isServiceRegistered(kService);
    const bool activatable = iface && iface->activatableServiceNames().value().contains(kService);
    if (m_installed != (registered || activatable)) {
        m_installed = registered || activatable;
        emit stateChanged();
    }
    if (!m_installed)
        return;
    // Starts the daemon if it isn't running
    QDBusMessage msg = QDBusMessage::createMethodCall(kService, kPath, kInterface, QStringLiteral("State"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QString> reply = *w;
        if (!reply.isError())
            setStateJson(reply.value());
    });
}

void ContinuityModule::onStateChanged(const QString &json)
{
    setStateJson(json);
}

void ContinuityModule::setStateJson(const QString &json)
{
    const QVariantMap state = QJsonDocument::fromJson(json.toUtf8()).toVariant().toMap();
    if (state.isEmpty())
        return;
    m_state = state;
    m_ready = true;
    emit stateChanged();
}

void ContinuityModule::call(const QString &method, const QVariantList &args)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(kService, kPath, kInterface, method);
    msg.setArguments(args);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [](QDBusPendingCallWatcher *w) {
        w->deleteLater();
    });
}

void ContinuityModule::setEnabled(bool enabled)
{
    call(QStringLiteral("SetEnabled"), {enabled});
}

void ContinuityModule::setRole(const QString &role)
{
    call(QStringLiteral("SetRole"), {role});
}

void ContinuityModule::setLabel(const QString &label)
{
    call(QStringLiteral("SetLabel"), {label});
}

void ContinuityModule::setOption(const QString &key, const QVariant &value)
{
    const QString text = value.typeId() == QMetaType::Bool ? (value.toBool() ? QStringLiteral("true")
                                                                             : QStringLiteral("false"))
                                                           : value.toString();
    call(QStringLiteral("SetOption"), {key, text});
}

void ContinuityModule::addPeer(const QString &address)
{
    if (!address.trimmed().isEmpty())
        call(QStringLiteral("AddPeer"), {address.trimmed()});
}

void ContinuityModule::pair(const QString &key)
{
    call(QStringLiteral("Pair"), {key});
}

void ContinuityModule::cancelPairing()
{
    call(QStringLiteral("CancelPairing"));
}

void ContinuityModule::unpair(const QString &key)
{
    call(QStringLiteral("Unpair"), {key});
}

void ContinuityModule::removePeer(const QString &key)
{
    call(QStringLiteral("RemovePeer"), {key});
}

void ContinuityModule::setPosition(const QString &key, int x, int y)
{
    call(QStringLiteral("SetPosition"), {key, x, y});
}

void ContinuityModule::setServer(const QString &key)
{
    call(QStringLiteral("SetServer"), {key});
}

void ContinuityModule::discover()
{
    call(QStringLiteral("Discover"));
}

void ContinuityModule::copy(const QString &text)
{
    if (auto *clipboard = QGuiApplication::clipboard())
        clipboard->setText(text);
}
