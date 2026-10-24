#include "appactions.h"

#include <QSettings>

#ifdef HAVE_LINGMO_INTENTS
#include <LingmoIntents/intentregistry.h>
#endif

static const QString DisabledApps = QStringLiteral("intents_disabled_apps");
static const QString DisabledIntents = QStringLiteral("intents_disabled");

AppActions::AppActions(QObject *parent)
    : QObject(parent)
{
#ifdef HAVE_LINGMO_INTENTS
    m_registry = new LingmoIntents::IntentRegistry(this);
    connect(m_registry, &LingmoIntents::IntentRegistry::changed, this, &AppActions::rebuild);
#endif
    rebuild();
}

bool AppActions::available() const
{
#ifdef HAVE_LINGMO_INTENTS
    return true;
#else
    return false;
#endif
}

void AppActions::rebuild()
{
    m_apps.clear();
#ifdef HAVE_LINGMO_INTENTS
    QSettings settings(QStringLiteral("lingmoos"), QStringLiteral("ai"));
    const QStringList offApps = settings.value(DisabledApps).toStringList();
    const QStringList offIntents = settings.value(DisabledIntents).toStringList();
    for (const LingmoIntents::IntentManifest &m : m_registry->manifests()) {
        QVariantList intents;
        for (const LingmoIntents::IntentInfo &i : m.intents) {
            intents << QVariantMap{{QStringLiteral("id"), i.id},
                                   {QStringLiteral("title"), i.titleText()},
                                   {QStringLiteral("description"), i.descriptionText()},
                                   {QStringLiteral("icon"), i.icon},
                                   {QStringLiteral("capabilities"), i.capabilities},
                                   {QStringLiteral("confirm"), i.needsConfirmation()},
                                   {QStringLiteral("needsUI"), i.needsUI},
                                   {QStringLiteral("enabled"), !offIntents.contains(i.id)}};
        }
        m_apps << QVariantMap{{QStringLiteral("app"), m.appId},
                              {QStringLiteral("name"), m.nameText()},
                              {QStringLiteral("icon"), m.icon},
                              {QStringLiteral("system"), m.system},
                              {QStringLiteral("enabled"), !offApps.contains(m.appId)},
                              {QStringLiteral("intents"), intents}};
    }
    std::sort(m_apps.begin(), m_apps.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(
                   b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
#endif
    emit changed();
}

void AppActions::writeList(const QString &key, const QString &item, bool remove)
{
    QSettings settings(QStringLiteral("lingmoos"), QStringLiteral("ai"));
    QStringList list = settings.value(key).toStringList();
    list.removeAll(item);
    if (!remove)
        list.append(item);
    settings.setValue(key, list);
    settings.sync();
    rebuild();
}

void AppActions::setAppEnabled(const QString &app, bool enabled)
{
    if (!app.isEmpty())
        writeList(DisabledApps, app, enabled);
}

void AppActions::setIntentEnabled(const QString &id, bool enabled)
{
    if (!id.isEmpty())
        writeList(DisabledIntents, id, enabled);
}
