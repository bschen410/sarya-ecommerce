-- =====================================================================
-- Sarya (沙亞) WMBS — 001 base schema
-- Follows SRS Section 4 (Relational Database Schema). Tables marked
-- [EXT] are additions required by Section 2.3 / 2.4 that Section 4 omits.
-- =====================================================================

-- ---------- USERS (superclass) --------------------------------------
CREATE TABLE users (
    user_id        SERIAL PRIMARY KEY,
    loginid        VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    name           VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL UNIQUE,
    status         VARCHAR(20)  NOT NULL
        CHECK (status IN ('unverified', 'active', 'suspended', 'disabled'))
);

-- ---------- WAREHOUSE -----------------------------------------------
CREATE TABLE warehouse (
    storeid  SERIAL PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    address  VARCHAR(255),
    phone    VARCHAR(30),
    email    VARCHAR(255),
    status   VARCHAR(20) NOT NULL DEFAULT 'active'          -- [EXT] BR-020 停用
        CHECK (status IN ('active', 'disabled'))
);

-- ---------- ADMIN / EMPLOYEE / EMPLOYEE_ROLE ------------------------
CREATE TABLE admin (
    admin_id INT PRIMARY KEY REFERENCES users(user_id)
);

CREATE TABLE employee (
    employee_id INT PRIMARY KEY REFERENCES users(user_id),
    storeid     INT REFERENCES warehouse(storeid)            -- WORK；銷售人員可為 NULL
);

CREATE TABLE employee_role (
    employee_id INT NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    role        VARCHAR(20) NOT NULL CHECK (role IN ('sales', 'warehouse')),
    PRIMARY KEY (employee_id, role)
);

-- ---------- CUSTOMER / CUSTOMER_ADDRESS -----------------------------
CREATE TABLE customer (
    customer_id   INT PRIMARY KEY REFERENCES users(user_id),
    phone         VARCHAR(30) NOT NULL,
    sand_coin     INT NOT NULL DEFAULT 0 CHECK (sand_coin >= 0),   -- BR-018
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE customer_address (
    address_id  SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
    recipient   VARCHAR(100) NOT NULL,
    recv_phone  VARCHAR(30)  NOT NULL,
    zip_code    VARCHAR(10)  NOT NULL,
    detail      VARCHAR(255) NOT NULL
);
CREATE INDEX idx_address_customer ON customer_address(customer_id);

-- ---------- CATEGORY / BRAND / SPEC [EXT] (PCS-F-003, PCS-F-006) -----
CREATE TABLE category (
    code        VARCHAR(50) PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    parent_code VARCHAR(50) REFERENCES category(code),
    sort_order  INT NOT NULL DEFAULT 0,
    CHECK (parent_code IS NULL OR parent_code <> code)
);

CREATE TABLE brand (
    name VARCHAR(100) PRIMARY KEY
);

CREATE TABLE spec_field (
    field_id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL REFERENCES category(code) ON DELETE CASCADE,
    name     VARCHAR(100) NOT NULL,
    unit     VARCHAR(20),
    UNIQUE (category, name)
);

-- ---------- PRODUCT -------------------------------------------------
CREATE TABLE product (
    productid       SERIAL PRIMARY KEY,
    model           VARCHAR(100) UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    image           VARCHAR(500),
    brand           VARCHAR(100) NOT NULL REFERENCES brand(name) ON UPDATE CASCADE,
    category        VARCHAR(50)  NOT NULL REFERENCES category(code) ON UPDATE CASCADE,
    price           DECIMAL(10, 2) NOT NULL CHECK (price >= 0),          -- 未稅售價
    warranty_months INT NOT NULL DEFAULT 0 CHECK (warranty_months >= 0),
    sn_required     BOOLEAN NOT NULL DEFAULT false,
    status          VARCHAR(20) NOT NULL DEFAULT 'on_shelf'
        CHECK (status IN ('on_shelf', 'off_shelf')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_product_category ON product(category);
CREATE INDEX idx_product_brand ON product(brand);
CREATE INDEX idx_product_status_created ON product(status, created_at DESC);

CREATE TABLE product_spec (                                    -- [EXT]
    productid INT NOT NULL REFERENCES product(productid) ON DELETE CASCADE,
    field_id  INT NOT NULL REFERENCES spec_field(field_id) ON DELETE CASCADE,
    value     VARCHAR(200) NOT NULL,
    PRIMARY KEY (productid, field_id)
);
CREATE INDEX idx_product_spec_field_value ON product_spec(field_id, value);

-- ---------- CART / CART_ITEM ----------------------------------------
CREATE TABLE cart (
    cart_id     SERIAL PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE REFERENCES customer(customer_id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cart_item (
    cart_id   INT NOT NULL REFERENCES cart(cart_id) ON DELETE CASCADE,
    productid INT NOT NULL REFERENCES product(productid),
    quantity  INT NOT NULL CHECK (quantity > 0),
    added_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (cart_id, productid)
);

-- ---------- STORAGE_BIN [EXT] (WMS-F-002, D-006) --------------------
CREATE TABLE storage_bin (
    bin_id  SERIAL PRIMARY KEY,
    storeid INT NOT NULL REFERENCES warehouse(storeid),
    zone    VARCHAR(10) NOT NULL,
    row_no  VARCHAR(10) NOT NULL,
    level   VARCHAR(10) NOT NULL,
    UNIQUE (storeid, zone, row_no, level)
);

-- ---------- INVENTORY (STORED_IN) -----------------------------------
CREATE TABLE inventory (
    productid    INT NOT NULL REFERENCES product(productid),
    storeid      INT NOT NULL REFERENCES warehouse(storeid),
    on_hand_qty  INT NOT NULL DEFAULT 0 CHECK (on_hand_qty >= 0),           -- BR-012
    reserved_qty INT NOT NULL DEFAULT 0
        CHECK (reserved_qty >= 0 AND reserved_qty <= on_hand_qty),          -- BR-012
    bin_id       INT REFERENCES storage_bin(bin_id) ON DELETE SET NULL,     -- [EXT]
    PRIMARY KEY (productid, storeid)
);
CREATE INDEX idx_inventory_store ON inventory(storeid);

-- ---------- DISCOUNT ------------------------------------------------
CREATE TABLE discount (
    code        VARCHAR(32) PRIMARY KEY,
    type        VARCHAR(20) NOT NULL CHECK (type IN ('shipping', 'seasonal', 'special')),
    description VARCHAR(255),
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    threshold   DECIMAL(10, 2) CHECK (threshold IS NULL OR threshold >= 0),
    method      VARCHAR(20) NOT NULL CHECK (method IN ('rate', 'bogo', 'free_shipping')),
    rate        DECIMAL(10, 2) CHECK (rate IS NULL OR (rate > 0 AND rate < 1)),
    CHECK (end_date >= start_date),                                         -- BR-008
    CHECK (
        (type = 'shipping' AND method = 'free_shipping') OR
        (type = 'seasonal' AND method = 'rate') OR
        (type = 'special'  AND method IN ('rate', 'bogo'))
    ),
    CHECK (method <> 'rate' OR rate IS NOT NULL)
);

CREATE TABLE discount_product (
    code      VARCHAR(32) NOT NULL REFERENCES discount(code) ON DELETE CASCADE ON UPDATE CASCADE,
    productid INT NOT NULL REFERENCES product(productid),
    PRIMARY KEY (code, productid)
);
CREATE INDEX idx_discount_product_product ON discount_product(productid);

-- ---------- ORDERS / ORDER_ITEM / ORDER_LOG / ORDER_DISCOUNT ----------
CREATE TABLE orders (
    orderid        SERIAL PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customer(customer_id),
    order_time     TIMESTAMPTZ NOT NULL DEFAULT now(),
    recipient      VARCHAR(100) NOT NULL,
    recv_phone     VARCHAR(30)  NOT NULL,
    ship_address   VARCHAR(300) NOT NULL,
    ship_method    VARCHAR(20)  NOT NULL CHECK (ship_method IN ('home_delivery', 'store_pickup')),
    payment_method VARCHAR(20)  NOT NULL CHECK (payment_method IN ('credit_card', 'atm')),
    subtotal       DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    discount_amt   DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (discount_amt >= 0),
    coin_used      INT NOT NULL DEFAULT 0 CHECK (coin_used >= 0),
    shipping_fee   DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
    tax            DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
    total          DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    status         VARCHAR(20) NOT NULL DEFAULT 'received'
        CHECK (status IN ('received', 'processing', 'shipping', 'closed', 'cancelled')),
    -- BR-005: total = subtotal - discount - coin + shipping + tax
    CHECK (total = subtotal - discount_amt - coin_used + shipping_fee + tax)
);
CREATE INDEX idx_orders_customer ON orders(customer_id, order_time DESC);
CREATE INDEX idx_orders_status_time ON orders(status, order_time);
CREATE INDEX idx_orders_time ON orders(order_time);

CREATE TABLE order_item (
    orderid          INT NOT NULL REFERENCES orders(orderid),
    line_no          INT NOT NULL,
    productid        INT NOT NULL REFERENCES product(productid),
    discount_code    VARCHAR(32) REFERENCES discount(code) ON UPDATE CASCADE,   -- ITEM_DISCOUNT
    reserved_storeid INT NOT NULL REFERENCES warehouse(storeid),               -- [EXT] 預扣倉庫
    ship_storeid     INT REFERENCES warehouse(storeid),                        -- SHIP，出貨後才填
    product_name     VARCHAR(200) NOT NULL,                                    -- BR-011
    unit_price       DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),          -- BR-011
    quantity         INT NOT NULL CHECK (quantity > 0),
    item_subtotal    DECIMAL(10, 2) NOT NULL CHECK (item_subtotal >= 0),       -- 折扣後小計
    PRIMARY KEY (orderid, line_no)
);
CREATE INDEX idx_order_item_product ON order_item(productid);
CREATE INDEX idx_order_item_reserved_store ON order_item(reserved_storeid) WHERE ship_storeid IS NULL;

CREATE TABLE order_log (
    log_id      SERIAL PRIMARY KEY,
    orderid     INT NOT NULL REFERENCES orders(orderid),
    employee_id INT REFERENCES employee(employee_id),      -- NULL = 會員自行操作 / 系統
    old_status  VARCHAR(20),
    new_status  VARCHAR(20) NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_log_order ON order_log(orderid);

CREATE TABLE order_discount (
    orderid INT NOT NULL REFERENCES orders(orderid),
    code    VARCHAR(32) NOT NULL REFERENCES discount(code) ON UPDATE CASCADE,
    PRIMARY KEY (orderid, code)
);

-- ---------- PAYMENT [EXT] (PLS-F-004, D-013) -------------------------
CREATE TABLE payment (
    payment_id SERIAL PRIMARY KEY,
    orderid    INT NOT NULL REFERENCES orders(orderid),
    method     VARCHAR(20) NOT NULL CHECK (method IN ('credit_card', 'atm')),
    amount     DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    txn_no     VARCHAR(40) NOT NULL UNIQUE,              -- 交易序號 / ATM 虛擬帳號
    status     VARCHAR(20) NOT NULL
        CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at    TIMESTAMPTZ
);
CREATE INDEX idx_payment_order ON payment(orderid);

-- ---------- SHIPMENT [EXT] (PLS-F-005, D-014) ------------------------
CREATE TABLE shipment (
    shipment_id  SERIAL PRIMARY KEY,
    orderid      INT NOT NULL REFERENCES orders(orderid),
    storeid      INT NOT NULL REFERENCES warehouse(storeid),
    carrier      VARCHAR(50) NOT NULL,
    tracking_no  VARCHAR(50) NOT NULL,
    employee_id  INT NOT NULL REFERENCES employee(employee_id),
    shipped_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_at TIMESTAMPTZ,
    UNIQUE (orderid, storeid),
    UNIQUE (carrier, tracking_no)
);

-- ---------- SERIAL_NUMBER (weak entity of PRODUCT) -------------------
CREATE TABLE serial_number (
    productid INT NOT NULL REFERENCES product(productid),
    sn        VARCHAR(100) NOT NULL UNIQUE,                 -- BR-001 全域唯一
    storeid   INT REFERENCES warehouse(storeid),
    orderid   INT,
    line_no   INT,
    status    VARCHAR(20) NOT NULL CHECK (status IN ('in_stock', 'sold')),
    PRIMARY KEY (productid, sn),
    FOREIGN KEY (orderid, line_no) REFERENCES order_item(orderid, line_no),
    -- BR-017: 在庫序號一定在某倉庫；售出後不在倉庫且對應出貨的訂單明細
    CHECK (
        (status = 'in_stock' AND storeid IS NOT NULL AND orderid IS NULL AND line_no IS NULL) OR
        (status = 'sold'     AND storeid IS NULL     AND orderid IS NOT NULL AND line_no IS NOT NULL)
    )
);
CREATE INDEX idx_serial_store ON serial_number(productid, storeid) WHERE status = 'in_stock';

-- ---------- REVIEW ---------------------------------------------------
CREATE TABLE review (
    review_id  SERIAL PRIMARY KEY,
    orderid    INT NOT NULL REFERENCES orders(orderid),
    productid  INT NOT NULL REFERENCES product(productid),
    rating     INT NOT NULL CHECK (rating BETWEEN 1 AND 5),           -- BR-019
    comment    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (orderid, productid)                                        -- BR-019 只能評一次
);
CREATE INDEX idx_review_product ON review(productid);

-- ---------- WH_LOG (庫存異動紀錄) ------------------------------------
CREATE TABLE wh_log (
    log_id      SERIAL PRIMARY KEY,
    storeid     INT NOT NULL REFERENCES warehouse(storeid),
    productid   INT NOT NULL REFERENCES product(productid),
    employee_id INT NOT NULL REFERENCES employee(employee_id),
    type        VARCHAR(20) NOT NULL CHECK (type IN ('inbound', 'outbound', 'adjustment')),
    quantity    INT NOT NULL CHECK (quantity <> 0),     -- 帶正負號的異動量（進貨 +、出貨 −、調整 ±）
    qty_after   INT NOT NULL CHECK (qty_after >= 0),
    source_type VARCHAR(20) NOT NULL CHECK (source_type IN ('purchase', 'order', 'stocktake')),
    source_id   INT,
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((type = 'inbound' AND quantity > 0) OR (type = 'outbound' AND quantity < 0) OR type = 'adjustment')
);
CREATE INDEX idx_wh_log_product_store ON wh_log(productid, storeid, logged_at);
CREATE INDEX idx_wh_log_time ON wh_log(logged_at);

-- ---------- STOCKTAKE / STOCKTAKE_ITEM -------------------------------
CREATE TABLE stocktake (
    stocktake_id   SERIAL PRIMARY KEY,
    storeid        INT NOT NULL REFERENCES warehouse(storeid),
    employee_id    INT NOT NULL REFERENCES employee(employee_id),
    stocktake_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status         VARCHAR(20) NOT NULL DEFAULT 'pending'               -- [EXT] 核准流程
        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by    INT REFERENCES employee(employee_id),                 -- [EXT]
    reviewed_at    TIMESTAMPTZ                                           -- [EXT]
);

CREATE TABLE stocktake_item (
    stocktake_id INT NOT NULL REFERENCES stocktake(stocktake_id) ON DELETE CASCADE,
    productid    INT NOT NULL REFERENCES product(productid),
    book_qty     INT NOT NULL CHECK (book_qty >= 0),
    actual_qty   INT NOT NULL CHECK (actual_qty >= 0),
    PRIMARY KEY (stocktake_id, productid)
);

-- ---------- COIN_LOG [EXT] (D-016 沙幣異動) ---------------------------
CREATE TABLE coin_log (
    log_id      SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customer(customer_id),
    orderid     INT REFERENCES orders(orderid),
    points      INT NOT NULL CHECK (points <> 0),        -- 正：回饋/退還，負：折抵
    type        VARCHAR(20) NOT NULL CHECK (type IN ('earn', 'redeem', 'refund')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_coin_log_customer ON coin_log(customer_id, created_at DESC);
