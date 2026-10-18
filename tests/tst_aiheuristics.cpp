/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "aiheuristics.h"

#include <QSet>
#include <QTest>

using namespace AIHeuristics;

class TestAIHeuristics : public QObject
{
    Q_OBJECT

private slots:
    void parameterBillions_data()
    {
        QTest::addColumn<QString>("name");
        QTest::addColumn<QString>("parameterSize");
        QTest::addColumn<double>("expected");

        QTest::newRow("ollama size") << "qwen2.5:7b" << "7.6B" << 7.6;
        QTest::newRow("millions") << "qwen2.5:0.5b" << "494.03M" << 0.49403;
        QTest::newRow("name only") << "llama3.2:3b" << "" << 3.0;
        QTest::newRow("name decimal") << "qwen3:0.6b" << "" << 0.6;
        QTest::newRow("name millions") << "gemma3:270m" << "" << 0.27;
        QTest::newRow("moe total") << "mixtral:8x7b" << "" << 56.0;
        QTest::newRow("moe active ignored") << "qwen3:30b-a3b" << "" << 30.0;
        QTest::newRow("hf name") << "hf.co/bartowski/Qwen2.5-14B-Instruct-GGUF:Q4_K_M" << "" << 14.0;
        QTest::newRow("unknown") << "mistral:latest" << "" << -1.0;
    }

    void parameterBillions()
    {
        QFETCH(QString, name);
        QFETCH(QString, parameterSize);
        QFETCH(double, expected);
        QVERIFY2(qAbs(AIHeuristics::parameterBillions(name, parameterSize) - expected) < 0.001,
                 qPrintable(QString::number(AIHeuristics::parameterBillions(name, parameterSize))));
    }

    void modelTags_data()
    {
        QTest::addColumn<QString>("name");
        QTest::addColumn<QString>("parameterSize");
        QTest::addColumn<bool>("embedding");
        QTest::addColumn<bool>("tools");
        QTest::addColumn<bool>("thinking");
        QTest::addColumn<QStringList>("expected");

        QTest::newRow("qwen3 8b") << "qwen3:8b" << "8.2B" << false << true << true
                                  << QStringList{TagTools, TagThinking, TagHighlights, TagMultilingual};
        QTest::newRow("llama3.2 3b") << "llama3.2:3b" << "3.2B" << false << true << false
                                     << QStringList{TagTools, TagHighlights, TagFast, TagMultilingual};
        QTest::newRow("llama3 8b english") << "llama3:8b" << "8.0B" << false << false << false
                                           << QStringList{TagHighlights};
        QTest::newRow("gemma3 1b") << "gemma3:1b" << "999.89M" << false << false << false
                                   << QStringList{TagFast, TagMultilingual};
        QTest::newRow("gemma3 12b") << "gemma3:12b" << "12.2B" << false << false << false
                                    << QStringList{TagHighlights, TagAccurate, TagMultilingual};
        QTest::newRow("mistral-small 24b") << "mistral-small:24b" << "24B" << false << true << false
                                           << QStringList{TagTools, TagHighlights, TagAccurate, TagMultilingual};
        QTest::newRow("coder") << "qwen2.5-coder:7b" << "7.6B" << false << true << false
                               << QStringList{TagTools, TagMultilingual};
        QTest::newRow("granite3.3") << "granite3.3:2b" << "2.5B" << false << true << true
                                    << QStringList{TagTools, TagThinking, TagFast, TagMultilingual};
        QTest::newRow("phi4") << "phi4:14b" << "14.7B" << false << false << false
                              << QStringList{TagHighlights, TagAccurate};
        QTest::newRow("embedding") << "nomic-embed-text:latest" << "137M" << true << false << false << QStringList{};
        QTest::newRow("whisper") << "whisper-large-v3" << "" << false << false << false << QStringList{TagSubtitles};
    }

    void modelTags()
    {
        QFETCH(QString, name);
        QFETCH(QString, parameterSize);
        QFETCH(bool, embedding);
        QFETCH(bool, tools);
        QFETCH(bool, thinking);
        QFETCH(QStringList, expected);
        QCOMPARE(AIHeuristics::modelTags(name, parameterSize, embedding, tools, thinking), expected);
    }
};

QTEST_GUILESS_MAIN(TestAIHeuristics)
#include "tst_aiheuristics.moc"
