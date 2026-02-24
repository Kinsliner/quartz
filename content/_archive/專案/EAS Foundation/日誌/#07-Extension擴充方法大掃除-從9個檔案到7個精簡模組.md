---
title: "#07 Extension 擴充方法大掃除 — 從 9 個檔案到 7 個精簡模組"
tags: [extension-methods, api-design, code-cleanup, refactoring, EAS Foundation]
created: 2026-02-16
---

# Phase 7: Extension 擴充方法大掃除 — 從 9 個檔案到 7 個精簡模組

## 這次做了什麼?

這次的重點是處理 **EAS Foundation 的 Extension 擴充方法模組**。這個模組包含了 9 個擴充方法檔案,提供各種便利的輔助功能。

經過一輪檢視後,發現這些擴充方法裡藏了不少問題:重複的功能、語意錯誤的命名、過時的實作方式、還有一些根本沒人在用的冗餘方法。所以這次的任務就是 **大掃除** — 移除冗餘、修正錯誤、統一命名、補齊缺漏。

### 處理成果總覽

最終結果:
- **保留**: 7 個擴充方法檔案 (CheckExtension, ColliderExtension, CollectionExtension, MathExtension, ReflectionExtension, TransformExtension, ValueExtension)
- **移除**: 2 個檔案 (FileExtension, InputExtension)
- **修正**: 大量 bug 與語意錯誤
- **精簡**: 移除 20+ 個冗餘方法
- **補完**: 新增缺漏的工具方法

### 1. CheckExtension — 修正泛型參數命名

這個檔案提供一堆 `IsNullOrEmpty` 檢查方法,支援字串、陣列、List、Dictionary 等各種集合類型。

發現一個尷尬的泛型參數命名問題:

```csharp
Dictionary<T, T>     // 兩個泛型參數都叫 T
Dictionary<TKey, TValue>  // 語意清楚
```

原本的寫法會讓編譯器誤以為 Key 和 Value 必須是同一種類型,雖然實際上編譯器會自動推斷,但這種命名方式容易造成誤解。

另外還移除了一些多餘的約束:

```csharp
where T : class  // 集合方法不需要這個約束
```

集合的元素可以是 value type,加上 `class` 約束反而限制了使用範圍。

### 2. ColliderExtension — 保留實用工具

這個檔案只有兩個方法,但都挺實用的:

- **ContainsPoint(point, tolerance)** — 判斷點是否在 Collider 範圍內,支援容差值
- **GetMaxSizeCollider(colliders)** — 從一堆 Collider 裡找出體積最大的

這兩個方法都是「Unity 本來應該提供但沒提供」的實用工具,所以完整保留,只做了些程式碼風格調整。

### 3. CollectionExtension — 大刀闊斧整理

這個檔案是重災區,有一堆重複功能和奇怪設計。

#### 合併重複方法

原本有兩組功能完全一樣的方法:

```
TryFind / TryGet → 合併為 TryFind
GetRandom / RandomPick → 合併為 RandomPick
```

#### 修正嚴重 bug

**RandomPick 的 off-by-one 錯誤**:

```csharp
list.RemoveRange(min - 1, count)  // 少取一個元素
list.RemoveRange(min, count)      // 正確的索引
```

**Remove(Predicate) 的 value type 問題**:

原本的實作會檢查 `item != null`,但如果 item 是 value type (例如 int),這個檢查會編譯錯誤。修正方式是改用 `!EqualityComparer<T>.Default.Equals(item, default)`。

#### 改名避免混淆

**Map → ForEach**

原本有個方法叫 `Map`,但它的功能其實是「對每個元素執行操作」,並不是函數式編程裡的 Map (轉換並回傳新集合)。改名為 `ForEach`,這樣一看就知道是「遍歷執行」而不是「轉換映射」。

#### 新增補完方法

**RandomElement** — 隨機取單一元素。原本有 `RandomPick(min, max)` 可以取一個範圍,但如果只是想隨機取一個元素,還要寫 `RandomPick(0, 0)` 很繁瑣。

#### 移除冗餘方法

- **Dictionary.TryAdd** — .NET Standard 2.1 已內建,不需要擴充方法了
- **ForEach(Action\<KeyValuePair\>)** — 直接用 `foreach` 就好,沒必要包一層

### 4. MathExtension — 修正參數順序與簡化實作

#### Between 參數順序錯誤

原本的方法簽名是 `Between(max, min)`,這跟一般人的直覺完全相反。修正為 `Between(min, max)`,符合常見習慣。

#### 移除 IsZero 冗餘 epsilon

原本有個 `IsZero(float value)` 方法,內部硬編碼 `epsilon = 0.0001f`。問題是 Unity 本來就有 `Mathf.Approximately(value, 0)`,而且它的 epsilon 處理更完善。直接移除這個方法,改用 Unity 內建的。

#### RotateVector3Point 改為擴充方法

原本是靜態方法 `MathExtension.RotateVector3Point(point, angle, axis)`,改為擴充方法後變成:

```csharp
point.Rotate(angle, axis)
```

語意更流暢,更符合擴充方法的設計理念。

### 5. ReflectionExtension — 從 12 個方法簡化為 4 個

這個檔案有一堆重複的方法,原因是沒注意到 **Type 繼承自 MemberInfo**。

原本有:
```
GetName(MemberInfo) / GetName(Type)
GetMenu(MemberInfo) / GetMenu(Type)
...
```

但因為 Type 繼承 MemberInfo,所以 MemberInfo 的版本已經可以處理 Type 了,不需要額外寫一個 Type 版本。

精簡後只保留:
```
GetName(MemberInfo)
GetMenu(MemberInfo)
GetShortName(Type)           // 確實是 Type 特有的功能
GetNameWithNamespace(Type)   // 確實是 Type 特有的功能
```

從 12 個方法砍到 4 個,功能完全沒變,只是移除了重複的 overload。

### 6. TransformExtension — 移除重複與修正 bug

#### 移除冗餘 GetRootParent

Unity 本身就有 `transform.root`,幹嘛還要寫個 `GetRootParent()` 包一層?直接刪除。

#### IsParentOf 簡化

原本有個 `IsParentOf(Transform parent, Transform child)` 靜態方法,但 Unity 已經有 `child.IsChildOf(parent)`,功能完全一樣。移除冗餘。

#### FindAncestor 改名

原本叫 `GetRootParent(Predicate)`,但它的功能其實是「往上找符合條件的第一個祖先節點」,並不一定會找到 root。改名為 `FindAncestor`,語意更準確。

#### ChangeLayerForAll 修正 bug

```csharp
transform.Find(child.name)  // 會找錯對象
直接用 child               // 正確的引用
```

`transform.Find()` 會搜尋整個子樹,如果有重名的子物件就會找錯。既然已經有 `child` 引用了,直接用它就好。

#### SortByHierarchy 簡化

直接 in-place sort:

```csharp
list.Sort((a, b) => a.GetSiblingIndex().CompareTo(b.GetSiblingIndex()))
```

不需要額外配置記憶體,效能更好。

### 7. ValueExtension — 語意修正與系列補完

#### 移除 11 個冗餘方法

以下這些方法都有更好的替代方案,直接移除:

- **GetCharLength** — `value.ToString().Length` 就好
- **ToPercentString** — `string.Format("{0:P}", value)` 更標準
- **MergeToString** — `string.Join()` 已經很好用
- **ConvertToString** — `ToString()` 本來就有
- **ToFullMessage** — Exception 已經有 `ToString()` 包含完整訊息

#### 修正語意反轉的命名

**Max/Min → AtMost/AtLeast**

原本有 `Max(value, limit)` 和 `Min(value, limit)`,但它們的功能跟名字完全相反:

```csharp
value.Max(10)  // 你以為是「最大值」,其實是「不超過 10」
value.Min(5)   // 你以為是「最小值」,其實是「不低於 5」
```

改名後:

```csharp
value.AtMost(10)   // 「不超過 10」,語意清楚
value.AtLeast(5)   // 「不低於 5」,語意清楚
```

#### 補完系列方法

**Rich Text 系列補完**:

```csharp
ToBoldString()    // <b>text</b>
ToItalicString()  // <i>text</i>
```

**LayerMask 系列補完**:

```csharp
Clamp01()          // 限制在 0~1 範圍 (float 專用)
RemoveLayer()      // 移除指定 layer
ContainsLayer()    // 檢查是否包含指定 layer
```

### 8-9. FileExtension 與 InputExtension — 直接移除

**FileExtension** — 零引用,而且現在都用 UnityEngine.AssetDatabase 或 System.IO,這個擴充方法沒存在價值。

**InputExtension** — 零引用,而且內部用 `Camera.main` 這種反模式 (每次呼叫都要搜尋整個場景),效能很差。現代做法是用 InputSystem 或注入 Camera 引用,不需要這種擴充方法。

## 用了哪些技術?

### Extension Method 設計原則

好的擴充方法應該:

1. **補充內建 API 的不足** — 例如 Unity 沒有提供 `Collider.ContainsPoint`,所以我們自己寫
2. **簡化常見操作** — 例如 `list.RandomElement()` 比 `list[Random.Range(0, list.Count)]` 更易讀
3. **保持語意清晰** — 方法名稱要一看就懂,不能跟內建方法混淆
4. **避免重複造輪子** — 如果內建已經有了,就不要再寫一個

### 泛型約束的正確使用

泛型約束 `where T : class` 會限制泛型參數必須是 reference type,但很多時候這個約束是不必要的。

移除不必要的約束後,`List<int>`、`List<string>`、`List<MyClass>` 都能用同一個方法,適用範圍更廣。

### Value Type 的 null 檢查陷阱

在泛型方法裡寫 `item != null`,如果 `T` 是 value type (例如 int) 就會編譯錯誤。

正確的寫法是用 `EqualityComparer<T>.Default`:

```csharp
!EqualityComparer<T>.Default.Equals(item, default)
```

這樣不管 reference type 還是 value type 都能正確處理。

### In-Place Sort vs 建立新列表

In-place sort 的優點:
- 不需要額外記憶體配置
- 效能更好 (尤其是大列表)
- 避免 GC 壓力

對於「排序」這種操作來說,通常就是想要直接改變原列表,所以 in-place sort 更合適。

### Mathf.Approximately 的 epsilon 處理

Unity 的 `Mathf.Approximately` 內部使用動態 epsilon,會根據數值大小自動調整容差範圍,比硬編碼 `epsilon = 0.0001f` 更可靠。

## 遇到什麼挑戰?

### 挑戰 1: 如何判斷方法是否冗餘?

我的判斷標準是:

1. **內建已有同等功能** → 刪除 (例如 Dictionary.TryAdd)
2. **只是包一層簡單呼叫** → 刪除 (例如 GetCharLength)
3. **語意不清或容易誤用** → 刪除或重新命名 (例如 Max/Min)
4. **補充內建不足** → 保留 (例如 ContainsPoint)
5. **簡化複雜操作** → 保留 (例如 RandomPick)

### 挑戰 2: 語意反轉的命名該怎麼修正?

一開始我想說「改成 Clamp 就好」,但 Clamp 是「限制在某個範圍內」,跟「不超過某個值」的語意還是有點不同。

後來想到用 **AtMost/AtLeast** — 這是很常見的英文慣用語:

- "at most 10" = 最多 10,不能超過
- "at least 5" = 最少 5,不能低於

這樣命名既符合英文語意,也跟數學概念一致,而且不會跟其他方法混淆。

### 挑戰 3: RandomPick 的 off-by-one bug 怎麼發現的?

我是在看程式碼時覺得 `min - 1` 這個寫法很奇怪 — 為什麼要減 1?索引不是應該直接用 min 嗎?

於是我手動追蹤了幾個情境:

```
假設 list = [A, B, C, D, E],想要 RandomPick(1, 3)

期望: 隨機移除 [B, C, D] 其中一部分
實際: RemoveRange(0, count) ← 從索引 0 開始移除,會移除 A!
```

這才發現原本的實作邏輯完全錯了。這個案例告訴我:**看到奇怪的運算就要多想一下,說不定就是 bug**。

### 挑戰 4: Type 繼承 MemberInfo 導致的重複方法

ReflectionExtension 有一堆重複的 overload,一開始我以為是故意設計成這樣,讓使用者可以選擇傳 Type 或 MemberInfo。

後來查了 MSDN 才發現 — **Type 本來就繼承自 MemberInfo**!

這意味著所有接受 MemberInfo 參數的方法,自動就能接受 Type 參數,根本不需要額外寫一個 Type 版本。

移除重複的 overload 後,程式碼量少了一半,功能完全沒變。

### 挑戰 5: ChangeLayerForAll 的 Find 陷阱

這個 bug 很隱蔽,因為大部分情況下 `transform.Find(child.name)` 確實會找到正確的子物件。

但如果場景裡有重名的物件,或者子物件結構比較複雜,Find 可能會找到錯的對象,導致設定 layer 時出錯。

我一開始沒注意到這個問題,直到看到程式碼時想:**既然已經有 child 引用了,為什麼還要 Find?**

這才意識到原本的實作有問題。修正後直接用 child,既正確又高效。

### 挑戰 6: 移除 InputExtension 的決策

InputExtension 裡有些方法看起來挺實用的,例如「世界座標轉螢幕座標」、「滑鼠點擊檢測」等等。

但仔細看會發現它們都用了 `Camera.main` — 這是 Unity 裡的反模式,因為每次呼叫都要搜尋整個場景找 MainCamera tag,效能很差。

而且這些方法的使用情境都很特定,不適合放在通用框架裡。現代做法是用 InputSystem 或注入 Camera 引用,不需要這種擴充方法。

最終決定直接移除,如果以後真的需要,可以用更好的方式重新實作。

## 學到了什麼?

### 經驗 1: 擴充方法不是越多越好

**精簡的 API 比豐富的 API 更好用** — 只保留真正實用、語意清晰的方法,使用體驗反而更好。因為每個擴充方法都會出現在 IntelliSense 自動完成清單裡,太多反而造成選擇困擾。

### 經驗 2: 命名要符合直覺,不能反直覺

Max/Min 的命名問題讓我深刻體會到 — **方法名稱一定要符合使用者的直覺**。

如果方法名稱跟實際功能相反,使用者很容易用錯,而且這種錯誤很難 debug,因為程式碼看起來完全正常,只是邏輯跟預期相反。

### 經驗 3: 內建 API 永遠比自己實作更可靠

能用內建 API 就用內建 API。Mathf.Clamp、Mathf.Approximately、string.Format 這些內建方法,都經過大量測試和優化,可靠性遠高於自己實作的版本。

### 經驗 4: 泛型約束要謹慎使用

`where T : class` 這種約束看起來很安全,但實際上常常是不必要的限制。**只在真的需要 reference type 特性時才加約束**,其他情況盡量不加,保持泛型的通用性。

### 經驗 5: 繼承關係會影響 API 設計

Type 繼承 MemberInfo 這個事實讓我意識到 — **設計 API 前要先了解類型的繼承關係**。

如果你的方法接受基底類別參數,就不需要再為每個衍生類別寫一個 overload,因為多型會自動處理。

### 經驗 6: 效能問題要在設計階段就考慮

`Camera.main` 看起來很方便,但每次呼叫都要搜尋整個場景,如果在 Update 裡呼叫會造成嚴重效能問題。正確的做法是在初始化時取得 Camera 引用並快取,或者用依賴注入的方式傳入。

## 目前進度

這次的提交:

- **Commit cfc7b96**: Extension 擴充方法集 (7 檔案, 957 行)

加上前面的進度:

- **已提交**: 158 個檔案 (+7)
- **未提交**: 23 個檔案
- **已移除**: 22 個檔案 (+2)

整個 EAS Foundation 的重寫工作已經完成大約 **87%**,離終點越來越近了!

## 下一步

Extension 模組整理完後,接下來應該要處理:

1. **Service/Event/Flow 核心系統** — 框架的核心機制還沒碰
2. **未提交的 23 個檔案** — 檢視這些檔案該保留還是移除
3. **整合測試** — 確保所有模組能正常運作

目標是在接下來幾個 Phase 內完成所有檔案的處理,讓整個框架重構畫下完美句點!

→ 繼續閱讀：[[專案/EAS Foundation/日誌/#08-BuildTool-最後一塊拼圖終於到位|#08 BuildTool — 最後一塊拼圖終於到位]]

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案主頁]]
