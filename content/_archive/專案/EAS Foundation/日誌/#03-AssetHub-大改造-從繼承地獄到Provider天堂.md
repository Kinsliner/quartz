---
title: "#03 AssetHub 大改造 — 從繼承地獄到 Provider 天堂"
tags: [Unity, 架構設計, Editor工具, 資源管理, 設計模式, EAS Foundation]
created: 2026-02-16
---

# Phase 3: AssetHub 大改造 — 從繼承地獄到 Provider 天堂

## 這次做了什麼?

這次要聊的是一個超級大工程 — **AssetHub 模組的完整重寫**!

AssetHub 是什麼?簡單來說,它就是「遊戲資源的統一載入系統」。你想載入一個音效、一張圖片、一個 Prefab?都跟 AssetHub 要就對了。它會幫你處理所有載入邏輯,你只需要告訴它「我要哪個資源」,它就會從正確的地方把資源拿給你。

聽起來很簡單對吧?但魔鬼藏在細節裡 — 資源可能來自 Resources 資料夾、可能是 AssetBundle、可能是 Addressable、甚至可能是動態產生的。每種來源的載入方式都不一樣,要怎麼統一管理?

這就是 AssetHub 要解決的問題,也是這次重寫的核心挑戰!

### 這次完成了什麼

**全新的架構設計:**
- 拋棄了原本的多層繼承 AssetLink 體系
- 採用扁平化的 `AssetHubEntry` + 可插拔式 **Provider/Registrar** 模式
- Runtime 提供 `AssetProvider` 基底類別(ResourceProvider、CacheProvider 內建實作)
- Editor 提供 `AssetRegistrar` 基底類別(ResourceRegistrar、CacheRegistrar 內建實作)
- 透過 `TypeResolver.FindDerivedTypes<T>()` 自動探索所有擴充實作,完全不用手動註冊!

**核心功能系統:**
- 引用計數機制(Load/Release 追蹤)
- `FormerProviderNameAttribute` 屬性支援向下相容的 Provider 重新命名
- Setting 系統整合(AssetHubSetting.cs + AssetHubTable.setting)

**編輯器工具(AssetHubEditor):**
- 基於 `ReorderableTable<EditEntry>` 建構,包含 6 個 Column 類別
- 完整中文化介面(儲存設定、載入設定、新增空項、加入選取項目)
- 搜尋欄過濾功能(支援 Label、Description、物件名稱)
- 批次資料夾匯入支援(拖曳資料夾自動遞迴加入所有資源)
- 拖放功能透過 `IDragDropReceiver` 介面實作
- 警告圖示提示無效狀態(無 Key、遺失資源)

**AI 資源探索功能:**
- 新增 `description`、`assetType`、`assetPath` 中繼資料欄位
- 建立 `AssetHubManifestGenerator` 自動產生 `UserSettings/ASSET_MANIFEST.md`
- Manifest 包含每個資源的 Description、Type、Provider、Path 資訊
- 讓 AI 能夠理解專案中有哪些可用資源!

**完整文件:**
- 建立 `ASSETHUB_EXTENSION_GUIDE.md` 擴充開發指南
- 建立 `AssetHubExample.cs` 使用範例

### 統計數字

- **提交檔案:** 16 個(5 個 Editor + 11 個 Runtime)
- **總進度:** 已完成 115 個檔案(48 Editor + 67 Runtime)
- **剩餘:** 70 個檔案(21 Editor + 49 Runtime,包含 4 個跳過)
- **已刪除:** 16 個檔案(MapID、Localization 等棄用模組)

這是目前為止**單一模組檔案數最多的一次提交**!

## 用了哪些技術?

### 技術亮點一:Provider 模式 — 從繼承樹到插件系統

這是整個重寫的核心!

**原本的設計:**

舊版用的是多層繼承的 AssetLink 體系:

```
AssetLink (抽象基底)
  ├─ ResourceLink
  ├─ AssetBundleLink
  ├─ AddressableLink
  └─ CustomLink
```

每種載入方式都是一個繼承類別,聽起來很物件導向對吧?

**問題在哪?**

1. **擴充困難** — 每次新增載入方式都要改 AssetHub 核心程式碼
2. **序列化複雜** — 多型序列化超級麻煩,容易出錯
3. **Editor 與 Runtime 混在一起** — 編輯器邏輯和執行階段邏輯糾纏不清
4. **重複程式碼** — 每個子類別都要處理相似的載入/卸載邏輯

**新的設計:Provider/Registrar 模式**

我把整個架構改成這樣:

```
Runtime 端:
  AssetHubEntry (單一資料類別,只存資料,不含邏輯)
    ├─ providerTypeName: string
    ├─ label: string
    ├─ description: string
    ├─ assetType: string
    └─ ...

  AssetProvider (抽象基底)
    ├─ Load()
    ├─ Release()
    └─ IsLoaded()

  ResourceProvider : AssetProvider
  CacheProvider : AssetProvider
  (任何人都可以寫自己的 Provider!)

Editor 端:
  AssetRegistrar (抽象基底)
    ├─ Register()
    └─ GetAssetType()

  ResourceRegistrar : AssetRegistrar
  CacheRegistrar : AssetRegistrar
  (任何人都可以寫自己的 Registrar!)
```

**魔法在哪?**

1. **AssetHubEntry 變成純資料** — 只存「這個資源叫什麼」「用哪個 Provider 載入」,不管「怎麼載入」
2. **Provider 負責 Runtime 載入邏輯** — 每個 Provider 專注做好自己的事
3. **Registrar 負責 Editor 註冊邏輯** — 編輯器程式碼和執行階段完全分離
4. **自動探索機制** — 用 `TypeResolver.FindDerivedTypes<AssetProvider>()` 掃描所有 Provider 實作,完全不用手動註冊

這樣的設計有什麼好處?

- 想新增 AddressableProvider?寫一個類別繼承 AssetProvider,完成!
- 想新增 Editor 支援?寫一個類別繼承 AssetRegistrar,完成!
- AssetHub 核心程式碼**完全不用改**!

這就是「開放封閉原則」的實踐 — 對擴充開放,對修改封閉。

### 技術亮點二:ReorderableTable 的深度應用

AssetHubEditor 的 UI 是用 `ReorderableTable<EditEntry>` 建構的,這是我在 Phase 1 時完成的表格工具。

這次是它第一次真正投入實戰,而且是**超級複雜的實戰**!

**挑戰:**

AssetHub 的每一行資料都包含:
- ID(唯讀)
- Label(可編輯文字)
- Description(可編輯文字)
- Provider 下拉選單(動態內容)
- Object 欄位(拖放資源)
- Info 欄位(顯示路徑或警告)

每個欄位的繪製邏輯都不一樣,而且還要處理拖放、搜尋過濾、警告提示等功能。

**解決方案:**

我為每個欄位建立了一個 Column 類別:
- `IDColumn` — 繪製唯讀 ID
- `LabelColumn` — 可編輯文字 + 搜尋過濾
- `DescriptionColumn` — 可編輯文字 + 搜尋過濾
- `ProviderColumn` — 動態 Provider 下拉選單
- `ObjectColumn` — 拖放資源 + 搜尋過濾
- `InfoColumn` — 路徑顯示 + 警告圖示

每個 Column 專注做好自己的事,Table 只負責排版和捲動。

這個設計讓整個 Editor 視窗的程式碼結構超級清晰,每次要改某個欄位的行為,直接找對應的 Column 類別就好,完全不會動到其他部分!

### 技術亮點三:AI 友善的資源探索

這是一個很特別的功能 — **讓 AI 能夠「看見」你的專案資源**。

**問題背景:**

在跟 AI 協作開發時,我常常遇到這個情況:

> 我:「幫我載入爆炸特效」
> AI:「好的,請問資源的路徑是?」
> 我:「呃...等我去找一下...」

AI 不知道我的專案裡有哪些資源,所以每次都要我手動提供路徑或資源名稱。

**解決方案:**

我在 AssetHubEntry 加入了三個中繼資料欄位:
- `description` — 資源的人類可讀描述
- `assetType` — 資源類型(Prefab、AudioClip、Texture2D 等)
- `assetPath` — 資源在專案中的路徑

然後建立了一個 `AssetHubManifestGenerator`,它會掃描所有 AssetHubEntry,產生一個 Markdown 檔案:

```markdown
# AssetHub Manifest

## explosion_vfx
- Description: 紅色爆炸特效,適合戰鬥場景
- Type: Prefab
- Provider: ResourceProvider
- Path: Assets/VFX/Explosion.prefab

## bgm_battle
- Description: 戰鬥背景音樂
- Type: AudioClip
- Provider: ResourceProvider
- Path: Assets/Audio/BGM_Battle.mp3
```

這個檔案會放在 `UserSettings/ASSET_MANIFEST.md`,然後在專案說明文件裡告訴 AI:「想知道有哪些資源可用,請查看 ASSET_MANIFEST.md」。

從此以後,AI 就能直接查表找資源了!

這個功能的靈感來自「怎麼讓 AI 更好地理解專案」的思考 — 與其每次都手動告訴它,不如建立一個機器可讀的資源清單,讓它自己查。

### 技術亮點四:FormerProviderName 的向下相容

這是一個很貼心的小功能。

**問題:**

假設我今天把 `ResourceProvider` 重新命名成 `UnityResourceProvider`,會發生什麼事?

所有舊的 Setting 檔案裡都寫著 `"providerTypeName": "ResourceProvider"`,載入時就會找不到對應的 Provider,資源全部掛掉!

**解決方案:**

我設計了一個 `FormerProviderNameAttribute`:

```csharp
[FormerProviderName("ResourceProvider", "OldResourceProvider")]
public class UnityResourceProvider : AssetProvider
{
    // ...
}
```

當 AssetHub 載入 Setting 時,如果找不到 `"ResourceProvider"`,就會去找有沒有哪個 Provider 標記了 `FormerProviderName("ResourceProvider")`,如果有就用那個!

這樣重新命名 Provider 就不會破壞舊專案的相容性,非常實用!

## 遇到什麼挑戰?

### 挑戰一:命名大作戰 — Assets vs AssetKeys

在設計程式碼產生器時,我遇到了一個命名衝突問題。

AssetHub 會自動產生一個常數類別,讓你用強型別的方式存取資源:

```csharp
AssetHub.Load<AudioClip>(???.explosion);
```

問號應該填什麼?

- `AssetKeys.explosion`?但 AssetCollector 模組已經用了 `AssetKeys` 這個名字!
- `AssetHubKeys.explosion`?太長了,每次都要打一堆字
- `Hub.explosion`?太短太籠統,容易跟其他系統混淆

最後我選擇了 **`Assets`** 這個名字:

```csharp
AssetHub.Load<AudioClip>(Assets.explosion);
```

簡潔、清楚、語意明確,而且跟 AssetCollector 的 `AssetKeys` 不衝突!

有時候命名真的比寫邏輯還難...

### 挑戰二:InfoColumn 的 NullReferenceException

這是一個經典的「粗心大意」錯誤。

在實作 InfoColumn 時,我在建構子裡忘記指派一個欄位:

```csharp
public InfoColumn(...)
{
    // 忘記寫: this.iconContent = ...
}

public override void DrawColumn(...)
{
    // 這裡用到 iconContent → 爆炸!
    GUI.Label(rect, iconContent);
}
```

結果一跑就 NullReferenceException,Unity 編輯器直接當掉。

Debug 了 10 分鐘才發現是建構子漏了一行...

**教訓:** 寫完建構子立刻檢查「所有欄位都指派了嗎?」,可以省下很多 Debug 時間。

### 挑戰三:拖放的雙重觸發問題

這個 Bug 超級詭異!

AssetHubEditor 支援兩種拖放方式:
1. 拖曳物件到 ObjectField
2. 拖曳物件到整個視窗(透過 IDragDropReceiver)

問題來了:當你拖曳物件到 ObjectField 時,**兩個系統都會觸發**!

結果就是:拖一個物件,清單裡出現兩筆資料...

**原因:**

ObjectField 本身會處理拖放事件,但它處理完後**不會標記事件為已消費**,所以事件繼續往上傳,被 IDragDropReceiver 再處理一次。

**解決方案:**

在 ObjectColumn 的 DrawColumn 裡,檢查當前事件:

```csharp
if (Event.current.type == EventType.DragPerform)
{
    // ObjectField 的拖放事件,標記為已消費
    Event.current.Use();
}
```

這樣 IDragDropReceiver 就不會重複處理了!

**教訓:** Unity 的事件系統有時候很隱晦,多個系統處理同一事件時要特別小心事件傳播機制。

### 挑戰四:架構設計的反覆推敲

這次重寫 AssetHub,光是架構設計就討論了很久。

一開始我想過幾個方案:

**方案一:繼續用繼承,但簡化層級**
- 優點:熟悉的 OOP 模式
- 缺點:根本問題沒解決,還是難擴充

**方案二:用介面(IAssetLink)取代抽象類別**
- 優點:更靈活
- 缺點:沒有共用程式碼,每個實作都要重複寫

**方案三:完全拋棄繼承,改用組合(Composition)**
- 優點:最靈活
- 缺點:太複雜,反而降低可讀性

**最終方案:Provider 模式(抽象類別 + 自動探索)**
- 優點:保留繼承的共用程式碼優勢,又有介面的擴充彈性
- 優點:自動探索機制讓擴充無痛
- 缺點:需要反射機制(但效能影響可接受,因為只在初始化時用)

選擇 Provider 模式是因為它在「易用性」和「擴充性」之間取得了最好的平衡。

這個過程讓我體會到:**沒有完美的架構,只有最適合當前需求的架構。**

## 下一步

AssetHub 模組算是完整收工了!接下來的計畫:

1. **提交 Extension 三兄弟** — CollectionExtension、MathExtension、TransformExtension 已經寫好很久,該讓它們出山了
2. **攻克其他大型模組** — Service、Flow、Stage、DataEditor、Console 等
3. **整合測試** — 隨著模組越來越多,要確保它們協同工作沒問題
4. **撰寫更多範例** — 好的範例勝過千言萬語

目前進度大約 **62%**(115/185 個檔案),而且這次搞定了一個超級大模組,成就感滿滿!

這次的 AssetHub 重寫讓我學到:**好的架構不是一開始就想出來的,而是在不斷推敲、比較、試錯中逐漸成形的。** Provider 模式雖然聽起來簡單,但它解決了繼承體系的所有痛點,而且還保留了擴充的靈活性。

更重要的是,加入「AI 友善」的設計思維,讓工具不只是給人用,也能讓 AI 更好地協助開發,這種「人機協作」的思考方式會是未來開發工具的趨勢!

我們下次見!

→ 繼續閱讀：[[專案/EAS Foundation/日誌/#04-文件大整頓-當理想碰上現實的對帳時刻|#04 文件大整頓]]

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案主頁]]
