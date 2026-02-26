---
title: "#03 LLM 整合"
tags: [Ollama, LLM, RAG, Prompt Engineering]
created: 2025-10-12
phase: 3
---

> **Tech** Ollama, Llama 3.1, Python requests
>
> **AI** Claude Code

## 源起

向量檢索只能回傳相關片段，使用者還要自己讀。接 LLM 讓系統直接回答問題，才是完整的 RAG。

## 設計

LLM 選 Ollama + Llama 3.1。理由是資料安全（招標文件不能外洩）、零費用、本地部署。Prompt 模板存成獨立 Markdown 檔案，核心指令是「基於參考資料回答、找不到就說不知道、用繁體中文」。

流程：向量檢索 top 8 → 格式化成帶章節路徑的參考資料 → 塞進 prompt template → 呼叫 Ollama HTTP API → 回傳答案和來源引用。

動態模型選擇——從 Ollama API 讀可用模型列表讓使用者選，不寫死。

## 實現

**UTF-8 wrapper 衝突。** CLI 主程式和 QA 模組都設了 `sys.stdout` UTF-8 wrapper，import 的時候 stdout 被關掉了再 wrap 就炸。改成只在 `__main__` 才設定。

**Ollama timeout。** 首次查詢要載入模型到記憶體，預設 10 秒 timeout 不夠。改成 60 秒。

**清屏問題。** `print('\n' * 100)` 把文字推到底部要往上捲。改用 ANSI escape `\033[2J\033[H`。

所有功能整合到 `rag_cli.py` 統一入口：分片、向量化、查詢測試、AI 問答。

## 尾聲

| 項目 | 結果 |
|------|------|
| 向量檢索 | ~1 秒 |
| LLM 生成 | ~3-5 秒（首次 +10 秒載入） |
| 端到端 | ~4-6 秒 |
| 答案品質 | 基於檢索內容，幾乎無幻覺 |

RAG 的完整流程跑通了。問「數位雙生系統的架構」能回答出四層架構設計和各層技術細節，全部來自檢索到的分片。

