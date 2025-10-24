---
title: "#06 Web 介面開發 - 從 CLI 到團隊共用"
tags: [streamlit, web-ui, team-collaboration, ux-design]
created: 2025-10-13
---

# 開發日誌 #6 - Web 介面開發

## 為什麼需要 Web 版本？

在完成了命令列版本的 RAG 系統後，我們遇到了一個實際問題：

> **CLI 介面對非技術人員不友善**

公司內部有 10 位同事需要使用這個系統查詢招標文件，但並非所有人都熟悉命令列操作。我們需要：

- ✅ 簡單直觀的操作介面
- ✅ 無需安裝環境即可使用
- ✅ 內網部署，資料不外洩
- ✅ 支援多人同時使用
- ✅ 快速開發，儘早上線

## 技術選型：為什麼選擇 Streamlit？

### 對比分析

| 方案 | 開發時間 | 學習曲線 | 適合人數 | 評價 |
|------|---------|---------|---------|------|
| **Streamlit** | 1 天 | 極低（純 Python） | < 50 人 | ⭐⭐⭐⭐⭐ |
| Flask + Vue.js | 2 週 | 高（前後端分離） | 不限 | ⭐⭐⭐ |
| Django + React | 3 週 | 高（複雜架構） | 不限 | ⭐⭐ |
| FastAPI + HTML | 1 週 | 中（需寫前端） | 不限 | ⭐⭐⭐ |

### 選擇 Streamlit 的理由

**優勢**：
- ✅ **開發速度極快**：純 Python，1 天完成 UI
- ✅ **零前端知識**：不需要 HTML/CSS/JavaScript
- ✅ **內建豐富元件**：聊天介面、檔案上傳、表格等
- ✅ **適合小團隊**：10 人使用完全足夠
- ✅ **自動重載**：修改代碼即時生效

**劣勢**（對我們不重要）：
- ❌ UI 客製化受限（但內部使用夠用）
- ❌ 不適合高併發（但只有 10 人）
- ❌ 不適合複雜互動（但我們需求簡單）

**結論**：對於 10 人內部使用的 RAG 系統，Streamlit 是完美選擇。

## 設計理念

### 核心原則

1. **簡單至上**
   - 不做複雜的多用戶系統
   - 專注三個核心功能
   - 減少點擊次數

2. **內網安全**
   - 所有資料僅在公司內網流動
   - 禁止上雲
   - 本地 LLM，資料不外洩

3. **漸進開發**
   - 先完成 UI 框架
   - 再整合後端功能
   - 快速迭代

4. **使用者友善**
   - 清晰的視覺設計
   - 直觀的操作流程
   - 即時反饋

## 三次迭代的設計過程

### 第一版：功能過於複雜 ❌

**設計內容**：
- 首頁介紹頁面（系統說明）
- 三個獨立頁面檔案（pages/）
- 系統設置頁面
- 大量的 CSS 樣式

**問題**：
- ❌ 使用者反饋「太複雜」
- ❌ 需要多次點擊才能完成任務
- ❌ 視覺干擾過多
- ❌ 首頁沒有實際功能

**教訓**：不要一開始就做太多功能。

### 第二版：極簡單頁面 ❌

**調整**：
- 只有一個上傳頁面
- 移除所有多餘元素
- 只保留核心功能

**問題**：
- ❌ 太簡單，缺少導航
- ❌ 無法切換不同功能
- ❌ 不符合實際使用需求

**教訓**：過度簡化也不好，要找到平衡點。

### 第三版：三頁面精簡架構 ✅

**設計原則**：
1. **一個主程式**：所有邏輯在 `app.py` 中（302 行）
2. **三個核心頁面**：AI 對話、上傳文件、文件管理
3. **左側導航欄**：清晰的功能切換
4. **極簡樣式**：只保留必要的 CSS（50 行）

**成功關鍵**：
- ✅ 功能剛好夠用
- ✅ 操作流程清晰
- ✅ 視覺乾淨簡潔

## 三個核心頁面設計

### 頁面 1：💬 AI 對話（首頁）

**設計目標**：
- 讓使用者一進來就能問問題
- 類似 ChatGPT 的對話體驗

**介面元素**：

```
┌─────────────────────────────────┐
│      👋 歡迎使用 RAG 系統        │
│   請在下方輸入您的問題...         │
└─────────────────────────────────┘

[對話記錄顯示區域]
👤 用戶：數位雙生系統的架構是什麼？
🤖 助手：根據文件內容...

[對話輸入框]
輸入您的問題... [發送]
```

**技術實現**：

```python
# 歡迎訊息（中間顯示）
st.markdown("""
    <div class="welcome-box">
        <div class="welcome-title">👋 歡迎使用 RAG 智能問答系統</div>
        <div class="welcome-subtitle">請在下方輸入您的問題</div>
    </div>
""", unsafe_allow_html=True)

# 初始化聊天記錄
if "messages" not in st.session_state:
    st.session_state.messages = []

# 顯示歷史對話
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# 對話輸入框（Streamlit 會自動放在底部）
if prompt := st.chat_input("輸入您的問題..."):
    # 顯示用戶訊息
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # 調用 RAG 系統（待整合）
    response = ask_rag_system(prompt)

    # 顯示助手回覆
    st.session_state.messages.append({"role": "assistant", "content": response})
    with st.chat_message("assistant"):
        st.markdown(response)
```

**設計亮點**：
- ✅ 使用 Streamlit 原生的 `st.chat_input()` 和 `st.chat_message()`
- ✅ 自動儲存對話歷史到 `session_state`
- ✅ 聊天記錄向上堆疊，符合使用習慣
- ✅ 歡迎訊息置中顯示，視覺清爽

### 頁面 2：📤 上傳文件

**設計目標**：
- 簡單的拖放上傳
- 顯示文件資訊
- 一鍵開始處理

**介面元素**：

```
┌─────────────────────────────────┐
│        📤 上傳文件               │
│                                 │
│   ┌───────────────────────┐    │
│   │  拖放文件到這裡         │    │
│   │  或點擊選擇文件         │    │
│   └───────────────────────┘    │
│                                 │
│   📎 檔名：服務建議書.pdf        │
│   📦 大小：12.3 MB              │
│   📝 類型：PDF                  │
│                                 │
│   [🚀 開始上傳]                 │
└─────────────────────────────────┘
```

**技術實現**：

```python
# 置中容器（使用三欄佈局）
col1, col2, col3 = st.columns([1, 2, 1])

with col2:
    # 文件上傳器
    uploaded_file = st.file_uploader(
        "選擇文件",
        type=["pdf", "docx", "txt"],
        label_visibility="visible"
    )

    if uploaded_file is not None:
        # 顯示文件資訊
        st.metric("📎 檔名", uploaded_file.name)
        st.metric("📦 大小", f"{uploaded_file.size / 1024 / 1024:.2f} MB")
        st.metric("📝 類型", uploaded_file.type.split('/')[-1].upper())

        # 上傳按鈕
        if st.button("🚀 開始上傳", type="primary", use_container_width=True):
            # 儲存文件（加時間戳避免重名）
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_path = UPLOAD_DIR / f"{timestamp}_{uploaded_file.name}"

            with open(file_path, "wb") as f:
                f.write(uploaded_file.getbuffer())

            # 記錄到資料庫
            add_document(uploaded_file.name, file_path)

            st.success(f"✅ 文件上傳成功：{uploaded_file.name}")
            st.info("請前往「文件管理」頁面查看")
```

**設計亮點**：
- ✅ 限制文件類型（type=["pdf", "docx", "txt"]）
- ✅ 顯示文件大小，讓使用者心裡有數
- ✅ 時間戳避免文件名衝突
- ✅ 成功後提示下一步操作

### 頁面 3：📋 文件管理

**設計目標**：
- 列表顯示所有文件
- 顯示處理狀態
- 支援刪除操作

**介面元素**：

```
┌──────────────────────────────────────────────┐
│ UDID     文件名稱        狀態    分片數  更新時間    操作 │
├──────────────────────────────────────────────┤
│ a3f7b2c1 服務建議書.pdf  已完成  360  2025-10-13  🗑️  │
│ b8e3c9d2 技術規格.docx   處理中  0    2025-10-13  🗑️  │
│ c9f4d1e3 系統架構.txt    已上傳  0    2025-10-13  🗑️  │
└──────────────────────────────────────────────┘
```

**技術實現**：

```python
# 載入文件列表
docs = load_documents_db()

if not docs:
    st.info("📭 尚無文件，請先上傳文件")
else:
    st.write(f"共 {len(docs)} 個文件")

    # 表格標題（使用欄位佈局）
    col1, col2, col3, col4, col5, col6 = st.columns([1, 2, 1.5, 1, 2, 1])
    with col1:
        st.markdown("**UDID**")
    with col2:
        st.markdown("**文件名稱**")
    with col3:
        st.markdown("**文件狀態**")
    with col4:
        st.markdown("**分片數量**")
    with col5:
        st.markdown("**最後更新時間**")
    with col6:
        st.markdown("**操作**")

    # 顯示每個文件
    for doc in docs:
        col1, col2, col3, col4, col5, col6 = st.columns([1, 2, 1.5, 1, 2, 1])

        with col1:
            st.text(doc["udid"])
        with col2:
            st.text(doc["filename"])
        with col3:
            # 狀態帶顏色標示
            status = doc["status"]
            if status == "已完成":
                st.success(status)  # 綠色
            elif status == "處理中":
                st.warning(status)  # 黃色
            else:
                st.info(status)     # 藍色
        with col4:
            st.text(doc["chunk_count"])
        with col5:
            st.text(doc["last_updated"])
        with col6:
            # 刪除按鈕（每個文件獨立 key）
            if st.button("🗑️", key=f"del_{doc['udid']}", help="刪除"):
                delete_document(doc["udid"])
                st.rerun()  # 重新載入頁面
```

**設計亮點**：
- ✅ 使用欄位佈局（`st.columns`）模擬表格
- ✅ 狀態用顏色標示（綠/黃/藍）
- ✅ 每個刪除按鈕有獨立 key
- ✅ 刪除後自動重載頁面

## 資料管理設計

### 為什麼使用 JSON 而非資料庫？

**理由**：
- ✅ **簡單直觀**：易於除錯和手動編輯
- ✅ **資料量小**：10 人使用，預計 < 100 個文件
- ✅ **無需額外服務**：不需要安裝 MySQL/PostgreSQL
- ✅ **易於備份**：直接複製 JSON 檔案
- ✅ **開發快速**：讀寫只需幾行代碼

**JSON 資料結構**：

```json
[
  {
    "udid": "a3f7b2c1",
    "filename": "服務建議書.pdf",
    "file_path": "data/uploads/20251013_153022_服務建議書.pdf",
    "status": "已上傳",
    "chunk_count": 0,
    "last_updated": "2025-10-13 15:30:22"
  }
]
```

**資料庫操作函數**：

```python
def load_documents_db():
    """載入文件資料庫"""
    if DB_FILE.exists():
        with open(DB_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return []

def save_documents_db(docs):
    """儲存文件資料庫"""
    with open(DB_FILE, 'w', encoding='utf-8') as f:
        json.dump(docs, f, ensure_ascii=False, indent=2)

def add_document(filename, file_path):
    """新增文件記錄"""
    docs = load_documents_db()
    doc = {
        "udid": str(uuid.uuid4())[:8],  # 8 位 UUID
        "filename": filename,
        "file_path": str(file_path),
        "status": "已上傳",
        "chunk_count": 0,
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    docs.append(doc)
    save_documents_db(docs)
    return doc

def delete_document(udid):
    """刪除文件記錄"""
    docs = load_documents_db()
    docs = [doc for doc in docs if doc["udid"] != udid]
    save_documents_db(docs)
```

### 檔案儲存結構

```
data/
├── uploads/                           # 原始上傳檔案
│   ├── 20251013_153022_服務建議書.pdf
│   └── 20251013_154530_技術規格.docx
├── rag/                               # RAG 處理結果（待整合）
│   ├── 服務建議書_20251013_153022/
│   │   ├── chunks.json
│   │   └── vectordb/
│   └── 技術規格_20251013_154530/
│       ├── chunks.json
│       └── vectordb/
└── documents.json                     # 文件資料庫
```

## 技術難題與解決

### 難題 1：UTF-8 編碼衝突

**問題**：
在命令列版本我們使用了 UTF-8 強制設定：
```python
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
```

但在 Streamlit 中會報錯：
```
ValueError: I/O operation on closed file
```

**原因**：
Streamlit 在載入模組時 stdout 已經被關閉，再設定會衝突。

**解決**：
完全移除 UTF-8 設定，Streamlit 本身已正確處理編碼：
```python
# 移除這段代碼
# if sys.platform == 'win32':
#     sys.stdout = io.TextIOWrapper(...)

# 直接使用
import streamlit as st
```

### 難題 2：對話框定位問題

**問題**：
Streamlit 的 `st.chat_input()` 會自動固定在頁面底部，但會延伸到側邊欄下方。

**嘗試 1**：強制設定 left 位置 ❌
```css
.stChatInput {
    left: 21rem !important;  /* 側邊欄寬度 */
}
```
結果：不可行，Streamlit 內部會覆蓋。

**嘗試 2**：使用 data-testid 選擇器 ❌
```css
[data-testid="stChatInput"] {
    left: 21rem !important;
}
```
結果：也不可行，Streamlit 動態生成 class。

**最終解決**：不干涉定位，讓 Streamlit 自己處理 ✅
```css
.stChatInput {
    background: transparent !important;  /* 只設定背景 */
}
```
結果：Streamlit 會自動根據側邊欄狀態調整對話框寬度！

**教訓**：順應框架設計，不要對抗。

### 難題 3：頁面過於複雜

**問題**：
第一版設計了太多頁面和功能，使用者反饋「太複雜」。

**解決過程**：
1. **分析核心需求**：對話、上傳、管理
2. **移除非必要元素**：
   - ❌ 刪除首頁介紹頁面
   - ❌ 移除系統設置頁面（暫時）
   - ❌ 簡化上傳頁面
3. **保留三個核心頁面**：聚焦主要功能

**教訓**：先做 MVP（最小可行產品），再擴充。

## 樣式設計

### CSS 設計原則

1. **極簡主義**：只保留必要的樣式（50 行）
2. **藍色主題**：#1f77b4（Streamlit 預設藍）
3. **語義化類別**：welcome-box、doc-table 等

### 完整 CSS

```css
/* 全域樣式 */
.main {
    padding-top: 2rem;
}

/* 歡迎訊息樣式 */
.welcome-box {
    text-align: center;
    padding: 3rem 2rem;
    margin: 2rem 0;
}
.welcome-title {
    font-size: 2.5rem;
    font-weight: bold;
    color: #1f77b4;
    margin-bottom: 1rem;
}
.welcome-subtitle {
    font-size: 1.2rem;
    color: #666;
}

/* 表格樣式 */
.doc-table {
    width: 100%;
    margin-top: 2rem;
}

/* 對話框樣式 */
.stChatInput {
    background: transparent !important;
}
```

## 使用者體驗優化

### 1. 導航設計

**側邊欄元素**：
- 🤖 系統標題
- 三個單選按鈕（頁面切換）
- 📊 系統資訊（文件數量）
- 🔒 安全提示

**優點**：
- ✅ 一目了然，知道當前位置
- ✅ 單次點擊切換頁面
- ✅ 即時顯示系統狀態

### 2. 視覺回饋

**狀態顏色**：
- 🟢 綠色（success）：已完成
- 🟡 黃色（warning）：處理中
- 🔵 藍色（info）：已上傳

**按鈕樣式**：
- 主要操作：`type="primary"`（藍色）
- 危險操作：🗑️ 刪除（紅色 icon）

### 3. 錯誤處理

**友善的錯誤訊息**：
```python
try:
    save_file(uploaded_file)
except Exception as e:
    st.error(f"❌ 上傳失敗：{str(e)}")
```

**即時驗證**：
- 檔案類型限制：`type=["pdf", "docx", "txt"]`
- 檔案大小提示：顯示 MB 數值

## 部署指南

### 本地開發

```bash
# 安裝 Streamlit
pip install streamlit

# 啟動應用
streamlit run app.py

# 訪問
http://localhost:8501
```

### 內網部署

```bash
# 允許內網訪問
streamlit run app.py --server.address=0.0.0.0 --server.port=8501

# 同事訪問（需在同一內網）
http://你的電腦IP:8501
# 例如：http://192.168.1.100:8501
```

### Windows 開機自動啟動

建立 `start.bat`：
```batch
@echo off
cd D:\Projects\assistant\rag-web
streamlit run app.py --server.address=0.0.0.0 --server.port=8501
```

然後加入「工作排程器」設定開機執行。

## 效能數據

### 檔案處理（10 人使用）

- 上傳 10 MB PDF：< 1 秒
- 顯示文件列表（100 個）：< 0.1 秒
- 切換頁面：< 0.1 秒

### 記憶體管理

**Streamlit Session State**：
```python
# 只儲存對話記錄
if "messages" not in st.session_state:
    st.session_state.messages = []
```

**不快取**：
- 文件列表每次重新讀取（確保最新狀態）
- 上傳的檔案不保留在 session 中

## 專案統計

### 開發時間

- 第一版（複雜版）：4 小時
- 第二版（極簡版）：1 小時
- 第三版（最終版）：2 小時
- **總計：7 小時（1 個工作天）**

### 程式碼規模

- `app.py`：302 行
- CSS：~50 行
- Python 邏輯：~200 行
- UI 佈局：~50 行

### 功能完成度

✅ **已完成**（UI 層）：
- 三個核心頁面
- 檔案上傳和儲存
- 文件列表顯示
- 文件刪除功能
- 對話介面 UI

⏳ **待整合**（後端層）：
- RAG 文檔處理（分片、向量化）
- 實際問答功能（呼叫 LLM）
- 狀態更新機制
- 進度顯示

## 經驗總結

### 成功經驗

1. **選對技術棧**
   - Streamlit 大幅降低開發難度
   - 純 Python 開發，無需前後端分離
   - 適合小團隊快速開發

2. **漸進式開發**
   - 先完成 UI，再整合後端
   - 及早收集使用者反饋
   - 快速迭代調整

3. **簡單至上**
   - 移除非必要功能
   - 專注核心使用場景
   - 降低學習成本

4. **JSON 資料庫**
   - 小規模應用不需要複雜資料庫
   - 易於除錯和備份
   - 滿足實際需求

### 踩過的坑

1. **過度設計**
   - 第一版功能太多
   - 學到：先做 MVP，再擴充

2. **強行客製化 CSS**
   - 試圖覆蓋 Streamlit 內部樣式
   - 學到：順應框架設計

3. **編碼問題**
   - Windows UTF-8 處理需要小心
   - 學到：使用框架提供的機制

4. **狀態管理**
   - 過度使用 session_state
   - 學到：只儲存必要的狀態

## 下一步規劃

### 短期（1 週內）

1. **整合 RAG 核心**
   - 複製 rag-chunking-engine 核心程式碼
   - 整合文檔分片功能
   - 整合向量化功能

2. **整合問答功能**
   - 整合 rag_qa.py 的 RAGSystem
   - 實作真實的問答邏輯
   - 顯示參考來源

3. **狀態更新機制**
   - 文件處理進度顯示
   - 自動更新文件狀態
   - 分片數量自動更新

### 中期（2-4 週）

4. **進階功能**
   - 批次上傳文件
   - 對話歷史匯出
   - 模型選擇介面
   - Prompt 模板編輯

5. **效能優化**
   - 文檔處理背景執行
   - 進度條顯示
   - 快取機制

### 長期（1-3 個月）

6. **系統設置頁面**
   - 檢索參數調整
   - 系統狀態監控

7. **團隊協作**
   - 簡單的使用者識別
   - 個人對話記錄
   - 共享知識庫

## 結語

這次 Web 化證明，**選對工具和保持簡單是關鍵**。

Streamlit 讓我們用 **1 天**時間完成了可用的 Web 應用，大幅降低了內部系統的開發門檻。雖然目前只完成了 UI 層，但已經足夠讓使用者理解系統的操作流程。

**關鍵數據**：
- 開發時間：**1 天**
- 程式碼：**302 行**
- 適用人數：**10 人**
- 技術門檻：**低**（純 Python）
- 維護成本：**極低**

對於小團隊的內部工具開發，這是一個非常成功的案例。

**下一步**：整合 RAG 核心功能，讓系統真正可用。

---

## 相關文章

- [[專案/RAG智能文檔檢索系統/日誌/05-Reranking精排序實作|#5 Reranking 精排序實作]] - 命令列版本的最後功能
- [[專案/RAG智能文檔檢索系統/index|專案主頁]]

返回 [[專案/RAG智能文檔檢索系統/index|專案主頁]]
