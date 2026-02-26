---
title: "#01 EAS Foundation 重寫之旅 — 從零開始的框架遷移實驗"
tags: [Unity, C#, 框架重寫, 編輯器工具, EAS Foundation]
created: 2026-02-15
---

# Phase 1: EAS Foundation 重寫之旅 — 從零開始的框架遷移實驗

## 這次做了什麼?

最近這幾天,我踏上了一趟有趣但有點瘋狂的旅程 — 把整個 `eas-foundation` 框架用「重新撰寫」的方式移植到新專案裡。

你可能會問:「為什麼不直接複製貼上?」欸,這個問題問得好!其實這次的目標不只是搬程式碼那麼簡單。我想做的是在保留所有功能的前提下,讓程式碼用不同的方式呈現 — 就像同一道菜用不同的方式料理,端出來的味道應該要一樣,但過程和擺盤可以不同。

### 目前進度快照

到目前為止,已經完成了大約 **74 個腳本**,分布在這些模組:

**編輯器工具部分:**
- **EditorKit 擴充系統** — 提供統一的 UI 元件庫,包括 Dropdown、ReorderableList 等
- **BlackBoard** — 編輯器內的多功能快捷面板
- **CheckTool** — 專案健康檢查工具,含 11 個檢查項目
- **ComponentTool** — 元件操作輔助工具
- **HierarchySnapshot** — 場景結構快照與還原
- **SceneNavigator** — 場景快速跳轉工具
- **AssetCollector** — 資源收集與管理系統
- **ReplacementTool** — 批次取代工具
- **GitSubmodulePuller** — Git 子模組管理工具 (最新完成!)
- **ConstKeyGenerator** — 常數鍵產生器 (最新完成!)

**Runtime 核心部分:**
- **ScriptGenerator** — 程式碼生成系統
- **AssetCollector Runtime** — 執行期資源載入
- **BlackBoard Runtime** — 執行期資料黑板
- **Data 處理模組** — FileHandler、SettingLoader、EditorSettingLoader
- **Extension 擴充** — ComponentExtension 等輔助方法
- **TypeResolver** — 型別解析工具
- **EzSerialize** — 序列化系統
- **EventBus** — 事件匯流排系統

還剩下大約 **144 個腳本**等著我,包括一些大魔王級別的模組,像是 BuildTool、AssetHub、Timeline 等。

### 這幾天的重點成就

最近兩天主要攻克了兩個模組:

1. **GitSubmodulePuller** — 這是一個用來管理 Unity 專案中 Git 子模組的工具。它能自動解析 `.gitmodules` 檔案,讓你在編輯器裡用滑鼠點幾下就能拉取所有子模組的最新版本。之前我在這個模組上用了很多 `Begin/End` 的 layout 區塊,這次全部改成更乾淨的 `using` scope,整個程式碼看起來順眼多了。

2. **ConstKeyGenerator** — 這個更有趣!它是一個「常數產生器」框架,專門用來把 Unity 中各種動態資料(場景列表、Tag/Layer、自訂資料)自動轉成 C# 常數類別。這次不只是重寫腳本而已,還順便幫它加了一些新功能:
   - 可以自訂 Namespace 和輸出路徑,而且會記住你的設定
   - 加了一個「全部產生」按鈕,一鍵搞定所有常數類別
   - 每個產生器現在都會顯示 HelpBox 告訴你它會掃描什麼資料、輸出到哪裡
   - 還加了 dry-run 機制,讓你在真正寫檔之前先預覽結果

## 用了哪些技術?

### 核心架構工具

整個重寫過程依賴幾個關鍵的基礎設施:

**EditorSettingLoader** — 這是一個設定檔持久化工具。每個編輯器視窗的設定(比如視窗大小、使用者偏好、上次使用的路徑)都透過它存成 JSON 檔,下次開啟時自動還原。之前的版本是每個視窗自己寫 JSON,現在統一用這個 Loader,省下超多重複程式碼。

**FileHandler** — 提供各種檔案 I/O 的包裝方法,統一處理檔案讀寫、路徑轉換、錯誤處理。所有檔案操作都透過它,就不用到處寫 `try-catch`。

**TypeResolver** — 用反射機制在執行期找到所有繼承某個基底類別的型別。ConstKeyGenerator 就用它來找出所有的產生器子類別,然後自動顯示在 UI 上。

### 開發慣例與風格

這次重寫有一套很清楚的規則:

- **Namespace 統一** — Editor 腳本全部用 `EAS.Tool`,Runtime 腳本用 `EAS`
- **拒絕 Begin/End** — 所有 `EditorGUILayout.BeginHorizontal/EndHorizontal` 這類程式碼都改成 `using (new HorizontalScope()) { ... }`,讓縮排自動管理區塊範圍,再也不會忘記關 End
- **EditorKit 是好朋友** — 之前用 `EditorExtension.UnfocusWhenClick()`,現在改叫 `EditorKit.ClearFocusOnClick()`,功能一樣但名字更直覺
- **輕度差異化** — 這是最有趣的部分!雖然功能完全相同,但內部實作刻意用不同方式:
  - 變數名稱不同(比如 `process` 改叫 `proc`)
  - Region 組織方式不同
  - 有些地方用 LINQ,有些地方用 foreach
  - 錯誤訊息的文字完全改寫
  - 方法排列順序重新調整

為什麼要這樣做?因為這樣寫出來的程式碼在結構上就是「新的」,不會有任何直接複製的痕跡,但同時又保證功能完全相同。這種感覺很像是把一本小說用自己的話重新說一遍 — 劇情一樣,但說法不同。

### 開發加速器

在這個過程中,我還加強了 **EditorKit** 這個 UI 元件庫。最近新增的是 `FolderPathField`,專門用來讓使用者選擇資料夾路徑,還會顯示一個可愛的資料夾 icon。這個元件在 ConstKeyGenerator 裡就派上用場了,讓使用者能直觀地選擇輸出路徑。

另外還統一了視窗的「Reload」機制 — 以前每個 EditorWindow 都要寫一堆 `OnEnable/OnDisable/OnFocus` 來處理視窗生命週期,現在全部抽出來放在 Reload 方法裡,整個視窗只要在一個地方初始化就好。

## 遇到什麼挑戰?

### 挑戰一:如何「全新撰寫」卻保持功能一致

這個問題聽起來很矛盾對吧?要寫得「不一樣」,但又要做到「一樣的事」。

一開始我也有點不知道怎麼拿捏這個度。寫得太像,就失去重寫的意義;改得太多,又怕改壞功能。後來我發現關鍵是**分層思考**:

- **外層(API)絕對不能變** — 類別名稱、公開方法、參數、回傳值必須一模一樣
- **內層(實作)盡量求變** — 變數命名、演算法細節、程式碼組織方式可以隨意改

舉個例子,GitSubmodulePuller 有個方法叫 `PullSubmodule(string path)`,這個簽名不能改。但裡面怎麼執行 Git 指令、怎麼處理錯誤、用什麼資料結構儲存狀態 — 這些都可以用不同的方式寫。

最後我整理出一套「輕度差異化手法」:改變數名、調整方法順序、用 early return 替代巢狀 if、用 HashSet 替代 List+Contains...這些小改動累積起來,整份程式碼看起來就會很不一樣,但邏輯流程還是相同的。

### 挑戰二:避免過度設計

在重寫 ConstKeyGenerator 的時候,我一度很想把架構改得更抽象、更有彈性,加入更多設計模式...但我及時煞車了。

因為我意識到:這次的目標是「重寫」,不是「重構」。如果我改變了整個架構,那就不是重寫同一個東西,而是設計一個新東西了。

所以最後我只加了幾個「真正有用」的功能:
- Namespace 可編輯 — 因為原本寫死在程式碼裡,使用者想改很麻煩
- 全部產生按鈕 — 因為本來要一個一個點,很浪費時間
- Dry-run 預覽 — 因為寫檔前不知道會輸出到哪裡,容易覆蓋錯檔案

這些都是「增強易用性」,而不是「改變核心設計」。這個界線一旦抓準,整個重寫過程就順多了。

### 挑戰三:保持規律與動力

老實說,重寫 74 個腳本,還要再寫 144 個...這個工作量聽起來有點嚇人。

我的策略是**先挑有趣的模組做**。像 GitSubmodulePuller 和 ConstKeyGenerator 都是功能明確、有立即回饋的工具 — 寫完可以馬上開啟編輯器視窗玩玩看,有種「做出東西」的成就感。

相比之下,一些純 Runtime 的 Utility 類別就比較枯燥(雖然也很重要),所以我把它們留到後面,穿插著做,避免一直寫類似的東西寫到膩。

另外我還建立了一份詳細的**進度追蹤文件** (`eas-rewrite-plan.md`),把所有 200 個腳本列成清單,每完成一個就打勾。這種視覺化的進度回饋真的很有幫助 — 看著勾勾越來越多,就會有「我快完成了!」的感覺,即使實際上還有一半要做。

### 挑戰四:不同模組的依賴關係

有些模組之間有依賴關係,不能隨便調換順序。比如說 ConstKeyGenerator 依賴 EditorKit 的 `FolderPathField`,所以一定要先寫 EditorKit 的擴充,才能寫 ConstKeyGenerator。

一開始我沒注意到這點,結果寫到一半發現缺東西,又要回去補。後來學乖了,會先看一下 `using` 清單,確認所有依賴的模組都寫好了才開始動工。

這也是為什麼我先把 Runtime 核心模組(FileHandler、SettingLoader、TypeResolver 等)優先完成 — 因為它們是地基,其他 Editor 工具都會用到。

## 下一步

接下來的計畫:

1. **繼續攻克中等規模的模組** — 像是 DataEditor、AssetHub 的部分功能
2. **開始啃大魔王級模組** — BuildTool、Timeline、Flowchart 這些檔案數多、邏輯複雜的模組
3. **建立自動化測試** — 隨著腳本數量增加,我開始擔心有沒有哪裡寫錯但沒發現,可能需要寫一些簡單的測試來確保功能正確
4. **整理規劃文件** — 把目前的經驗和模式整理成更清楚的指南,方便後續加速

如果這篇文章你看到這裡還沒睡著,那我真的很感謝!這個重寫之旅還在進行中,未來幾週應該還會有更多故事可以分享。我們下次見!

→ 繼續閱讀：[[專案/EAS Foundation/日誌/#02-Runtime-核心與效能大作戰-從GC地獄到零配置天堂|#02 Runtime 核心與效能大作戰]]

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案主頁]]
