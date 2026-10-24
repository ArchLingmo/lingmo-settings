#pragma once

#include <QObject>
#include <QVariantList>

namespace LingmoIntents {
class IntentRegistry;
}

// Settings › IA › "Ações dos apps": the actions (Lingmo Intents) each
// installed app offers, with a switch per app and per action. Writes
// intents_disabled_apps / intents_disabled in ai.conf, which every app's
// intents service checks on each call (docs/intents.md).
class AppActions : public QObject
{
    Q_OBJECT
    // false when Settings was built without liblingmo-intents
    Q_PROPERTY(bool available READ available CONSTANT)
    // [{app, name, icon, enabled, intents: [{id, title, description, capabilities, confirm, needsUI, enabled}]}]
    Q_PROPERTY(QVariantList apps READ apps NOTIFY changed)

public:
    explicit AppActions(QObject *parent = nullptr);

    bool available() const;
    QVariantList apps() const { return m_apps; }

    Q_INVOKABLE void setAppEnabled(const QString &app, bool enabled);
    Q_INVOKABLE void setIntentEnabled(const QString &id, bool enabled);

signals:
    void changed();

private:
    void rebuild();
    void writeList(const QString &key, const QString &item, bool remove);

    LingmoIntents::IntentRegistry *m_registry = nullptr;
    QVariantList m_apps;
};
