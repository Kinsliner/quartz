---
title: "#01 重寫啟動"
tags: [Unity, C#, Editor Tools, Framework]
created: 2026-02-15
phase: 1
---

# #01 重寫啟動

> **Tech** C#, Unity Editor, IMGUI, JSON, Reflection
> **AI** Claude Code

## 源起

公司內部用了好幾年的 Unity 框架 eas-foundation，功能沒問題但程式碼老舊，各模組風格不統一。與其繼續在舊 codebase 上修補，決定用「重新撰寫」的方式移植到新專案——不是複製貼上，而是看著舊程式碼的 API 和行為，用自己的方式重新寫一遍。

總共大約 200 個腳本等著處理，包含 BuildTool、AssetHub、Timeline 這些大傢伙。

## 設計

重寫規則分兩層：

- **外層不能動** — 類別名稱、公開方法、參數、回傳值一模一樣，既有專案不用改引用
- **內層盡量求變** — 變數命名、演算法細節、程式碼組織方式刻意用不同寫法

「輕度差異化」是整個重寫的核心手法：改變數名（`process` → `proc`）、調方法順序、用 early return 替代巢狀 if、用 HashSet 替代 List+Contains。累積起來整份程式碼在結構上就是全新的，但功能完全相同。

開發慣例也在這階段定下來：
- **Namespace 統一** — Editor 腳本用 `EAS.Tool`，Runtime 用 `EAS`
- **拒絕 Begin/End** — 所有 `EditorGUILayout.BeginHorizontal/EndHorizontal` 改成 `using (new HorizontalScope())`，讓縮排自動管理區塊範圍
- **EditorKit 集中** — 之前叫 `EditorExtension.UnfocusWhenClick()`，現在改叫 `EditorKit.ClearFocusOnClick()`，功能一樣但命名更直覺

執行順序上先把 Runtime 地基打好。FileHandler、SettingLoader、EditorSettingLoader、TypeResolver、EzSerialize、EventBus 這些基礎模組是所有 Editor 工具的共用依賴，必須最先完成。

## 實現

第一批處理了 10 個 Editor 工具模組：EditorKit 統一 UI 元件庫、BlackBoard 快捷面板、CheckTool 專案健康檢查（11 個檢查項目）、ComponentTool、HierarchySnapshot、SceneNavigator、AssetCollector、ReplacementTool、GitSubmodulePuller、ConstKeyGenerator。加上 8 個 Runtime 核心模組，共完成約 74 個腳本。

比較有趣的兩個：

**GitSubmodulePuller** 自動解析 `.gitmodules` 讓你在 Editor 裡點幾下就拉取所有子模組。原版用大量 `Begin/End` layout 區塊，全部改成 `using` scope 後可讀性差很多。

**ConstKeyGenerator** 是常數產生器框架，把 Unity 中的動態資料（場景列表、Tag/Layer）自動轉成 C# 常數類別。重寫時順手加了幾個實用功能：可自訂 Namespace 和輸出路徑（原本寫死）、「全部產生」一鍵按鈕（原本要一個一個點）、dry-run 預覽（寫檔前先看結果）。這些是「增強易用性」而非「改變核心設計」——這個界線一旦抓準，整個重寫過程就順很多。

EditorKit 也在這階段持續擴充，新增了 `FolderPathField` 元件供 ConstKeyGenerator 選擇輸出路徑用。另外統一了 EditorWindow 的 Reload 機制——以前每個視窗要寫一堆 `OnEnable/OnDisable/OnFocus`，現在全部抽到 Reload 方法裡，初始化集中在一個地方。

**模組依賴是一開始沒注意到的問題。** ConstKeyGenerator 依賴 EditorKit 的 `FolderPathField`，寫到一半才發現要回頭補。後來學乖，動手前先看 `using` 清單確認依賴都到位。這也是為什麼 Runtime 核心模組要優先完成——它們是地基，其他 Editor 工具都用到。

**維持動力的策略是先挑有趣的做。** 像 GitSubmodulePuller 和 ConstKeyGenerator 功能明確、寫完馬上能在編輯器裡看到結果。比起純 Runtime 的 Utility 類別有趣得多。另外建了一份進度追蹤文件 `eas-rewrite-plan.md`，200 個腳本列成清單，完成一個打一勾，視覺化的進度回饋很有幫助。

## 尾聲

| 項目 | 結果 |
|------|------|
| 完成腳本 | ~74 個 |
| 剩餘腳本 | ~144 個 |
| Editor 模組 | 10 個 |
| Runtime 模組 | 8 個 |

第一批完成大概三分之一。重寫規則和開發慣例在這個階段確立，後面的工作有了明確方向。

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案首頁]]
