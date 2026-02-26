---
title: "#08 BuildTool — 最後一塊拼圖終於到位"
tags: [Unity, EAS Foundation, BuildTool, Editor, Pipeline, 跨平台, 架構設計]
created: 2026-02-16
---

# Phase 8: BuildTool — 最後一塊拼圖終於到位

## 這次做了什麼?

終於！EAS Foundation 的最後一個模組 **BuildTool** 完成了。

這不是隨便一個小模組，而是原本那個 9 檔 2,600 行程式碼的包檔工具——負責把 Unity 專案打包成各平台執行檔的核心工具。你知道的，就是那種「如果壞了，整個團隊都無法出版遊戲」的那種關鍵系統。

這次我沒有修修補補舊架構，而是直接推倒重練，用全新設計重寫了整個系統，最後變成 **11 個檔案**的模組化架構。

### 核心功能一覽

BuildTool 現在可以做到：

- **多平台批次建置**：一次設定多個 preset，一鍵連續打包 Android、Windows、macOS、iOS 等不同平台
- **建置前驗證**：會先檢查設定是否完整（場景是否存在、keystore 檔案路徑是否正確等），避免建置到一半才發現缺東缺西
- **靈活的場景管理**：每個 preset 可以自訂要打包哪些場景、順序如何
- **檔案複製規則**：建置完自動複製資料夾、改名、整理輸出結構
- **Pipeline 擴充機制**：可以插入自訂的建置前後處理邏輯（比如修改程式碼、產生版本號、上傳到伺服器等）
- **平台專屬設定**：Android 可以設定 keystore、Windows Server 可以關掉 splash screen
- **五頁式 UI**：建置類型選擇、場景管理、複製規則、輸出設定、Pipeline 管理，分頁清楚不混亂

聽起來很厲害對吧？但這次改寫最大的價值不是功能多，而是**架構乾淨了**。

## 用了哪些技術？

### 1. 消滅雙層資料模型的惡夢

舊版的 BuildTool 有個超詭異的設計：它同時維護兩套資料結構。

一個是序列化到 JSON 的 `BuildToolSetting`，另一個是存在靜態類別 `BuildTool` 裡面的欄位。每次讀檔要手動把 JSON 的值一個一個複製到靜態欄位，存檔時再反過來複製回去。

這種設計的問題是：你改一個地方，就要在四個地方同步（讀、寫、靜態宣告、序列化結構）。漏掉一個地方？恭喜你，資料就會不一致，然後你得花半小時 debug。

新版直接把這兩層合併成**單一資料模型**：`BuildToolConfig`。

這個類別本身就可以直接序列化成 JSON，也可以直接在 Editor 裡操作。讀檔？一行 `JsonUtility.FromJson`。存檔？一行 `JsonUtility.ToJson`。沒有複製、沒有映射、沒有不一致。

### 2. BuildSession 建置會話機制

這是我最滿意的設計之一。

以前的問題是：當你一次建置五個 preset（比如 Android 低規版、高規版、Windows 測試版、正式版等），每個 preset 執行時都不知道「我是這一輪的第幾個」、「總共有幾個」、「我是不是第一個或最後一個」。

這導致 Pipeline 無法做一些「只在第一個 preset 前做初始化」或「只在最後一個 preset 後做清理」的事情。

新版引入了 `BuildSession` 物件：

- `SessionId`：每輪建置有唯一的 GUID，讓你可以辨識同一輪
- `StartTime`：記錄建置開始時間
- `CurrentPreset`：目前正在建置的 preset
- `CurrentIndex` / `TotalCount`：第幾個 / 總共幾個
- `IsFirst` / `IsLast`：是否第一個或最後一個

現在 Pipeline 可以寫出「只在第一個 preset 前備份專案」或「只在最後一個 preset 後上傳到伺服器」這種邏輯。

### 3. BuildCapabilities 跨版本抽象層

Unity 的 API 在不同版本之間會改。

舊版的建置 API 用 `BuildTargetGroup`（比如 `BuildTargetGroup.Android`），但新版改用 `NamedBuildTarget`（`NamedBuildTarget.Android`）。這導致如果你的 Editor 工具要支援多個 Unity 版本，就得到處寫 `#if UNITY_2023_1_OR_NEWER`。

我加了一層 `BuildCapabilities` 靜態類別，把所有「Unity 版本偵測」和「API 選擇」集中在這裡：

- 偵測目前 Unity 版本支援哪些功能
- 提供統一的介面（比如 `GetPlayerSettings(BuildTarget)` 會自動選用正確的 API）
- 把所有 `#if` 條件編譯都集中管理

這樣其他程式碼就不用管版本差異，直接呼叫 `BuildCapabilities` 就好。

### 4. IBuildToolPipeline 介面與 per-preset 篩選

Pipeline 是「建置前後可以執行的自訂邏輯」。

新版的 `IBuildToolPipeline` 改成接收 `BuildSession`：

```csharp
public interface IBuildToolPipeline
{
    string Name { get; }
    void Execute(BuildSession session);
}
```

這樣 Pipeline 可以根據 session 資訊決定要不要執行（比如「只在建置 Android 時執行」或「只在最後一個 preset 才執行」）。

### 5. IBuildPlatformExtension 平台擴充機制

不同平台有專屬設定。Android 要設定 keystore（簽章金鑰），Windows Server 版本要關掉 splash screen。

我設計了一個擴充點介面 `IBuildPlatformExtension`，讓每個平台可以自己決定要新增哪些額外設定：

- `AndroidKeystoreExtension`：讓你設定 keystore 路徑、密碼、alias 等
- `WindowsServerExtension`：可以關掉 Windows Server 預設的啟動畫面

未來如果要新增「iOS 專屬設定」或「WebGL 專屬設定」，只要實作這個介面就可以無縫整合。

### 6. 五頁式 EditorWindow UI

這個 Editor 視窗有**五個分頁**：

1. **建置類型**：選擇要建置哪些 preset
2. **場景設定**：雙欄選擇器（左邊是專案所有場景樹狀檢視，右邊是已選場景清單），可以拖拉排序
3. **複製規則**：inline 編輯「建置完成後要複製哪些檔案/資料夾到哪裡」
4. **輸出設定**：設定輸出路徑、產品名稱格式、平台專屬設定
5. **Pipeline 管理**：新增/移除/排序 Pipeline

每一頁都是獨立的 `void DrawXXXTab()` 方法，職責分明。

### 7. 共用元件擴充

為了實作這些 UI，我還順手擴充了 EditorKit（Editor 共用元件庫）：

- **MultiSelectPopup**：多選彈出選單，帶搜尋框（用在場景選擇器）
- **StringListDropdown**：字串清單下拉選單（用在選擇 Pipeline 類型）
- **DrawLine**：畫分隔線，新增可調參數（顏色、粗細、邊距）
- **MultiSelectField**：多選欄位（用在選擇多個 preset）

這些元件現在可以在其他 Editor 工具重複使用。

## 遇到什麼挑戰？

### 挑戰一：Code Review 修了一堆隱藏 Bug

我本來以為寫完就差不多了，結果 code review 時發現了**一大堆問題**。

有些是 Critical 等級的嚴重 bug（比如 file alias 會覆蓋同名檔案、刪除 preset 時 index 沒有重新計算導致選中錯誤的項目），有些是效能問題（檔案系統 I/O 沒有快取、每次都重複讀取），還有些是設計缺陷（場景池應該用 `HashSet<string>` 而不是 `List<string>` 避免重複）。

光是修這些問題就花了不少時間。

最扯的是 `DrawLine` 的 integer division bug：我原本寫 `height / 2` 來置中分隔線，結果忘記 C# 的整數除法會無條件捨去，導致奇數高度時會偏移一個 pixel。改成 `height * 0.5f` 才解決。

這讓我學到：code review 真的很重要，即使是自己覺得「應該沒問題」的程式碼，還是會有一堆盲點。

### 挑戰二：場景選擇器的 UX 設計

「讓使用者選擇場景」聽起來很簡單，對吧？

一開始我想用內建的 `EditorGUILayout.ObjectField`，但它不支援多選、不支援排序、不支援從專案樹狀結構選擇。

後來改用 `AdvancedDropdown`，但它只能單選。

最後我自己做了一個**雙欄選擇器**：

- 左欄是專案所有場景的樹狀檢視（按資料夾分組），可以多選
- 右欄是已選場景的清單，可以拖拉排序
- 有「新增」和「移除」按鈕在中間

聽起來簡單，但要處理「樹狀檢視的展開/收合狀態」、「拖拉排序的視覺回饋」、「多選時的快捷鍵（Ctrl/Shift）」等細節，花了不少時間調整。

最後做出來的成果我很滿意，用起來很直覺。

### 挑戰三：Pipeline 的執行時機

Pipeline 應該什麼時候執行？

一開始我設計成「每個 preset 建置前執行一次」，但這樣會有問題：如果你有五個 preset，同一個 Pipeline 就會被呼叫五次。

後來改成「整輪建置前執行一次」，但這樣又有問題：如果 Pipeline 需要知道「現在正在建置哪個 preset」怎麼辦？

最後的解決方案是：**Pipeline 每個 preset 都會被呼叫一次，但會收到 `BuildSession` 參數**。

Pipeline 可以自己決定要不要執行（比如「只在建置 Android 時執行」或「只在第一個 preset 才執行」）。

這樣既保持彈性，又避免重複執行不該重複的邏輯。

### 挑戰四：序列化 Pipeline 設定

Pipeline 是可以自訂的，每個 Pipeline 可能有自己的設定欄位（比如「上傳到哪個伺服器」、「版本號格式」等）。

這些設定要怎麼序列化到 JSON？

Unity 的 `JsonUtility` 不支援多型序列化（你不能有一個 `List<IPipeline>` 然後讓它自動序列化每個子類別的欄位）。

我最後用了**反射 + 手動序列化**：把每個 Pipeline 的類型名稱記錄下來，存成 `typeName` 欄位，讀取時再根據 `typeName` 用反射建立實例。

這個方案不算完美（效能不是最好），但對於 Editor 工具來說夠用了。

## 重寫旅程的終點

**EAS Foundation 的所有 169 個檔案都已經完成並提交**。

BuildTool 是最後一塊拼圖，現在整個基礎層已經完整了。

從 Phase 1 開始的「重構之旅」，經歷了 Runtime Core、AssetHub、文件整理、Editor Tools、UI Components、Extension Methods、到現在的 BuildTool，總算是告一段落。

接下來的工作重點會從「基礎設施建設」轉向「實際應用開發」——用這套已經打磨好的基礎層來做真正的遊戲功能。

這種感覺就像是你花了好幾週搭建一個超級穩固的地基和骨架，現在終於可以開始蓋房子了。

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案主頁]]
