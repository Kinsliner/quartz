---
title: "#02 Runtime 核心與效能大作戰 — 從 GC 地獄到零配置天堂"
tags: [Unity, C#, 效能優化, GC, 資料結構, Runtime, EAS Foundation]
created: 2026-02-15
---

# Phase 2: Runtime 核心與效能大作戰 — 從 GC 地獄到零配置天堂

## 這次做了什麼?

上次我們聊到了編輯器工具的重寫之旅,這次要來聊聊更硬核的部分 — **Runtime 核心模組**。

如果說編輯器工具是「開發時期的好幫手」,那 Runtime 模組就是「遊戲執行時的心臟」。這些東西跑在玩家的裝置上,每一幀都在執行,效能稍微差一點就會直接影響遊戲流暢度。所以這次的重寫,我特別在意「怎麼寫得更好」,而不只是「怎麼寫得不一樣」。

### 這次完成的模組

**核心資料結構:**
- **ObserverList\<T\>** — 全新設計的迭代安全泛型列表(這是重點!)
- **EventBus** — 事件系統(已在 Phase 1 完成,但這次優化了配合 UpdateHandler 使用)
- **EzSerialize** — 序列化系統(之前完成)

**核心 Runtime 系統:**
- **UpdateHandler / FixedUpdateHandler / LateUpdateHandler** — 三大更新系統,全部改用 ObserverList 達成零 GC
- **FPSDisplay / FPSGUIDisplay** — FPS 顯示工具,前者用 Canvas,後者用 OnGUI

**實用工具模組(8 個檔案一次提交):**
- **CoroutineRunner** — 協程執行器
- **CursorLocker** — 游標鎖定系統(重新設計!)
- **EzCopy** — 深拷貝工具
- **GizmosDebugger** — Gizmos 繪製工具
- **Installer** — 系統安裝器
- **ParticleTester** — 粒子測試工具
- **SceneLoader** — 場景載入系統(API 大簡化!)
- **Utility** — 通用工具類別

**程式碼重組:**
- 合併了三個小工具類別:DebugPlus、Gadget、UguiUtility 全部移除,功能分散到 Extension 系列
- 完成 CollectionExtension、MathExtension、TransformExtension 三個擴充類別(準備提交中)
- 刪除了 12 個檔案,精簡專案結構

### 統計數字嚇死人

- **已完成:** ~85 個腳本
- **剩餘:** ~73 個腳本 (+ 4 個跳過不處理)
- **刪除:** 12 個檔案
- **重大重構:** 2 個(ObserverList 和 CursorLocker)

## 用了哪些技術?

### 技術亮點一:ObserverList\<T\> — 零 GC 的迭代安全列表

這是這次重寫的最大亮點!

**問題背景:**
原本的 UpdateHandler 有個經典問題 — 它用 `List<IUpdate>` 儲存所有需要更新的物件,然後每一幀執行:

```
遍歷 list → 呼叫每個物件的 Update()
```

聽起來沒問題對吧?但魔鬼藏在細節裡:如果某個物件在 Update 裡面把自己從 list 移除(或者加入新物件),就會發生「迭代中修改集合」的錯誤,Unity 會直接炸給你看。

**傳統解法:**
用 `list.ToArray()` 先拍個快照,然後遍歷陣列:

```
快照陣列 = list.ToArray()
遍歷快照陣列 → 呼叫 Update()
```

這樣確實安全了,但每一幀都要 `ToArray()`,每次都會產生新的陣列記憶體,然後 GC 就來了...**每一幀都產生垃圾!**

**我的解法:ObserverList\<T\>**

設計概念很簡單:

1. 內部用 `List<T>` 儲存資料
2. 維護一個 `isDirty` 旗標
3. 快取一個 `cachedSnapshot` 陣列
4. 當 list 被修改時,設定 `isDirty = true`
5. 需要迭代時,檢查 `isDirty`:
   - 如果是 `true` → 重新產生快照,設為 `false`
   - 如果是 `false` → 直接用快取的快照

**魔法在哪?**

如果你的 list 內容不常變動(大部分遊戲執行時都是這樣),那 `isDirty` 大部分時候是 `false`,於是就**一直重複使用同一個快照陣列,完全沒有 GC!**

只有在真正新增/移除物件時才會重建快照,而這種情況相對少見。

**更進一步:duck-typed foreach**

我還實作了一個 struct Enumerator,讓你可以直接用 `foreach` 語法:

```csharp
foreach (var item in observerList)
{
    item.Update();
}
```

因為 Enumerator 是 struct,所以這個 foreach 迴圈**完全不產生任何 GC allocation!**

這個設計讓 UpdateHandler 從「每幀產生垃圾」變成「完全零配置」,效能提升超有感!

### 技術亮點二:CursorLocker 的優先權系統

原本的 CursorLocker 很簡單:

```
Lock() → 鎖定游標
Unlock() → 解鎖游標
```

但這有個問題:如果同時有多個系統都想控制游標(比如 UI 系統想顯示游標,FPS 控制器想隱藏游標),誰說了算?

**重新設計:請求優先權系統**

新版本用 `Dictionary<object, CursorRequest>` 來管理所有請求:

- 每個系統用自己的參考物件當 key,註冊一個請求
- 每個請求都有優先權(priority)
- CursorLocker 會根據「優先權最高的請求」來決定游標狀態
- 當某個系統不再需要時,就移除它的請求

這樣多個系統可以和平共處,誰的優先權高誰就贏。之前那種「最後一個呼叫 Lock 的人說了算」的混亂局面就不會再發生了。

### 技術亮點三:SceneLoader API 簡化

原本的 SceneLoader 有 7 個重載方法,各種參數組合讓人眼花撩亂。

這次我重新梳理,發現其實只需要 **5 個清楚的方法**:

- LoadSceneAdditive(name, callback)
- LoadSceneAdditiveAsync(name)
- UnloadScene(name, callback)
- UnloadSceneAsync(name)
- TryGetInstance(out instance)

參數少了,命名清楚了,用起來就順手多了。

### 技術亮點四:Extension 系列整合

之前有很多小工具散落在 DebugPlus、Gadget、UguiUtility 裡面,這次全部整合到三個 Extension 類別:

- **CollectionExtension** — SwapWith 等集合操作
- **MathExtension** — Randomize 等數學工具
- **TransformExtension** — SortByHierarchy、ToTransforms、IsMouseHover 等 Transform 操作

這樣用起來更符合 C# 的慣例,也更好找。

## 遇到什麼挑戰?

### 挑戰一:ObserverList 的命名大戰

一開始這個類別叫什麼我想了很久。

- `SafeList`? → 太籠統,safe 是指執行緒安全還是迭代安全?
- `IterationSafeList`? → 太長,而且聽起來很笨重
- `CachedSnapshotList`? → 太技術細節,沒講清楚用途

最後選擇 **ObserverList**,因為這個 pattern 在設計上就是「Observer Pattern」的一種應用 — 你有一堆 observer(IUpdate 物件)要通知,而這個 list 專門用來存放和迭代這些 observers。

名字一定好,整個設計就有靈魂了。

### 挑戰二:CursorLocker 從簡單到複雜的演化

CursorLocker 是個很好的「需求演變」案例。

一開始我也想過直接照抄原本的簡單 Lock/Unlock 設計,反正能用就好。但後來想想,既然都要重寫了,為什麼不解決原本設計的問題?

於是我花了一些時間和自己(以及 AI 助手)討論:
- 要不要用字串 key? → 不好,容易拼錯
- 要不要用 enum 列舉所有系統? → 不好,每次新增系統要改 enum
- 要不要用 object 當 key? → 好!系統用自己的實例當 key,自動唯一

然後又討論優先權怎麼處理:
- 用先來後到? → 不好,無法處理重要度
- 用數字優先權? → 好!簡單直觀

最後就變成現在這個「多系統優先權請求管理」的設計。

雖然比原本複雜一點,但解決的問題更多,用起來也更穩健。

### 挑戰三:FPS 計算的小陷阱

在重寫 FPSDisplay 時,我發現原本的程式碼用 `Time.deltaTime` 來計算 FPS。

乍看沒問題,但如果遊戲暫停(`Time.timeScale = 0`),deltaTime 就變成 0,FPS 顯示就爆炸了。

解法很簡單:改用 `Time.unscaledDeltaTime`,這個值不受 timeScale 影響。

這種小細節如果不注意,很容易在測試時漏掉,結果遊戲上線後玩家暫停就看到 FPS 爆表...

### 挑戰四:整合與刪除的取捨

在整理 Utility 模組時,我發現有些功能其實很少用(比如 DebugPlus.cs 根本沒有任何地方引用)。

但刪除總是需要勇氣 — 萬一以後會用到呢?

後來我給自己定了一個原則:**如果目前專案沒有任何引用,而且功能不是核心必需,就大膽刪除。**真的需要的話,Git 歷史裡永遠找得回來。

這樣一來,專案就不會累積一堆「可能以後會用到」的殭屍程式碼,整個 codebase 保持精簡。

最後成功刪除了 12 個檔案,感覺整個專案都輕盈了!

## 下一步

這次 Runtime 核心模組算是告一段落了,接下來的計畫:

1. **提交 Extension 三兄弟** — CollectionExtension、MathExtension、TransformExtension 已經寫好,等著 commit
2. **繼續攻克其他 Runtime 模組** — Service、Flow、Stage、Timer、Transform、ObjectPool、Network 等
3. **處理更多 Editor 工具** — Console、DataEditor、AssetHub、BuildTool 等大傢伙
4. **測試與驗證** — 隨著模組越來越多,需要確保它們之間的整合沒問題

目前進度大約 **54%**(85/158 個有效檔案),感覺再努力一下就能看到終點了!

這次的重寫讓我學到:效能優化不一定要寫很複雜的程式碼,有時候只是換個資料結構、加個快取機制,就能從「每幀產生垃圾」變成「完全零配置」。ObserverList 的設計雖然簡單,但效果驚人,這種「小巧思帶來大改善」的感覺真的很棒!

我們下次見!

→ 繼續閱讀：[[專案/EAS Foundation/日誌/#03-AssetHub-大改造-從繼承地獄到Provider天堂|#03 AssetHub 大改造]]

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案主頁]]
