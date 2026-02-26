---
title: "#01 衛星截圖工具"
tags: [Python, Selenium, Folium, CLI]
created: 2025-10-23
phase: 1
---

> **Tech** Python, Folium, Selenium, Pillow, geopy
>
> **AI** Claude Code

## 源起

需要一個能根據經緯度和範圍自動抓衛星圖的工具。重點是要「乾淨」的影像——沒有地圖標記、沒有 UI 控制元件、沒有浮水印。另一個核心需求是 1 公尺 = 1 像素的比例對應，這樣後續做測量或分析的時候不需要再換算。

Google Maps API 要收費有額度限制，寫個 web app 來串接功能又覺得太多了。

## 設計

技術棧的核心是 Folium，一個 Python 地圖庫，可以生成互動式地圖 HTML，圖層用的是免費的 Esri World Imagery。但 Folium 只能輸出網頁，不能直接出圖片，所以拿 Selenium 開一個 headless Chrome 載入地圖再截圖。裁切和縮放交給 Pillow，座標計算靠 geopy 的 geodesic。

流程大概是：

1. 用 geopy 算出目標範圍的四角座標
2. Folium 生成包含該區域的地圖 HTML
3. Selenium headless Chrome 載入並截圖
4. 用 Web Mercator 投影換算像素座標，Pillow 精確裁切

## 實現

**zoom level 的品質陷阱。** 一開始跑出來的小範圍（300m）圖片還行，但範圍一拉到 1000m 整張糊掉。原因是 Folium 會自動降低 zoom level 來塞進整個區域。解法是手動把 zoom level 拉高 2-3 級，瀏覽器視窗開成目標的兩倍大，截圖後再用 LANCZOS 縮回來。這樣即使 2000m 的大範圍也夠清晰。

**球面座標轉平面像素。** 經緯度是球面座標，圖片是平面的，要把地圖上的點轉成像素位置需要 Web Mercator 投影公式。花了一些時間把這組轉換寫對，才能精確切出「剛好就是指定範圍」的區域。

**參數設計改過一次。** 最初設計是輸入面積（平方公尺），但「90000 平方公尺」沒人第一時間知道是多大。改成輸入邊長之後直覺很多——300 公尺就是 300 公尺，輸出圖片就是 300x300 像素。

## 尾聲

| 項目 | 結果 |
|------|------|
| 支援範圍 | 100m ~ 2000m |
| 生成速度 | 3-10 秒 |
| 像素比例 | 1px = 1m |
| 費用 | 免費（Esri World Imagery） |

一個下午從零到可用。工具不複雜，但「zoom level 品質修正」和「投影座標轉換」這兩個坑佔了大部分時間。

