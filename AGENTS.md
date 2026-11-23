# AGENTS.md

## 專案概要

**沙亞 Sarya（WMBS, Web-based Mall Business System）**：銷售電腦零組件與 3C 產品的線上商城。核心是關聯式資料庫，重點在多角色作業流程與 **多人同時下單時庫存、訂單資料的正確性**。

- 需求規格書：`docs/srs/`
  - 2.3 功能性需求、2.4 資料需求、2.5 非功能性需求、2.8 商業規則（BR-xxx）、Section 4 資料庫綱要
  - 需求編號格式：`子系統-類型-流水號`，類型 `F` 功能 / `D` 資料 / `N` 非功能；優先序 1 必要、2 次要、3 選擇性
- 角色：會員（customer）、銷售人員（sales）、倉管人員（warehouse）、系統管理員（admin）

### 子系統代號

| 代號 | 子系統 | 代號 | 子系統 |
|---|---|---|---|
| AMS | 帳號與會員管理 | PLS | 付款與物流 |
| PCS | 商品型錄 | DPS | 優惠折扣與沙幣紅利 |
| SFCS | 搜尋與篩選 | WMS | 倉儲管理 |
| SCS | 購物車與線上估價 | RPS | 報表統計 |
| OMS | 訂單管理 | RVS | 評價管理 |

## 目前狀態與目錄結構

目前只有資料庫層，前後端尚未建立。

```
backend/db/
  migrations/
    001_schema.sql        # 所有資料表（依 SRS Section 4）
    002_rules_views.sql   # 商業規則 trigger 與 view
  seed.sql                # 示範資料（WMBS-N-802）
docs/srs/Team7_Phase2.pdf
```

### 規劃中的技術棧（SRS 2.6 / 2.7，新增程式碼時須遵守）

- 後端：Node.js 24 LTS + Express 5，RESTful API，掛在 `/api` 下
- 資料庫：PostgreSQL 18（透過資料庫驅動程式直接存取，SQL 一律參數化）
- 前端：Vue 3 + Vite，前後端分離；部署時編譯成靜態檔由 Nginx 提供
- Nginx 反向代理 `/api` → 後端
- Docker Compose 一次建起 Nginx、前端、後端、PostgreSQL（WMBS-N-801）
- 驗證：JWT，有效期限 2 小時；密碼以 bcrypt 雜湊

建立新目錄時請沿用 `backend/`，前端放 `frontend/`。在專案還沒有對應設定檔之前，不要假設
`npm` script、`docker compose` 指令已經存在；請先檢查，必要時建立並同步更新本檔。

## 資料庫

### 手動建庫

```bash
createdb sarya
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/migrations/001_schema.sql
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/migrations/002_rules_views.sql
psql -d sarya -v ON_ERROR_STOP=1 -f backend/db/seed.sql
```

示範帳號密碼皆為 `Sarya1234`：`admin`、`sales01`、`wh_tpe` / `wh_txg` / `wh_khh`（三個倉庫的倉管）、
`member01`–`member03`。

### Migration 規則

- 檔名 `NNN_描述.sql`，三位數流水號遞增，依序執行（WMBS-N-803）。
- **不要修改已提交的 migration**；結構變更請新增下一號檔案（例如 `003_xxx.sql`）。
  例外：在第一版正式交付前，若團隊明確要求整理 schema，可直接改 001/002，並一併更新 `seed.sql`。
- schema 變更後須確認 `seed.sql` 仍能在全新資料庫上完整執行。
- seed 用明確 ID 插入後，要用 `setval(...)` 校正 sequence（參考現有寫法）。

### 命名與寫法慣例

- 表名、欄位名用 `snake_case`；主鍵沿用 SRS 命名（`productid`、`storeid`、`orderid` 不加底線，
  其餘如 `user_id`、`customer_id` 有底線）——照現有欄位名稱寫，不要自行「統一」。
- 列舉值用 `VARCHAR` + `CHECK (... IN (...))`，值為小寫英文（如 `received`、`on_shelf`）。
- 金額 `DECIMAL(10, 2)`；沙幣、數量用 `INT`；時間用 `TIMESTAMPTZ`。
- SRS Section 4 沒有、但 2.3/2.4 需要而補上的表或欄位，以註解 `-- [EXT]` 標註並註明來源需求編號。
- 實作某條商業規則的 constraint / trigger，旁邊用註解標上 `BR-xxx`。
- Trigger 違反規則時 `RAISE EXCEPTION 'BR-xxx: 中文說明' USING ERRCODE = 'P0001'`；
  後端可依 `P0001` 與 `BR-xxx` 前綴轉成 4xx 錯誤回應。
- 資料表須維持 3NF（WMBS-N-406）。訂單明細的 `product_name`、`unit_price` 是刻意保存的下單快照（BR-011），不是冗餘。

### 重要的既有設計

- `users` 為 superclass，`admin` / `employee` / `customer` 為子類；角色查詢用 `v_user_roles`。
  管理員同時存在於 `employee`，以便作為 `wh_log`、`order_log` 的經辦人。
- 可售數量 = `on_hand_qty - reserved_qty`，只計算 `active` 倉庫；用 `v_product_stock`。
- 訂單狀態轉換由 trigger `orders_status_transition` 強制（BR-010）。
- 特價活動期間重疊由 trigger 檢查（BR-007）；評價限已結案訂單由 trigger 檢查（BR-019）。
- `orders` 有 CHECK 保證 `total = subtotal - discount_amt - coin_used + shipping_fee + tax`（BR-005）。

## 商業規則重點（實作後端時最容易出錯的地方）

完整內容見 SRS 2.8，以下是必須特別注意的：

- **不可超賣（WMBS-N-403/604）**：下單預扣庫存必須在同一個交易內完成，用
  `SELECT ... FOR UPDATE` 或條件式 `UPDATE inventory SET reserved_qty = reserved_qty + $1
  WHERE ... AND on_hand_qty - reserved_qty >= $1` 並檢查影響列數。不要「先查再寫」。
- **金額計算（BR-005/006/009）**：售價為未稅價；稅額 = 折扣後金額 × 5%；運費、季節折扣作用於整筆訂單，
  特價折扣作用於指定商品；折扣後商品金額 ≥ 門檻時免運。三種折扣可同時套用。
- **訂單取消（OMS-F-005）**：只有 `received`、`processing` 可取消，取消時須釋放 `reserved_qty`、退還沙幣。
- **庫存異動（BR-013）**：每次 `on_hand_qty` 變動都必須寫一筆 `wh_log`，並記錄來源單據。
- **序號（BR-017）**：`sn_required` 商品出貨時每件對應一個 `in_stock` 序號，出貨後改為 `sold`。
- **沙幣（BR-018）**：訂單結案後才入帳（預設實付 1%），折抵不得超過餘額；每次異動寫 `coin_log`。
- **不可刪除（BR-020, PCS-F-005）**：有交易或庫存紀錄的商品、倉庫只能下架 / 停用。
- **帳號狀態（BR-021）**：`suspended` 會員不可登入、下單；`disabled` 員工不可登入後台。
- **權限（WMBS-N-503）**：每支 API 依角色控管，會員只能存取自己的資料；倉管只能操作所屬倉庫。
- **安全（WMBS-N-504）**：所有 SQL 參數化，禁止字串拼接；輸出須跳脫以防 XSS。

## 測試

SRS 2.7.3 要求的測試（建立後端時一併撰寫）：

- 每個子系統的 API 單元與整合測試，涵蓋註冊、下單、出貨、進貨、盤點
- 商業規則測試：庫存不可為負、特價期間不可重疊、折扣與總額計算、訂單狀態轉換
- 併發測試：多位使用者同時購買最後一件商品，只能有一筆成功

修改 SQL 後至少要在全新資料庫上跑完 migration + seed 無錯誤。

## 協作慣例

- Commit 訊息採 Conventional Commits，scope 可用子系統或目錄，例如
  `feat(oms): ...`、`fix(db): ...`、`docs(srs): ...`。
- 程式碼識別字用英文；註解、錯誤訊息、文件可用繁體中文。
- 實作功能時在 PR / commit 說明中引用對應的需求編號（如 `OMS-F-001`、`BR-010`）。
- 需求不明確或 SRS 與 schema 衝突時，以 SRS 為準並回報差異，不要自行決定。

## 分支與 Pull Request

- 不直接 push 到 `main`；從最新的 `main` 開分支，命名 `類型/子系統-簡述`，例如
  `feat/oms-create-order`、`fix/db-stock-check`、`docs/readme`。
- 一個 PR 只做一件事；schema 變更與使用它的 API 可以放同一個 PR。
- **PR 標題即 squash 後的 commit 訊息**，必須符合 Conventional Commits（`feat(oms): 建立訂單與預扣庫存`）。
- PR 內容依 `.github/pull_request_template.md` 填寫：摘要、需求編號、測試方式、schema 變更檢查。
- 合併前至少 1 位組員 review 通過；CI 建立後須全部通過。
- 一律使用 **Squash and merge**；合併後刪除分支，後續修改從 `main` 開新分支。
