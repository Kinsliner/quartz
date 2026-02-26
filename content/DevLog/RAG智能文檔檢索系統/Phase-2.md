---
title: "#02 向量化與檢索"
tags: [ChromaDB, Embedding, sentence-transformers]
created: 2025-10-12
phase: 2
---

> **Tech** ChromaDB, sentence-transformers, BAAI/bge-small-zh-v1.5
>
> **AI** Claude Code

## 源起

分片做完了，接下來要把文字轉成向量、存進向量資料庫、實現語義檢索。

## 設計

Embedding 模型選 BAAI/bge-small-zh-v1.5：專為中文優化、100MB 大小、512 維向量、CPU 就能跑。和通用英文模型比，中文專業術語的相似度分數差距明顯（0.58 vs 0.32）。

向量資料庫選 ChromaDB：API 簡單、內建持久化、Python 原生、適合中小型應用。360 個分片的規模不需要 Pinecone 或 Milvus 那種等級的東西。

## 實現

**ChromaDB 不吃中文 collection 名稱。** 只接受 `[a-zA-Z0-9._-]{3,63}`，招標文件的中文檔名直接報錯。改用 UUID 當 collection name，原始名稱存在 metadata 和 `vectordb_info.txt`。

**Metadata 不能有 None。** 有些 chunk 的 heading 或 page_number 是 None，ChromaDB 直接拒絕。插入前過濾掉 None 值。

360 個分片批次向量化約 12 秒，查詢回應約 1 秒。資料庫持久化在 `vectordb/` 目錄，重啟不用重跑。

## 尾聲

| 項目 | 結果 |
|------|------|
| 向量化耗時 | ~12 秒（360 chunks） |
| 查詢耗時 | ~1 秒 |
| 向量維度 | 512 |
| 資料庫大小 | ~5 MB |
| 記憶體 | ~1.5 GB（含模型） |

檢索效果不錯——問「系統架構」能準確找到架構相關的章節，相似度 0.67 左右。

