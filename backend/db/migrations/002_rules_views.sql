-- =====================================================================
-- 002 business-rule triggers & views
-- =====================================================================

-- ---------- BR-010: 訂單狀態只能依序推進 -------------------------------
CREATE OR REPLACE FUNCTION trg_order_status_transition() RETURNS trigger AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF NOT (
        (OLD.status = 'received'   AND NEW.status IN ('processing', 'cancelled')) OR
        (OLD.status = 'processing' AND NEW.status IN ('shipping', 'cancelled')) OR
        (OLD.status = 'shipping'   AND NEW.status = 'closed')
    ) THEN
        RAISE EXCEPTION 'BR-010: 訂單狀態不可由 % 變更為 %', OLD.status, NEW.status
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_status_transition
    BEFORE UPDATE OF status ON orders
    FOR EACH ROW EXECUTE FUNCTION trg_order_status_transition();

-- ---------- BR-007: 同一商品的特價活動期間不得重疊 ---------------------
CREATE OR REPLACE FUNCTION check_special_overlap(p_code VARCHAR, p_productid INT) RETURNS void AS $$
DECLARE
    d discount%ROWTYPE;
    clash VARCHAR;
BEGIN
    SELECT * INTO d FROM discount WHERE code = p_code;
    IF d.type <> 'special' THEN
        RETURN;
    END IF;
    SELECT o.code INTO clash
      FROM discount_product dp
      JOIN discount o ON o.code = dp.code
     WHERE dp.productid = p_productid
       AND o.code <> p_code
       AND o.type = 'special'
       AND daterange(o.start_date, o.end_date, '[]') && daterange(d.start_date, d.end_date, '[]')
     LIMIT 1;
    IF clash IS NOT NULL THEN
        RAISE EXCEPTION 'BR-007: 商品 % 已參加期間重疊的特價活動 %', p_productid, clash
            USING ERRCODE = 'P0001';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_discount_product_overlap() RETURNS trigger AS $$
BEGIN
    PERFORM check_special_overlap(NEW.code, NEW.productid);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER discount_product_overlap
    BEFORE INSERT OR UPDATE ON discount_product
    FOR EACH ROW EXECUTE FUNCTION trg_discount_product_overlap();

CREATE OR REPLACE FUNCTION trg_discount_dates_overlap() RETURNS trigger AS $$
DECLARE
    pid INT;
BEGIN
    IF NEW.type = 'special' AND (NEW.start_date <> OLD.start_date OR NEW.end_date <> OLD.end_date OR NEW.type <> OLD.type) THEN
        FOR pid IN SELECT productid FROM discount_product WHERE code = NEW.code LOOP
            PERFORM check_special_overlap(NEW.code, pid);
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER discount_dates_overlap
    AFTER UPDATE ON discount
    FOR EACH ROW EXECUTE FUNCTION trg_discount_dates_overlap();

-- ---------- BR-019: 只有已結案訂單內的商品可以評價 ---------------------
CREATE OR REPLACE FUNCTION trg_review_closed_order() RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM orders o JOIN order_item oi ON oi.orderid = o.orderid
         WHERE o.orderid = NEW.orderid AND oi.productid = NEW.productid AND o.status = 'closed'
    ) THEN
        RAISE EXCEPTION 'BR-019: 只能評價已結案訂單中購買的商品' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER review_closed_order
    BEFORE INSERT ON review
    FOR EACH ROW EXECUTE FUNCTION trg_review_closed_order();

-- ---------- Views ----------------------------------------------------
-- 每項商品在所有啟用倉庫的可售數量（BR-004：現有數量 − 預扣數量）
CREATE VIEW v_product_stock AS
SELECT p.productid,
       COALESCE(SUM(i.on_hand_qty)  FILTER (WHERE w.status = 'active'), 0)::INT AS on_hand_qty,
       COALESCE(SUM(i.reserved_qty) FILTER (WHERE w.status = 'active'), 0)::INT AS reserved_qty,
       COALESCE(SUM(i.on_hand_qty - i.reserved_qty) FILTER (WHERE w.status = 'active'), 0)::INT AS available_qty
  FROM product p
  LEFT JOIN inventory i ON i.productid = p.productid
  LEFT JOIN warehouse w ON w.storeid = i.storeid
 GROUP BY p.productid;

-- 商品平均評分
CREATE VIEW v_product_rating AS
SELECT productid, ROUND(AVG(rating)::numeric, 1) AS avg_rating, COUNT(*)::INT AS review_count
  FROM review
 GROUP BY productid;

-- 使用者角色（會員 / 銷售 / 倉管 / 管理員）
CREATE VIEW v_user_roles AS
SELECT u.user_id, 'customer'::VARCHAR AS role FROM users u JOIN customer c ON c.customer_id = u.user_id
UNION ALL
SELECT u.user_id, er.role FROM users u JOIN employee_role er ON er.employee_id = u.user_id
UNION ALL
SELECT u.user_id, 'admin' FROM users u JOIN admin a ON a.admin_id = u.user_id;
