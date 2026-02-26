---
title: "#05 BuildTool 收官"
tags: [Unity, C#, Build Pipeline, Architecture, EditorWindow]
created: 2026-02-16
phase: 5
---

> **Tech** C#, Unity Editor, Build Pipeline, Reflection, JSON
>
> **AI** Claude Code

## 源起

EAS Foundation 最後一個模組：BuildTool。原本 9 個檔案、2,600 行程式碼的包檔工具——負責把 Unity 專案打包成各平台執行檔。那種「壞了整個團隊都無法出版遊戲」的關鍵系統。

這次沒修修補補，直接推倒重練。

## 設計

舊版最大的問題是**雙層資料模型**。同時維護一個序列化到 JSON 的 `BuildToolSetting` 和一個靜態類別裡的欄位。讀檔要手動把 JSON 的值一個一個複製到靜態欄位，存檔再反過來。改一個地方要在四個地方同步（讀、寫、靜態宣告、序列化結構），漏一個就資料不一致。

新版用單一 `BuildToolConfig` 資料模型，直接序列化也直接操作。讀檔一行 `JsonUtility.FromJson`，存檔一行 `JsonUtility.ToJson`。沒有複製、沒有映射、沒有不一致。

另一個設計重點是 **BuildSession**。多 preset 批次建置時（例如 Android 低規版、高規版、Windows 測試版），每個 preset 執行時不知道「我是這一輪的第幾個」。新版 BuildSession 帶 SessionId（GUID）、StartTime、CurrentPreset、CurrentIndex / TotalCount、IsFirst / IsLast，Pipeline 能精準控制「只在第一個 preset 前初始化」或「只在最後一個 preset 後上傳到伺服器」。

Pipeline 的執行時機討論了幾輪。一開始「每個 preset 前執行一次」會重複五次，改成「整輪建置前執行一次」又失去了 per-preset 的靈活性。最後方案：每個 preset 都呼叫一次 Pipeline，但傳入 BuildSession 讓 Pipeline 自己決定要不要跑。

**BuildCapabilities** 處理跨版本問題。Unity 的建置 API 不同版本會改——BuildTargetGroup vs NamedBuildTarget。把所有版本偵測和 API 選擇集中在這個靜態類別，其他程式碼不管版本差異。

**IBuildPlatformExtension** 處理平台專屬設定。Android 的 keystore、Windows Server 關 splash screen，每個平台實作自己的 Extension，核心不改。

## 實現

最後變成 **11 個檔案**的模組化架構，五頁式 EditorWindow UI：

1. **建置類型** — 選要建哪些 preset
2. **場景管理** — 雙欄選擇器，左邊專案所有場景樹狀檢視，右邊已選清單可拖拉排序
3. **複製規則** — inline 編輯建置完後要複製哪些檔案到哪裡
4. **輸出設定** — 輸出路徑、產品名稱格式、平台專屬設定
5. **Pipeline 管理** — 新增/移除/排序 Pipeline

每頁獨立的 `DrawXXXTab()` 方法，職責分明。

場景選擇器試過 ObjectField（不支援多選排序）和 AdvancedDropdown（只能單選），最後自己做雙欄選擇器。處理樹狀檢視的展開/收合、拖拉排序的視覺回饋、多選快捷鍵（Ctrl/Shift），花了不少時間。

Pipeline 序列化靠反射——Unity 的 `JsonUtility` 不支援多型序列化，把每個 Pipeline 的 typeName 記下來，讀取時反射建立實例。不完美但 Editor 工具夠用。

為了這些 UI 還擴充了 EditorKit：MultiSelectPopup（多選彈出選單帶搜尋框）、StringListDropdown、DrawLine（可調顏色粗細邊距）、MultiSelectField。

**Code review 修了一堆隱藏問題。** file alias 覆蓋同名檔案、刪 preset 後 index 沒重算導致選中錯誤項目、檔案 I/O 沒快取每次重複讀取、場景池應該用 `HashSet<string>` 而不是 `List<string>` 避免重複。

最扯的是 `DrawLine` 的 integer division bug：`height / 2` 置中分隔線，C# 整數除法無條件捨去，奇數高度偏移一個 pixel。改成 `height * 0.5f` 解決。

## 尾聲

| 項目 | 結果 |
|------|------|
| BuildTool | 9 檔 2,600 行 → 11 檔模組化架構 |
| 新增 EditorKit 元件 | 4 個 |
| EAS Foundation 總計 | 169 個 .cs 檔全部完成 |
| 移除冗餘檔案 | 22+ 個 |

169 個檔案全部完成並提交。從 Phase 1 的框架重寫啟動，經過 Runtime Core、AssetHub、Editor 工具、Extension 整理，到 BuildTool 收官，整個基礎層重構完畢。接下來從基礎設施建設轉向實際應用開發。

