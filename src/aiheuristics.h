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

#include <QString>
#include <QStringList>

// Pure helpers of the AI page, kept apart from AIModule so the unit tests
// (tests/tst_aiheuristics.cpp) link only Qt Core. Whisper models and the
// hardware they suit: whisperhw.h.
namespace AIHeuristics {

// Tag ids, in display order. The page shows them as badges (AIModule::tagText).
inline const QString TagTools = QStringLiteral("tools");
inline const QString TagThinking = QStringLiteral("thinking");
inline const QString TagHighlights = QStringLiteral("highlights");     // summaries / picking clips from a transcript
inline const QString TagFast = QStringLiteral("fast");
inline const QString TagAccurate = QStringLiteral("accurate");
inline const QString TagMultilingual = QStringLiteral("multilingual"); // good in Portuguese
inline const QString TagSubtitles = QStringLiteral("subtitles");       // speech to text (Whisper)

// Billions of parameters from Ollama's parameter_size ("7.6B", "494.03M") or,
// when that is empty, from the name ("qwen2.5:3b", "mixtral:8x7b", "gemma3:270m").
// Returns -1 when unknown.
double parameterBillions(const QString &name, const QString &parameterSize);

// Tags for an Ollama model. tools/thinking come from Ollama's capabilities;
// the rest is a heuristic on the family (name) and size.
QStringList modelTags(const QString &name, const QString &parameterSize,
                      bool embedding, bool tools, bool thinking);

} // namespace AIHeuristics
