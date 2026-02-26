---
title: "#05 Reranking 精排序"
tags: [Cross-Encoder, Reranking, Information Retrieval]
created: 2025-10-12
phase: 5
---

> **Tech** sentence-transformers CrossEncoder, BAAI/bge-reranker-v2-m3
>
> **AI** Claude Code

## 源起

向量檢索（Bi-Encoder）能找到相關內容，但排序不夠精確——最相關的結果不一定排最前面，這直接影響餵給 LLM 的上下文品質。

## 設計

兩階段檢索：第一階段用 Bi-Encoder（bge-small-zh-v1.5）快速召回 top 20 候選，第二階段用 Cross-Encoder（bge-reranker-v2-m3）對 20 個候選逐一評分，取最相關的 top 8 給 LLM。

Bi-Encoder 把 query 和 document 分開編碼再比餘弦距離，速度快但精度有限。Cross-Encoder 把 query-document 對一起餵進去算相關性分數，精度高但慢。兩者結合剛好：大範圍用快的撈、小範圍用準的排。

參數設 initial_k=20、final_k=8。20 個候選夠涵蓋相關內容，8 個分片約 3000-5000 字不會讓 LLM prompt 太長。

## 實現

實作上是把舊的 `vector_search(query, top_k=8)` 內部替換成兩階段流程，外部 API 不變，其他程式碼不用改。

每個結果同時保留 vector_similarity 和 rerank_score 兩個分數，方便除錯和分析。實測 Rerank 分數的區間（0.76-0.92）比向量相似度（0.63-0.69）差異更明顯，更容易區分相關性。

Reranking 增加約 0.5 秒，整體問答時間從 4-6 秒變成 5-7 秒，可以接受。

## 尾聲

| 項目 | 結果 |
|------|------|
| Reranker 模型 | bge-reranker-v2-m3（~560 MB） |
| 增加耗時 | ~0.5 秒 |
| 檢索流程 | top 20 → rerank → top 8 |
| 記憶體增加 | ~800 MB |

排序品質提升明顯，最相關的結果確實排到了前面。0.5 秒換更好的答案品質，值得。

