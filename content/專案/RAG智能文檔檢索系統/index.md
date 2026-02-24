---
title: RAG 智能文檔檢索系統 - 從零打造企業級知識庫
tags: [RAG, NLP, Vector-Database, LLM, Document-Processing, Python]
created: 2025-10-12
status: 已完成
github: https://github.com/yourusername/rag-chunking-engine
---

# RAG 智能文檔檢索系統

## 專案簡介

為了建立公司內部招標文件知識庫，我從零開始打造了一套完整的 RAG（Retrieval-Augmented Generation）系統。由於市面上的向量資料庫分片效果不理想，特別是對於中文招標文件這種結構化文檔，我決定自己開發智能分片引擎，並結合本地語言模型，確保資料安全性。

整個專案在一天內完成核心功能，現已達到生產就緒狀態。

## 主要功能

- **智能文檔分片**：自主開發 ProposalChunker，專門處理中文招標文件的階層式結構
- **兩階段檢索**：結合向量檢索與 Reranking，顯著提升檢索準確度
- **語義向量檢索**：使用 bge-small-zh-v1.5 中文優化模型，提供精準的語義搜尋
- **本地 LLM 問答**：整合 Ollama 實現完整的 RAG 問答系統，資料不外洩
- **Web 介面**：基於 Streamlit 的友善 Web 介面，支援內網部署，團隊成員可共用
- **CLI 介面**：統一命令列介面，適合開發和測試使用

## 核心亮點

### 1. ProposalChunker 智能分片引擎

專門針對中文招標文件開發的分片策略：

- **特殊區域識別**：自動識別並完整保留封面、評選表、目次、圖表目錄
- **階層式標題解析**：支援「壹貳參」、「一二三」、「(一)(二)」、「1.2.3.」四層標題
- **章節路徑追蹤**：維護完整的章節階層關係，如「參、專案需求規劃 > 二. 數位雙生系統 > 1. 使用者介面層」
- **智能長度控制**：自動分割過長章節但保留語義完整性

### 2. 兩階段檢索系統

創新的混合檢索策略：

- **第一階段（粗檢索）**：使用 Bi-Encoder (bge-small-zh-v1.5) 快速檢索 top 20 候選
- **第二階段（精排序）**：使用 Cross-Encoder (bge-reranker-v2-m3) 重新評分，精選 top 8
- **效果提升**：將最相關的結果排在前面，顯著提升答案品質

### 3. 完整的 RAG 流程

```
文檔輸入 → 智能分片 → 向量化 → ChromaDB 存儲 → 兩階段檢索 → LLM 生成答案
```

### 4. 性能表現

測試文檔（130 頁，65,000+ 字符）處理效率：

- 解析時間：~3 秒
- 分片時間：~1 秒（360 個分片）
- 向量化時間：~12 秒
- 查詢時間（兩階段）：
  - 向量檢索：~0.5 秒
  - Reranking：~0.5-1 秒
- LLM 回答：~3-5 秒
- **總計：從文檔到可問答 < 20 秒**
- **單次問答：~5-7 秒（含 Reranking）**

## 技術棧

- **語言/框架**：Python 3.12.3, Preact (前端規劃中)
- **文檔處理**：pdfplumber, PyPDF2, python-docx
- **向量化**：sentence-transformers (BAAI/bge-small-zh-v1.5)
- **Reranking**：CrossEncoder (BAAI/bge-reranker-v2-m3)
- **向量資料庫**：ChromaDB (持久化存儲)
- **LLM**：Ollama (llama3.1)
- **AI 協作工具**：Claude Code, GitHub Copilot

## 系統架構

```
┌─────────────────────────────────────────────────────────┐
│                   RAG 系統架構                            │
└─────────────────────────────────────────────────────────┘

文檔輸入 (PDF/Word/TXT)
    ↓
┌──────────────────┐
│  文檔解析層       │ → PDFParser / WordParser
│  - 提取文本       │
│  - 識別結構       │
└──────────────────┘
    ↓
┌──────────────────┐
│  智能分片層       │ → ProposalChunker ⭐
│  - 特殊區域識別   │
│  - 階層式切分     │
└──────────────────┘
    ↓
┌──────────────────┐
│  向量化層         │ → bge-small-zh-v1.5
│  - 生成 embeddings│   (512 維向量)
└──────────────────┘
    ↓
┌──────────────────┐
│  向量資料庫       │ → ChromaDB
│  - 向量存儲       │
└──────────────────┘
    ↓
┌──────────────────┐
│  兩階段檢索層     │ → Bi-Encoder + Cross-Encoder
│  - 粗檢索 (top 20)│   bge-small-zh-v1.5
│  - 精排序 (top 8) │   bge-reranker-v2-m3 ⭐
└──────────────────┘
    ↓
┌──────────────────┐
│  LLM 問答層       │ → Ollama (本地部署)
│  - 生成答案       │
└──────────────────┘
```

## 開發日誌

1. [[DevLog/RAG智能文檔檢索系統/Phase-1|#1 智能分片引擎]] - 專為中文招標文件設計的 ProposalChunker
2. [[DevLog/RAG智能文檔檢索系統/Phase-2|#2 向量化與檢索]] - bge-small-zh-v1.5 + ChromaDB 整合
3. [[DevLog/RAG智能文檔檢索系統/Phase-3|#3 LLM 整合]] - Ollama 本地部署，完整 RAG 流程跑通
4. [[DevLog/RAG智能文檔檢索系統/Phase-4|#4 工程化整理]] - 輸出目錄整理與 CLI 體驗優化
5. [[DevLog/RAG智能文檔檢索系統/Phase-5|#5 Reranking 精排序]] - 兩階段檢索提升排序品質
6. [[DevLog/RAG智能文檔檢索系統/Phase-6|#6 Web 介面]] - Streamlit 打造團隊共用介面

## 技術挑戰

在開發過程中解決了 7 個關鍵技術難題：

1. **Windows UTF-8 編碼問題**：命令列預設不支援 UTF-8
2. **ProposalChunker 返回類型一致性**：統一 list 與 object 返回處理
3. **ChromaDB 中文命名限制**：使用 UUID 替代中文集合名稱
4. **ChromaDB metadata None 值問題**：過濾空值欄位
5. **UTF-8 Wrapper 衝突**：避免重複包裝導致 I/O 錯誤
6. **清屏文字位置偏移**：改用 ANSI escape codes
7. **Ollama 連接超時**：調整 timeout 適應首次模型載入

## 專案成果

- ✅ 完整的端到端 RAG 系統（分片 → 向量化 → 兩階段檢索 → 問答）
- ✅ 專為中文招標文件優化的分片策略
- ✅ 兩階段檢索系統，顯著提升檢索準確度
- ✅ 本地化部署，資料零外洩
- ✅ CLI 介面：適合開發和測試
- ✅ Web 介面：適合團隊內部使用（10 人規模）
- ✅ 生產就緒，可穩定處理企業文檔

## 相關連結

- GitHub: https://github.com/yourusername/rag-chunking-engine
- 技術文件：[PROJECT_OVERVIEW.md](https://github.com/yourusername/rag-chunking-engine/blob/main/PROJECT_OVERVIEW.md)
- 建置紀錄：完整技術細節請見開發日誌

---

返回 [[專案/index|所有專案]]
