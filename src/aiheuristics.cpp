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

#include "aiheuristics.h"

#include <QRegularExpression>

namespace AIHeuristics {

namespace {

// Name without registry/user prefix, lowercase: "hf.co/bartowski/Qwen2.5-7B-GGUF:Q4" -> "qwen2.5-7b-gguf:q4"
QString baseName(const QString &name)
{
    QString n = name.trimmed().toLower();
    const int slash = n.lastIndexOf(QLatin1Char('/'));
    return slash >= 0 ? n.mid(slash + 1) : n;
}

bool isMultilingualFamily(const QString &n)
{
    // Families trained on many languages, Portuguese included (model cards on ollama.com).
    // llama3 (3.0) itself was English-first; 3.1+ lists Portuguese.
    static const QRegularExpression re(QStringLiteral(
        "^(qwen|gemma|mistral|mixtral|ministral|magistral|aya|command-?r|command-?a|gpt-oss|glm-?4|deepseek-v3)"
        "|^llama-?3[._-]?[1-9]|^llama-?4|^granite-?[3-9]"));
    return re.match(n).hasMatch();
}

// Models made for one narrow job: not for summarising a transcript
bool isSpecialist(const QString &n)
{
    static const QRegularExpression re(QStringLiteral(
        "code|coder|starcoder|embed|guard|shield|ocr|math|sqlcoder|bge|minilm|moondream|llava|-base\\b|:text"));
    return re.match(n).hasMatch();
}

} // namespace

double parameterBillions(const QString &name, const QString &parameterSize)
{
    static const QRegularExpression sizeRe(QStringLiteral("^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*([KMBT])"),
                                           QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch size = sizeRe.match(parameterSize);
    if (size.hasMatch()) {
        const double value = size.captured(1).toDouble();
        switch (size.captured(2).toUpper().at(0).unicode()) {
        case 'K': return value / 1e6;
        case 'M': return value / 1e3;
        case 'B': return value;
        case 'T': return value * 1e3;
        }
    }

    const QString n = baseName(name);
    // "8x7b": mixture of experts, total size
    static const QRegularExpression moeRe(QStringLiteral("(?<![0-9.])([0-9]+)x([0-9]+(?:\\.[0-9]+)?)b(?![a-z])"));
    const QRegularExpressionMatch moe = moeRe.match(n);
    if (moe.hasMatch())
        return moe.captured(1).toDouble() * moe.captured(2).toDouble();
    // The first "<n>b" / "<n>m" that isn't part of a version ("qwen2.5:3b" -> 3)
    static const QRegularExpression nameRe(QStringLiteral("(?<![0-9.])([0-9]+(?:\\.[0-9]+)?)([bm])(?![a-z])"));
    const QRegularExpressionMatch m = nameRe.match(n);
    if (m.hasMatch())
        return m.captured(2) == QLatin1String("m") ? m.captured(1).toDouble() / 1e3 : m.captured(1).toDouble();
    return -1;
}

QStringList modelTags(const QString &name, const QString &parameterSize, bool embedding, bool tools, bool thinking)
{
    QStringList tags;
    const QString n = baseName(name);
    if (n.startsWith(QLatin1String("whisper")))
        return {TagSubtitles};
    if (embedding)
        return tags;

    const double billions = parameterBillions(name, parameterSize);
    if (tools)
        tags << TagTools;
    if (thinking)
        tags << TagThinking;
    // Picking the best moments of a long transcript needs a capable instruct
    // model: ~3B and up, general purpose
    if (billions >= 2.9 && !isSpecialist(n))
        tags << TagHighlights;
    if (billions > 0 && billions <= 4.5)
        tags << TagFast;
    if (billions >= 12)
        tags << TagAccurate;
    if (isMultilingualFamily(n))
        tags << TagMultilingual;
    return tags;
}

} // namespace AIHeuristics
