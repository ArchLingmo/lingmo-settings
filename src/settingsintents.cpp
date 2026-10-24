#ifdef HAVE_LINGMO_INTENTS
#include "settingsintents.h"

#include <LingmoIntents/intentservice.h>

#include <QCoreApplication>

using LingmoIntents::IntentCall;
using LingmoIntents::IntentResult;

namespace SettingsIntents {

bool requested(int argc, char *argv[])
{
    return argc == 2 && qstrcmp(argv[1], "--intents") == 0;
}

int run(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    LingmoIntents::IntentService intents(QStringLiteral("lingmo-settings"));
    intents.handle(QStringLiteral("settings.open"), [](const IntentCall &call) {
        // page is one of the enum values and section matches [a-z0-9_-]* (checked by the schema)
        QString page = call.params().value(QStringLiteral("page")).toString();
        const QString section = call.params().value(QStringLiteral("section")).toString();
        if (!section.isEmpty())
            page += QLatin1Char('/') + section;
        QString error;
        if (!LingmoIntents::spawnDetached(QStringLiteral("lingmo-settings"), {QStringLiteral("-m"), page}, &error))
            return IntentResult::failed(error);
        return IntentResult::ok({{QStringLiteral("page"), page}});
    });
    if (!intents.publish(LingmoIntents::IntentService::Headless))
        return 1;
    intents.setIdleQuit(20000);
    return app.exec();
}

}
#endif
