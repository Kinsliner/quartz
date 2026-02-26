---
title: "#02 Runtime 核心與效能"
tags: [Unity, C#, GC Optimization, Data Structures, Performance]
created: 2026-02-15
phase: 2
---

> **Tech** C#, Unity Runtime, ObserverList, struct Enumerator
>
> **AI** Claude Code

## 源起

Phase 1 搞定了 Editor 工具和基礎設施，這次輪到跑在玩家裝置上的 Runtime 核心模組。這些東西每一幀都在執行，效能差一點就直接影響遊戲流暢度，所以不只是「寫得不一樣」，還要「寫得更好」。

## 設計

核心問題出在 UpdateHandler。它用 `List<IUpdate>` 存所有需要每幀更新的物件，遍歷時如果有物件把自己從 list 移除，就會「迭代中修改集合」直接炸掉。傳統解法是每幀 `list.ToArray()` 拍快照再遍歷，安全是安全了，但每幀都產生新陣列，GC 壓力很大。

設計了 **ObserverList\<T\>** 解決這個問題：

1. 內部用 `List<T>` 存資料
2. 維護 `isDirty` 旗標和 `cachedSnapshot` 陣列
3. list 被修改時設 `isDirty = true`
4. 迭代時檢查——dirty 就重建快照，clean 就直接用快取

遊戲執行期 list 內容很少變動，`isDirty` 大部分時候是 false，一直重複使用同一個快照，完全沒有 GC。再加上 struct Enumerator 支援 duck-typed foreach，整個遍歷過程零 allocation。

命名想了很久——SafeList 太籠統、IterationSafeList 太長、CachedSnapshotList 太技術。最後選 ObserverList，因為它就是 Observer Pattern 的一種應用：一堆 observer 要通知，這個 list 專門存放和迭代 observers。

## 實現

**三個 UpdateHandler 全面改用 ObserverList。** UpdateHandler、FixedUpdateHandler、LateUpdateHandler 從「每幀產生垃圾」變成「完全零配置」。

**CursorLocker 重新設計。** 原版只有 Lock/Unlock，多個系統同時搶控制游標就亂了——UI 系統想顯示游標，FPS 控制器想隱藏，誰說了算？新版用 `Dictionary<object, CursorRequest>` 管理所有請求，每個請求帶優先權數字，系統根據最高優先權決定游標狀態。

key 的選型：字串容易拼錯、enum 每次新增要改定義，最後選 `object`——系統用自己的實例當 key，自動唯一。優先權用數字，簡單直觀。

**SceneLoader API 簡化。** 原本 7 個重載方法，參數組合眼花撩亂。梳理後只需 5 個：LoadSceneAdditive、LoadSceneAdditiveAsync、UnloadScene、UnloadSceneAsync、TryGetInstance。

**實用工具模組一次提交 8 個：** CoroutineRunner、CursorLocker、EzCopy、GizmosDebugger、Installer、ParticleTester、SceneLoader、Utility。

**Extension 整合。** DebugPlus、Gadget、UguiUtility 三個零散的工具類別功能拆散到 CollectionExtension、MathExtension、TransformExtension。12 個舊檔案直接刪除。

**FPS 顯示的小坑。** 原本用 `Time.deltaTime` 算 FPS，遊戲暫停（timeScale = 0）就爆掉。改用 `Time.unscaledDeltaTime`，不受 timeScale 影響。

**刪除的勇氣。** 整理 Utility 模組時發現 DebugPlus.cs 零引用。定了原則：目前專案沒有任何引用、功能非核心必需就大膽刪。Git 歷史裡永遠找得回來。12 個檔案砍掉，codebase 清爽不少。

## 尾聲

| 項目 | 結果 |
|------|------|
| 累計完成 | ~85 個腳本 |
| 刪除檔案 | 12 個 |
| 重大重構 | ObserverList, CursorLocker |
| 進度 | ~54% |

效能優化不一定要寫很複雜的程式碼。ObserverList 的設計很簡單——換個資料結構、加個快取機制，就從每幀產生垃圾變成完全零配置。

