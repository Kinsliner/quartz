---
title: "#04 Editor 工具、UI 元件、Extension"
tags: [Unity, IMGUI, PropertyDrawer, TreeView, Extension Methods, UI]
created: 2026-02-16
phase: 4
---

> **Tech** C#, Unity Editor IMGUI, PropertyDrawer, IDragHandler, Extension Methods
>
> **AI** Claude Code

## 源起

前三個 Phase 把 Runtime 核心和 AssetHub 搞定了，剩下一批 Editor 工具、UI 元件和 Extension 擴充方法散落各處還沒處理。這個階段集中收拾這些東西。

## 設計

**Editor 工具。** DirectoryNode 用不可變設計（所有欄位 readonly），避免多處引用同一節點時的副作用。SerializeDic 解決 Unity 原生不支援序列化 Dictionary 的問題。

**UI 元件重寫。** SliderInputLinker 對齊 Unity Slider API 降低學習成本，UIDrag 從 Update 輪詢改成事件驅動。

**Extension 清理原則。** 內建已有同等功能就刪、只是包一層簡單呼叫就刪、語意不清就改名、補充內建不足就保留。

## 實現

### Editor 工具

**DirectoryNode + DirectoryTreeDrawer。** 不可變樹狀資料結構配 IMGUI 繪製器，在 Editor 視窗用 Foldout 展開/收合瀏覽。展開狀態存 `Dictionary<DirectoryNode, bool>`。

Icon 對齊是最痛苦的部分——`EditorGUIUtility.IconContent` 會自動縮放 icon，怎麼調都不對。最後放棄用它，改用 `GUI.DrawTexture` 手動畫 16x16 方框，完全控制位置和大小。副檔名轉 icon 的邏輯封裝到 EditorKit 作為公開方法，涵蓋 3D 模型、音訊、圖片、動畫、影片等幾十種格式。

縮排調了五六次。公式裡多加一個 `IndentWidth` 讓檔案比資料夾多縮一層，視覺效果反而更亂。改回 `depth * IndentWidth + 12` 才對。UI 差幾個像素感覺就完全不同。

**SerializeDic + SerializeDicDrawer。** 新增 key-value 配對時如果 key 已存在，Unity 序列化系統會默默把重複項刪掉，連警告都不給。解法是新增時自動遞增產生不重複的預設 key（NewKey → NewKey1 → NewKey2），加上安全上限 1000 次避免極端情況的無限迴圈。

### UI 元件重寫

**SliderInputLinker。** 原本的 API 自成一套，改成模仿 Unity Slider 命名——value、minValue、maxValue、interactable、SetValueWithoutNotify()。核心問題是雙向同步的循環觸發：Slider 改了更新 InputField、InputField 改了更新 Slider、無限循環。統一走一個 `SetValue(value, notify)` 入口，內部靜默更新兩個 UI 元件，只在 notify=true 時才觸發 onValueChanged。

**UIDrag。** 原本在 Update 裡每幀 `Input.GetMouseButton(0)`，即使沒在拖曳也跑。改用 `IBeginDragHandler/IDragHandler/IEndDragHandler` 事件介面，有事才做事。只支援 Screen Space - Overlay 模式——研究過支援 Camera 和 World Space，發現等於寫三個不同元件。專注做好一件事比什麼都想做好。

**MeshClosure 和 PushButtonSwitch 移除。** 前者高度依賴特定專案的網格結構，後者功能跟 Unity Toggle 重複。通用框架專注通用需求。

### Extension 大掃除

9 個檔案逐一檢視，最終保留 7 個，移除 FileExtension（零引用）和 InputExtension（用 `Camera.main` 反模式，每次呼叫搜尋整場景），砍掉 20+ 個冗餘方法。

**語意反轉修正。** `value.Max(10)` 直覺是「最大值」，實際功能是「不超過 10」。改名 AtMost / AtLeast。`Map` 改 `ForEach`——功能是遍歷執行，不是函數式轉換。

**RandomPick off-by-one。** `list.RemoveRange(min - 1, count)` 少取一個元素，手動追蹤幾個情境才發現。看到奇怪的運算就要多想一下。

**Remove(Predicate) 的 value type 問題。** 原本 `item != null` 檢查如果 T 是 int 會編譯錯誤，改用 `EqualityComparer<T>.Default.Equals(item, default)`。

**Type 繼承 MemberInfo。** ReflectionExtension 有 12 個方法，一半是重複 overload——因為 `Type` 繼承 `MemberInfo`，所有接受 MemberInfo 的方法自動能處理 Type。砍到 4 個，功能沒變。

**其他修正：** CheckExtension 的 `Dictionary<T, T>` 泛型參數改成 `<TKey, TValue>`、MathExtension 的 `Between(max, min)` 參數順序反了改回 `(min, max)`、TransformExtension 的 `ChangeLayerForAll` 用 `transform.Find(child.name)` 會找錯對象（重名問題），直接用已有的 child 引用。冗餘方法如 `GetRootParent()`（Unity 有 `transform.root`）、`Dictionary.TryAdd`（.NET Standard 2.1 已內建）、`IsZero(float)` （`Mathf.Approximately` 更可靠）全部移除。

## 尾聲

| 項目 | 結果 |
|------|------|
| 累計完成 | ~158 個 |
| 未提交 | ~23 個 |
| 已移除 | ~22 個 |
| Extension | 9 → 7 個檔案，移除 20+ 冗餘方法 |
| 進度 | ~87% |

Extension 大掃除砍掉大量冗餘。精簡的 API 比豐富的 API 更好用——每個擴充方法都會出現在 IntelliSense 裡，太多反而造成選擇困擾。

