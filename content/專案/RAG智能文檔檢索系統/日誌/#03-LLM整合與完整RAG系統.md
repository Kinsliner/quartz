---
title: "#03 LLM 整合與完整 RAG 系統"
tags: [RAG, LLM, Ollama, AI, Prompt-Engineering]
created: 2025-10-12
---

# 開發日誌 #3：LLM 整合與完整 RAG 系統

有了智能分片和向量檢索，現在要整合 LLM 來完成最後一塊拼圖：讓系統能真正「回答問題」。

傳統的向量檢索只能返回相關片段，用戶還需要自己閱讀和理解。而 RAG 系統則能：

1. 檢索相關內容（Retrieval）
2. 增強上下文（Augmentation）
3. 生成自然語言答案（Generation）

這就是 RAG 的完整形態！

## 技術選型：為什麼選 Ollama？

### 需求分析

對於企業內部知識庫系統，我們有以下考量：

- ✅ **資料安全**：文檔內容不能外洩，必須本地部署
- ✅ **成本控制**：不想每次查詢都花錢（OpenAI API 按量計費）
- ✅ **自主可控**：不依賴外部服務的可用性
- ✅ **易於部署**：希望安裝簡單，維護容易

### Ollama 的優勢

**Ollama** 是一個本地 LLM 運行環境，類似 Docker 但專為 LLM 設計：

✅ **一鍵安裝**：`curl https://ollama.ai/install.sh | sh`
✅ **模型豐富**：支援 Llama 3.1, Mistral, Gemma 等主流開源模型
✅ **API 簡潔**：HTTP API 設計簡單，易於整合
✅ **資源友善**：支援 CPU 運行，也能利用 GPU 加速
✅ **完全免費**：開源且無需 API key

**我選擇的模型**：llama3.1:latest (4.7 GB)

```bash
# 安裝 Ollama
curl https://ollama.ai/install.sh | sh

# 拉取模型
ollama pull llama3.1

# 啟動服務（自動在背景運行）
ollama serve
```

## RAG 問答系統設計

### 工作流程

```
用戶問題: "數位雙生系統的架構是什麼？"
    ↓
┌─────────────────────────┐
│ 1. 向量檢索              │
│    查詢向量資料庫        │
│    取得 top 8 相關分片   │
└─────────────────────────┘
    ↓
┌─────────────────────────┐
│ 2. 上下文組合            │
│    將分片內容整理成      │
│    結構化的參考資料      │
└─────────────────────────┘
    ↓
┌─────────────────────────┐
│ 3. Prompt 構建          │
│    使用模板組合          │
│    {context} + {query}  │
└─────────────────────────┘
    ↓
┌─────────────────────────┐
│ 4. LLM 生成             │
│    呼叫 Ollama API      │
│    生成自然語言答案      │
└─────────────────────────┘
    ↓
┌─────────────────────────┐
│ 5. 答案返回             │
│    顯示答案 + 來源引用   │
└─────────────────────────┘
```

### 核心實作

#### 1. 動態模型選擇

不寫死模型名稱，從 Ollama 動態讀取可用模型：

```python
def get_available_models() -> list:
    """從 Ollama 獲取可用模型列表"""
    try:
        response = requests.get('http://localhost:11434/api/tags', timeout=5)
        if response.status_code == 200:
            data = response.json()
            return [model['name'] for model in data.get('models', [])]
    except:
        return []

def select_model():
    """讓用戶選擇模型"""
    models = get_available_models()

    if not models:
        print("❌ 找不到可用的 Ollama 模型")
        print("請先執行: ollama pull llama3.1")
        return None

    print("\n📋 可用模型:")
    for i, model in enumerate(models, 1):
        print(f"  {i}. {model}")

    choice = int(input("\n請選擇模型 (輸入編號): "))
    return models[choice - 1]
```

#### 2. Prompt 模板設計

將 Prompt 存在獨立的 Markdown 檔案中，方便調整優化：

**prompts/rag_prompt.md**：

```markdown
你是一個專業的文檔助理，專門協助用戶理解招標文件和服務建議書。

請根據以下參考資料回答用戶的問題：

## 參考資料

{context}

## 用戶問題

{query}

## 回答指引

1. 請基於參考資料回答，不要編造內容
2. 如果參考資料中找不到答案，請誠實告知
3. 回答要結構清晰，使用條列式或段落分明的方式
4. 如果適用，可以引用參考資料中的具體內容
5. 使用繁體中文回答

請開始回答：
```

**載入 Prompt 模板**：

```python
def load_prompt_template() -> str:
    """載入 Prompt 模板"""
    with open('prompts/rag_prompt.md', 'r', encoding='utf-8') as f:
        return f.read()

def build_prompt(context: str, query: str) -> str:
    """構建完整 Prompt"""
    template = load_prompt_template()
    return template.replace('{context}', context).replace('{query}', query)
```

#### 3. 上下文格式化

將檢索到的 8 個分片整理成結構化格式：

```python
def format_context(results: dict) -> str:
    """格式化檢索結果為上下文"""
    documents = results['documents'][0]
    metadatas = results['metadatas'][0]

    context_parts = []
    for i, (doc, meta) in enumerate(zip(documents, metadatas), 1):
        section = meta.get('section', '未知章節')
        heading = meta.get('heading', '')

        context_parts.append(f"""
### 參考資料 {i}
章節: {section}
{f'標題: {heading}' if heading else ''}

內容:
{doc}
""")

    return '\n'.join(context_parts)
```

#### 4. Ollama API 呼叫

```python
def query_ollama(model: str, prompt: str) -> str:
    """呼叫 Ollama API 生成答案"""
    url = 'http://localhost:11434/api/generate'

    payload = {
        'model': model,
        'prompt': prompt,
        'stream': False  # 不使用串流模式，一次返回完整答案
    }

    try:
        response = requests.post(url, json=payload, timeout=60)
        if response.status_code == 200:
            data = response.json()
            return data['response']
        else:
            return f"❌ API 錯誤: {response.status_code}"
    except requests.Timeout:
        return "❌ 請求超時，模型可能正在載入..."
    except Exception as e:
        return f"❌ 發生錯誤: {str(e)}"
```

#### 5. 完整 RAG 問答流程

```python
def rag_query(chunks_folder: str, model: str, query: str):
    """完整的 RAG 查詢流程"""

    print(f"\n🔍 問題: {query}\n")

    # 1. 向量檢索
    print("📚 檢索相關資料...")
    results = vector_search(chunks_folder, query, top_k=8)

    # 2. 格式化上下文
    context = format_context(results)

    # 3. 顯示參考來源（簡化版）
    print("\n📖 參考資料來源:")
    for i, meta in enumerate(results['metadatas'][0], 1):
        section = meta.get('section', '未知章節')
        print(f"  {i}. {section}")

    # 4. 構建 Prompt
    prompt = build_prompt(context, query)

    # 5. 呼叫 LLM
    print("\n🤖 生成答案中...\n")
    answer = query_ollama(model, prompt)

    # 6. 顯示答案
    print("━" * 60)
    print(answer)
    print("━" * 60)
```

## 實測效果展示

### 測試案例 1：系統架構查詢

**問題**：「數位雙生智能火場鑑識輔助系統的架構是什麼？」

**參考資料來源**（簡化顯示）：
```
📖 參考資料來源:
  1. 參、專案需求規劃 > 一. 整體系統架構
  2. 參、專案需求規劃 > 二. 數位雙生智能火場鑑識輔助系統
  3. 參、專案需求規劃 > 二. 數位雙生智能火場鑑識輔助系統 > 1. 使用者介面層
  4. 參、專案需求規劃 > 二. 數位雙生智能火場鑑識輔助系統 > 2. 應用服務層
  5. 參、專案需求規劃 > 二. 數位雙生智能火場鑑識輔助系統 > 3. 資料存取層
  ...（共 8 個相關分片）
```

**LLM 回答**：

```
根據服務建議書，數位雙生智能火場鑑識輔助系統採用多層架構設計：

1. 使用者介面層 (Presentation Layer)
   - 提供 Web-based 操作介面
   - 支援火場鑑識人員進行案件管理、證據分析等功能
   - 響應式設計，支援多種裝置存取

2. 應用服務層 (Application Layer)
   - 使用 ASP.NET Core 架構建置
   - 提供標準化 RESTful API
   - 支援系統內部模組與外部平台整合

3. 資料存取層 (Data Access Layer)
   - 整合多種資料庫系統
   - 包含關聯式資料庫（SQL Server）
   - 以及 NoSQL 資料庫（MongoDB）用於非結構化資料

4. 基礎設施層 (Infrastructure Layer)
   - 包含雲端服務整合
   - 安全稽核機制
   - 資料治理與備份系統

整體架構強調模組化設計、可擴充性與異質系統整合能力，
確保系統能夠穩定運行並支援未來功能擴展。
```

**效果評估**：

✅ **準確性**：答案完全基於檢索到的內容，沒有虛構
✅ **結構性**：使用條列式呈現，層次分明
✅ **完整性**：涵蓋了四個主要架構層，並說明各層功能
✅ **專業性**：使用正確的技術術語（RESTful API, ASP.NET Core 等）
✅ **可追溯**：顯示參考來源，用戶可以驗證答案

### 測試案例 2：技術細節查詢

**問題**：「系統使用哪些技術棧？」

**LLM 回答**：

```
根據服務建議書，本系統採用以下技術棧：

前端技術:
- React.js - 使用者介面框架
- Bootstrap 5 - 響應式設計框架
- D3.js - 資料視覺化

後端技術:
- ASP.NET Core 6.0 - 應用服務框架
- Entity Framework Core - ORM 框架
- SignalR - 即時通訊

資料庫:
- Microsoft SQL Server 2019 - 關聯式資料庫
- MongoDB - NoSQL 文件資料庫
- Redis - 快取系統

雲端服務:
- Azure App Service - 應用程式託管
- Azure Blob Storage - 物件儲存
- Azure CDN - 內容傳遞網路

這些技術的選擇考慮了系統的穩定性、擴展性和開發效率。
```

## 技術難題與解決

### 難題 5：UTF-8 Wrapper 衝突

**問題描述**：

當 `rag_cli.py` 和 `rag_qa.py` 都設置 UTF-8 wrapper 時會衝突：

```python
# rag_cli.py
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# rag_qa.py 被 import 時
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
# 💥 錯誤: I/O operation on closed file
```

**解決方案**：

只在模組單獨運行時設置 wrapper：

```python
# rag_qa.py
if __name__ == '__main__' and sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')
```

### 難題 6：清屏文字顯示位置

**問題描述**：

使用 `print('\n' * 100)` 清屏會把文字推到螢幕下方，需要往上捲才能看到。

**解決方案**：

改用 ANSI escape codes：

```python
def clear_screen():
    """清除螢幕並將游標移到頂部"""
    print('\033[2J\033[H', end='')  # ANSI escape: 清屏 + 移動游標
```

這樣畫面會清空，且文字從螢幕頂部開始顯示。

### 難題 7：Ollama 連接超時

**問題描述**：

首次查詢時，Ollama 需要載入模型到記憶體，10 秒 timeout 不夠：

```python
requests.exceptions.ReadTimeout: HTTPConnectionPool(...): Read timed out. (read timeout=10)
```

**解決方案**：

將 timeout 增加到 60 秒：

```python
response = requests.post(
    'http://localhost:11434/api/generate',
    json=payload,
    timeout=60  # 給予充足的模型載入時間
)
```

## 系統整合：統一 CLI 介面

為了提供完整的用戶體驗，我將所有功能整合到 `rag_cli.py`：

```python
def main():
    """主選單"""
    while True:
        clear_screen()
        print("=" * 60)
        print("         RAG 智能文檔檢索系統")
        print("=" * 60)
        print("\n請選擇功能:\n")
        print("  1. 📄 文檔分片    - 解析並分片文檔")
        print("  2. 🔢 向量化      - 將分片轉換為向量並存入資料庫")
        print("  3. 🔍 查詢測試    - 測試向量資料庫檢索")
        print("  4. 🤖 AI 問答     - 使用 LLM 進行智能問答")  # ⭐ 新增
        print("  5. 📊 查看資料夾  - 檢視所有 RAG 結果")
        print("  6. ❌ 退出")
        print()

        choice = input("請輸入選項 (1-6): ").strip()

        if choice == '4':
            # 選擇資料庫
            folder = select_rag_folder()
            if not folder:
                continue

            # 選擇模型
            model = select_model()
            if not model:
                continue

            # 進入問答模式
            rag_qa_mode(folder, model)
```

### 問答模式

```python
def rag_qa_mode(folder: str, model: str):
    """AI 問答模式"""
    print(f"\n🤖 使用模型: {model}")
    print("💬 輸入問題開始對話（輸入 'exit' 返回主選單）\n")

    while True:
        question = input("\n❓ 你的問題: ").strip()

        if question.lower() == 'exit':
            break

        if not question:
            continue

        # 執行 RAG 查詢
        rag_query(folder, model, question)

        input("\n按 Enter 繼續...")
```

## 完整工作流程演示

```bash
$ python rag_cli.py

============================================================
         RAG 智能文檔檢索系統
============================================================

請選擇功能:

  1. 📄 文檔分片
  2. 🔢 向量化
  3. 🔍 查詢測試
  4. 🤖 AI 問答
  5. 📊 查看資料夾
  6. ❌ 退出

請輸入選項 (1-6): 4

📁 請選擇 RAG 資料夾:
  1. 01 華電聯網服務建議書_20251012_124248 ✅ (已向量化)
  2. 服務建議書_112年度_20251012_130637 ✅ (已向量化)

請選擇資料夾 (1-2): 1

📋 可用模型:
  1. llama3.1:latest
  2. mistral:latest

請選擇模型 (1-2): 1

🤖 使用模型: llama3.1:latest
💬 輸入問題開始對話（輸入 'exit' 返回主選單）

❓ 你的問題: 數位雙生系統的架構是什麼？

🔍 問題: 數位雙生系統的架構是什麼？

📚 檢索相關資料...

📖 參考資料來源:
  1. 參、專案需求規劃 > 一. 整體系統架構
  2. 參、專案需求規劃 > 二. 數位雙生智能火場鑑識輔助系統
  ...

🤖 生成答案中...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
根據服務建議書，數位雙生智能火場鑑識輔助系統採用多層架構設計：
[完整答案...]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

按 Enter 繼續...
```

## 性能與體驗

### 回應時間

| 階段 | 耗時 |
|------|-----|
| 向量檢索 | ~1 秒 |
| Prompt 構建 | <0.1 秒 |
| LLM 生成 | ~3-5 秒 (首次載入 +10 秒) |
| **總計** | **~4-6 秒** |

### 答案品質

經過多次測試，系統表現優秀：

✅ **準確率**：基於檢索內容回答，幾乎無幻覺
✅ **相關性**：能精準理解問題意圖
✅ **結構性**：回答清晰有條理
✅ **專業性**：保留專業術語，不過度簡化

## 階段總結

第三階段完成了 LLM 整合，實現完整的 RAG 系統：

✅ **完成項目**：
- Ollama 本地 LLM 整合
- 動態模型選擇
- Prompt 模板系統
- 完整 RAG 問答流程
- 統一 CLI 介面

✅ **技術突破**：
- 解決 UTF-8 wrapper 衝突
- 優化清屏顯示體驗
- 處理 Ollama timeout 問題

📊 **系統能力**：
- 端到端問答：從文檔到答案 < 20 秒
- 答案準確率：優秀
- 用戶體驗：流暢友善

🎯 **下一步**：
優化系統結構，統一資料夾管理，並進行最終的經驗總結。

---

[[02-向量化與檢索系統建置|← 上一篇：向量化與檢索系統建置]] | [[index|返回專案主頁]] | [[04-專案優化與技術總結|下一篇：專案優化與技術總結 →]]
