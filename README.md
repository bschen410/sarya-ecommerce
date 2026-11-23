# 沙亞 Sarya

銷售電腦零組件與 3C 產品的線上商城（WMBS, Web-based Mall Business System）。
國立臺北科技大學 資訊工程系 資料庫課程期末專案（Team 7）。

系統以關聯式資料庫為核心，支援會員、銷售人員、倉管人員、系統管理員四種角色，
涵蓋商品瀏覽與搜尋、線上估價、購物車結帳、訂單、付款物流、折扣與沙幣紅利、多倉庫庫存、
報表與評價，並確保多人同時下單時不會超賣。

完整需求請見 [系統需求規格書（SRS Phase 2）](docs/srs/Team7_Phase2.pdf)。

## 功能概覽

| 角色 | 主要功能 |
|---|---|
| 訪客 / 會員 | 搜尋與篩選商品、線上估價組裝電腦、購物車、結帳（折扣碼、沙幣折抵）、訂單追蹤與取消、商品評價 |
| 銷售人員 | 商品與分類 / 品牌 / 規格維護、訂單處理、折扣活動管理、銷售報表 |
| 倉管人員 | 多倉庫庫存與儲位、進貨入庫、揀貨出貨、序號管理、盤點、庫存報表 |
| 系統管理員 | 員工帳號與角色、會員停權、倉庫資料、盤點核准、營運儀表板 |

## 技術棧

| 層 | 技術 |
|---|---|
| 前端 | Vue 3、Vite |
| 後端 | Node.js 24 LTS、Express 5（RESTful API，JWT 驗證） |
| 資料庫 | PostgreSQL 18 |
| 部署 | Nginx（靜態檔 + `/api` 反向代理）、Docker Compose |

## 專案結構

```
backend/
  db/
    migrations/
      001_schema.sql        # 資料表
      002_rules_views.sql   # 商業規則 trigger 與 view
    seed.sql                # 示範資料
docs/
  srs/Team7_Phase2.pdf      # 系統需求規格書
AGENTS.md                   # 給 AI coding agent 的開發說明
```

> 目前進度：資料庫 schema 與示範資料已完成，前後端開發中。

## 快速開始

### 建立資料庫

需要 PostgreSQL 18。

```bash
createdb sarya
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/migrations/001_schema.sql
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/migrations/002_rules_views.sql
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/seed.sql
```

### 示範帳號

所有帳號密碼皆為 `Sarya1234`。

| 帳號 | 角色 |
|---|---|
| `admin` | 系統管理員 |
| `sales01` | 銷售人員 |
| `wh_tpe` / `wh_txg` / `wh_khh` | 倉管人員（台北 / 台中 / 高雄物流中心） |
| `member01` / `member02` / `member03` | 會員 |

## 資料庫設計重點

- 使用者採 superclass / subclass 設計：`users` → `admin`、`employee`、`customer`
- 可售庫存 = 現有數量 − 預扣數量，由 view `v_product_stock` 計算（僅計啟用中的倉庫）
- 商業規則盡量由資料庫強制：
  - 訂單狀態只能依 `received → processing → shipping → closed` 推進，出貨前可取消（BR-010）
  - 同一商品的特價活動期間不得重疊（BR-007）
  - 只能評價已結案訂單中的商品，每筆僅一次（BR-019）
  - 庫存與預扣數量不得為負、預扣不得大於現有（BR-012）
  - 訂單總額 = 小計 − 折扣 − 沙幣 + 運費 + 稅額（BR-005）
- 資料表正規化至 3NF

## 開發

- 資料庫結構變更請新增 migration（`backend/db/migrations/NNN_描述.sql`），不要修改已提交的檔案
- Commit 訊息與 PR 標題採 [Conventional Commits](https://www.conventionalcommits.org/)，例如 `feat(oms): 建立訂單 API`
- 不直接 push 到 `main`：開分支（如 `feat/oms-create-order`）→ 發 PR → 至少 1 位組員 review → **Squash and merge**
- 詳細開發慣例與商業規則注意事項見 [AGENTS.md](AGENTS.md)
