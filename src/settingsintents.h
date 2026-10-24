#pragma once

// settings.open (Lingmo Intents) on com.lingmo.SettingsUI.Intents /Intents.
// `lingmo-settings --intents` (D-Bus activation) answers without a window and
// opens the page the usual way (lingmo-settings -m page[/section]).
namespace SettingsIntents {
bool requested(int argc, char *argv[]);
int run(int argc, char *argv[]);
}
