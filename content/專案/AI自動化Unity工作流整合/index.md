---
title: AI 自動化 Unity 工作流整合 - 讓 AI 理解你的專案
tags: [ai, unity, devops, jira, git, claude, automation]
created: 2025-10-13
status: 已完成
github: https://github.com/你的使用者名稱/assistant
---

# AI 自動化 Unity 工作流整合

## 專案簡介

這是一個關於**兩個 AI 自動化工具整合**的故事。我花了數月時間分別開發了兩個工具：

- **automation_tool**：通用 AI 自動化開發工具，擁有強大的專案理解和分析能力
- **jira_poller**：Unity 專案專用的自動化 Agent 系統，提供完整的 Jira + Git DevOps 整合

當我意識到**它們是為同一個目標設計**時，決定進行整合，最終創造出一個兼具 AI 智能和 DevOps 整合的完整工作流系統。

## 核心創新

### 1. AI Agent 自主探索專案

使用 Anthropic Tool Use API，讓 Claude 自主探索 Unity 專案：
- 讀取專案結構
- 搜尋相關代碼
- 理解現有架構
- 基於實際代碼生成設計

### 2. Jira 驅動的人機協作

完整的工作流整合：
```
Jira 任務 → AI 分析 → 人工審批 → AI 設計 → 人工審批 → 開發 → 測試
```

### 3. Git Worktree 隔離

每個 Jira 任務獨立的工作空間：
- 自動創建 Git Worktree
- AI 在隔離環境中探索
- 結果自動提交到 Git
- 審批後可 Merge

## 主要功能

### 智能需求分析
- 自動分析 Jira 任務描述
- 生成標準化的 9 章節需求文檔
- 支援人工反饋循環
- **文檔質量提升 5 倍**

### 深度系統設計
- AI Agent 自主探索 Unity 專案
- 10-20 次工具調用理解代碼
- 生成基於實際架構的 11 章節設計文檔
- **從占位符到 4800+ 字的質的飛躍**

### 完整 DevOps 整合
- Jira API 自動檢測任務
- Git Worktree 自動管理
- 每階段 Git Commit
- Jira 評論自動發表
- 人工審批指令（@approved/@rejected/@sendback/@restart）

### 優雅降級機制
三層降級策略確保系統穩定：
1. 優先使用 automation_tool 的深度分析
2. 降級使用傳統 AI Provider
3. 最終使用占位符確保流程繼續

## 技術棧

### automation_tool
- **語言**：Python 3.8+
- **AI SDK**：Anthropic Claude SDK
- **核心技術**：Tool Use API、Async/Await
- **模組**：RequirementAnalyzer、SystemDesigner

### jira_poller
- **語言**：Python 3.8+
- **整合**：Jira REST API、Git
- **架構**：Orchestrator 模式、Provider 模式
- **特色**：Git Worktree、人機協作

### 整合技術
- **方式**：直接引用（sys.path）
- **通訊**：Markdown 文檔交換
- **同步**：asyncio.run() 處理異步調用

## 整合成果

| 階段 | 整合前 | 整合後 | 提升 |
|------|--------|--------|------|
| 需求文檔 | ~500 字 | ~2500 字 | **5x** |
| 需求章節 | 6 章節 | 9 章節 | 1.5x |
| 設計文檔 | 占位符 | ~4800 字 | **∞** |
| 設計章節 | 0 | 11 章節 | **∞** |
| 專案理解 | 無 | 自動探索 | **質的飛躍** |
| AI 調用 | 1-2 次 | 10-20 次 | **10x** |

## 開發歷程

這個整合專案記錄了從構思到實現的完整過程：

1. [[專案/AI自動化Unity工作流整合/日誌/01-兩個工具的誕生|#1 兩個工具的誕生]] - automation_tool 和 jira_poller 的設計理念和技術架構
2. [[專案/AI自動化Unity工作流整合/日誌/02-整合設計與實施|#2 整合設計與實施]] - 如何將兩個工具優雅地整合在一起
3. [[專案/AI自動化Unity工作流整合/日誌/03-技術深度解析|#3 技術深度解析]] - 關鍵技術細節和整合亮點

## 工作流程示意

```mermaid
graph TB
    A[Jira 任務提交] --> B[jira_poller 檢測]
    B --> C[創建 Git Worktree]
    C --> D[automation_tool<br/>需求分析]
    D --> E[生成 9 章節需求]
    E --> F{人工審批}
    F -->|@approved| G[automation_tool<br/>系統設計]
    F -->|@rejected| D
    G --> H[AI 探索專案<br/>10-20 次工具調用]
    H --> I[生成 11 章節設計]
    I --> J{人工審批}
    J -->|@approved| K[開發階段]
    J -->|@rejected| G
    K --> L[測試階段]
    L --> M[完成]
```

## 相關連結

- **automation_tool**: [[專案/AI自動化Coding工具/index|AI 自動化 Coding 工具]]
- **jira_poller**: GitHub Repository（私有）
- **整合文檔**: `AUTOMATION_TOOL_INTEGRATION.md`

## 使用場景

### Unity 遊戲開發團隊
- 從 Jira 任務到代碼實現的全自動化
- AI 理解現有 Unity 專案結構
- 生成符合專案風格的設計方案

### 企業 DevOps 流程
- 標準化的需求和設計文檔
- 人工審批確保質量控制
- Git Worktree 隔離降低風險

### AI 輔助開發研究
- Tool Use API 的實際應用
- 多輪對話的專案探索
- AI Agent 自主性研究

## 技術亮點

### 1. 專案探索的迭代式對話

SystemDesigner 不是簡單地讀取文件，而是像人類開發者一樣：
```
第 1 輪：了解整體專案結構 (get_project_structure)
第 2 輪：搜尋相關類別 (search_code "MainMenu")
第 3 輪：讀取主要代碼 (read_file MainMenuController.cs)
第 4 輪：列出相關文件 (list_files Assets/Scripts/UI)
...
最多 30 輪對話
```

### 2. 優雅的異步處理

在同步代碼中調用異步 API：
```python
try:
    loop = asyncio.get_event_loop()
    if loop.is_running():
        # 已有事件循環，降級處理
        raise RuntimeError("Cannot use async")
except RuntimeError:
    # 創建新事件循環
    result = asyncio.run(async_function())
```

### 3. 反饋循環的自動整合

人工反饋自動附加到需求文件：
```python
if feedback:
    temp_content = f"{original_content}\n\n## 人工反饋\n{feedback}"
    # AI 重新分析時會看到反饋
```

## 未來展望

### 短期目標
- ✅ 需求分析整合（已完成）
- ✅ 系統設計整合（已完成）
- ⏳ 開發階段整合（進行中）
- ⏳ 測試階段整合（規劃中）

### 中期目標
- 將 automation_tool 打包成 pip package
- 支援更多專案類型（不限於 Unity）
- 實現真正的代碼生成和提交

### 長期願景
- 完全自動化的開發工作流
- AI Agent 獨立完成開發任務
- 人類只需審批關鍵決策

---

> "當兩個工具為同一個夢想設計時，整合不是妥協，而是協同創造出更強大的系統。"

返回 [[專案/index|所有專案]]
