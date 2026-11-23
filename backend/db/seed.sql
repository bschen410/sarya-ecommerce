-- =====================================================================
-- Sarya WMBS — seed data (WMBS-N-802)
-- 所有示範帳號密碼皆為：Sarya1234
-- =====================================================================
BEGIN;

-- ---------- 倉庫 -----------------------------------------------------
INSERT INTO warehouse (storeid, name, address, phone, email) VALUES
  (1, '台北物流中心', '新北市五股區五工路 100 號', '02-2299-0000', 'tpe@sarya.local'),
  (2, '台中物流中心', '台中市西屯區工業區一路 50 號', '04-2359-0000', 'txg@sarya.local'),
  (3, '高雄物流中心', '高雄市前鎮區成功二路 20 號', '07-811-0000', 'khh@sarya.local');
SELECT setval('warehouse_storeid_seq', 3);

INSERT INTO storage_bin (storeid, zone, row_no, level)
SELECT s, z, r::text, l::text
  FROM generate_series(1, 3) s, unnest(ARRAY['A', 'B', 'C']) z, generate_series(1, 3) r, generate_series(1, 3) l;

-- ---------- 使用者（BR-002 初始系統管理員為資料庫初始資料） -------------
INSERT INTO users (user_id, loginid, password_hash, name, email, status) VALUES
  (1, 'admin',    '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '系統管理員', 'admin@sarya.local',   'active'),
  (2, 'sales01',  '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '王小明',     'sales01@sarya.local', 'active'),
  (3, 'wh_tpe',   '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '李倉管',     'wh_tpe@sarya.local',  'active'),
  (4, 'wh_txg',   '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '張倉管',     'wh_txg@sarya.local',  'active'),
  (5, 'wh_khh',   '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '陳倉管',     'wh_khh@sarya.local',  'active'),
  (6, 'member01', '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '林小美',     'member01@example.com', 'active'),
  (7, 'member02', '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '黃大華',     'member02@example.com', 'active'),
  (8, 'member03', '$2b$10$6.8bDCMQ4Q68B9BQ2NXguOo8PKxKxVEz2B7nxL1MI.k2omLvttKLe', '吳阿明',     'member03@example.com', 'active');
SELECT setval('users_user_id_seq', 8);

INSERT INTO admin (admin_id) VALUES (1);
-- 管理員同時是員工（員工表為 WH_LOG / ORDER_LOG 經辦人的參照對象）
INSERT INTO employee (employee_id, storeid) VALUES (1, NULL), (2, NULL), (3, 1), (4, 2), (5, 3);
INSERT INTO employee_role (employee_id, role) VALUES (2, 'sales'), (3, 'warehouse'), (4, 'warehouse'), (5, 'warehouse');

INSERT INTO customer (customer_id, phone, sand_coin, registered_at) VALUES
  (6, '0912-345-678', 500, now() - interval '90 days'),
  (7, '0922-111-222', 0,   now() - interval '60 days'),
  (8, '0933-555-666', 120, now() - interval '20 days');

INSERT INTO customer_address (customer_id, recipient, recv_phone, zip_code, detail) VALUES
  (6, '林小美', '0912-345-678', '106', '台北市大安區忠孝東路三段 1 號'),
  (6, '林小美（公司）', '0912-345-678', '110', '台北市信義區信義路五段 7 號'),
  (7, '黃大華', '0922-111-222', '407', '台中市西屯區台灣大道三段 99 號'),
  (8, '吳阿明', '0933-555-666', '806', '高雄市前鎮區中山二路 2 號');

INSERT INTO cart (customer_id) VALUES (6), (7), (8);

-- ---------- 分類 / 品牌 / 規格欄位 ------------------------------------
INSERT INTO category (code, name, parent_code, sort_order) VALUES
  ('components',  '電腦零組件', NULL, 1),
  ('peripherals', '週邊設備',   NULL, 2),
  ('laptop',      '筆記型電腦', NULL, 3),
  ('cpu',         'CPU 處理器', 'components', 1),
  ('motherboard', '主機板',     'components', 2),
  ('memory',      '記憶體',     'components', 3),
  ('gpu',         '顯示卡',     'components', 4),
  ('storage',     '儲存裝置',   'components', 5),
  ('ssd',         'SSD 固態硬碟', 'storage', 1),
  ('hdd',         '傳統硬碟',   'storage', 2),
  ('psu',         '電源供應器', 'components', 6),
  ('case',        '機殼',       'components', 7),
  ('cooler',      '散熱器',     'components', 8),
  ('fan',         '機殼風扇',   'components', 9),
  ('monitor',     '螢幕',       'peripherals', 1),
  ('keyboard',    '鍵盤',       'peripherals', 2),
  ('mouse',       '滑鼠',       'peripherals', 3);

INSERT INTO brand (name) VALUES
  ('AMD'), ('Intel'), ('ASUS'), ('MSI'), ('GIGABYTE'), ('Kingston'), ('Corsair'), ('Samsung'), ('WD'),
  ('Seagate'), ('Seasonic'), ('Cooler Master'), ('Fractal Design'), ('Lian Li'), ('Noctua'), ('DeepCool'),
  ('LG'), ('Logitech'), ('Keychron'), ('Razer'), ('Apple');

INSERT INTO spec_field (field_id, category, name, unit) VALUES
  (1,  'cpu', '腳位', NULL), (2, 'cpu', '核心數', '核'), (3, 'cpu', '執行緒', '緒'), (4, 'cpu', '基礎時脈', 'GHz'), (5, 'cpu', 'TDP', 'W'),
  (6,  'motherboard', '腳位', NULL), (7, 'motherboard', '晶片組', NULL), (8, 'motherboard', '記憶體類型', NULL), (9, 'motherboard', '尺寸規格', NULL),
  (10, 'memory', '記憶體類型', NULL), (11, 'memory', '容量', 'GB'), (12, 'memory', '時脈', 'MHz'),
  (13, 'gpu', '晶片', NULL), (14, 'gpu', '顯存容量', 'GB'), (15, 'gpu', '建議電源', 'W'),
  (16, 'storage', '容量', 'GB'), (17, 'storage', '介面', NULL),
  (18, 'psu', '瓦數', 'W'), (19, 'psu', '80 PLUS 認證', NULL),
  (20, 'case', '支援主機板', NULL),
  (21, 'cooler', '類型', NULL),
  (22, 'monitor', '尺寸', '吋'), (23, 'monitor', '解析度', NULL), (24, 'monitor', '更新率', 'Hz'),
  (25, 'keyboard', '軸體', NULL), (26, 'keyboard', '連線方式', NULL),
  (27, 'mouse', '連線方式', NULL), (28, 'mouse', 'DPI', NULL);
SELECT setval('spec_field_field_id_seq', 28);

-- ---------- 商品 -----------------------------------------------------
INSERT INTO product (productid, model, name, description, brand, category, price, warranty_months, sn_required, created_at) VALUES
  (1,  '100-100001084WOF', 'AMD Ryzen 7 9800X3D 8核16緒 處理器', '搭載第二代 3D V-Cache 技術，遊戲效能旗艦。', 'AMD', 'cpu', 15990, 36, false, now() - interval '80 days'),
  (2,  '100-100001405WOF', 'AMD Ryzen 5 9600X 6核12緒 處理器', 'Zen 5 架構，主流遊戲與創作首選。', 'AMD', 'cpu', 7290, 36, false, now() - interval '79 days'),
  (3,  'BX80768265K', 'Intel Core Ultra 7 265K 20核 處理器', 'Arrow Lake 架構，內建 NPU。', 'Intel', 'cpu', 11490, 36, false, now() - interval '78 days'),
  (4,  'BX8071514400F', 'Intel Core i5-14400F 10核16緒 處理器', '高 CP 值主流處理器（無內顯）。', 'Intel', 'cpu', 5190, 36, false, now() - interval '77 days'),
  (5,  'ROG STRIX B850-F GAMING WIFI', 'ASUS ROG STRIX B850-F GAMING WIFI 主機板', 'AM5 平台、PCIe 5.0、WiFi 7。', 'ASUS', 'motherboard', 9490, 48, true, now() - interval '70 days'),
  (6,  'MAG B650 TOMAHAWK WIFI', 'MSI MAG B650 TOMAHAWK WIFI 主機板', 'AM5 平台經典戰斧。', 'MSI', 'motherboard', 6490, 48, true, now() - interval '69 days'),
  (7,  'Z890 AORUS ELITE WIFI7', 'GIGABYTE Z890 AORUS ELITE WIFI7 主機板', 'LGA1851 平台，支援 Core Ultra 200S。', 'GIGABYTE', 'motherboard', 9990, 48, true, now() - interval '68 days'),
  (8,  'PRIME B760M-A WIFI D4', 'ASUS PRIME B760M-A WIFI D4 主機板', 'LGA1700 平台 mATX，支援 DDR4。', 'ASUS', 'motherboard', 3990, 36, true, now() - interval '67 days'),
  (9,  'KF560C36BBEK2-32', 'Kingston FURY Beast DDR5-6000 32GB(16GBx2) 記憶體', 'AMD EXPO / Intel XMP 3.0。', 'Kingston', 'memory', 3290, 120, false, now() - interval '60 days'),
  (10, 'CMH32GX5M2B6400C36', 'Corsair Vengeance RGB DDR5-6400 32GB(16GBx2) 記憶體', 'RGB 燈效。', 'Corsair', 'memory', 3890, 120, false, now() - interval '59 days'),
  (11, 'KF432C16BBK2/16', 'Kingston FURY Beast DDR4-3200 16GB(8GBx2) 記憶體', '經典 DDR4 套條。', 'Kingston', 'memory', 1290, 120, false, now() - interval '58 days'),
  (12, 'TUF-RTX5070TI-O16G-GAMING', 'ASUS TUF Gaming GeForce RTX 5070 Ti 16GB 顯示卡', '軍規用料，三風扇散熱。', 'ASUS', 'gpu', 29990, 36, true, now() - interval '30 days'),
  (13, 'RTX 5060 Ti 16G VENTUS 2X OC', 'MSI GeForce RTX 5060 Ti VENTUS 2X 16G OC 顯示卡', '雙風扇精巧設計。', 'MSI', 'gpu', 15490, 36, true, now() - interval '25 days'),
  (14, 'GV-R9070XTGAMING OC-16GD', 'GIGABYTE Radeon RX 9070 XT GAMING OC 16G 顯示卡', 'RDNA 4 架構。', 'GIGABYTE', 'gpu', 22990, 36, true, now() - interval '20 days'),
  (15, 'DUAL-RTX4060-O8G', 'ASUS DUAL GeForce RTX 4060 O8G 顯示卡', '入門 1080p 遊戲。', 'ASUS', 'gpu', 9990, 36, true, now() - interval '90 days'),
  (16, 'MZ-V9P2T0BW', 'Samsung 990 PRO 2TB PCIe 4.0 NVMe SSD', '讀取最高 7450MB/s。', 'Samsung', 'ssd', 5490, 60, false, now() - interval '50 days'),
  (17, 'WDS100T2X0E', 'WD Black SN850X 1TB NVMe SSD', '遊戲專用高速 SSD。', 'WD', 'ssd', 2890, 60, false, now() - interval '49 days'),
  (18, 'SNV3S/1000G', 'Kingston NV3 1TB PCIe 4.0 NVMe SSD', '高 CP 值 SSD。', 'Kingston', 'ssd', 1690, 36, false, now() - interval '48 days'),
  (19, 'ST4000DM004', 'Seagate BarraCuda 4TB 3.5吋 硬碟', '大容量資料倉儲。', 'Seagate', 'hdd', 2790, 24, false, now() - interval '47 days'),
  (20, 'FOCUS GX-850 ATX3', 'Seasonic FOCUS GX-850 ATX3.1 金牌全模組 電源供應器', '原生 12V-2x6 接頭。', 'Seasonic', 'psu', 4290, 120, false, now() - interval '40 days'),
  (21, 'RM750e', 'Corsair RM750e 金牌全模組 電源供應器', '低噪音、ATX 3.1。', 'Corsair', 'psu', 3190, 84, false, now() - interval '39 days'),
  (22, 'MPE-6501-ACABW', 'Cooler Master MWE 650 Bronze V3 電源供應器', '入門銅牌電源。', 'Cooler Master', 'psu', 1690, 60, false, now() - interval '38 days'),
  (23, 'FD-C-NOR1C-01', 'Fractal Design North 木質前板 機殼', '北歐風格中塔機殼。', 'Fractal Design', 'case', 4490, 24, false, now() - interval '35 days'),
  (24, 'LANCOOL 216', 'Lian Li LANCOOL 216 機殼', '高風流量設計。', 'Lian Li', 'case', 2990, 12, false, now() - interval '34 days'),
  (25, 'MCB-Q300L-KANN-S00', 'Cooler Master MasterBox Q300L 機殼', '小巧 mATX 機殼。', 'Cooler Master', 'case', 1390, 12, false, now() - interval '33 days'),
  (26, 'NH-D15 G2', 'Noctua NH-D15 G2 雙塔空冷散熱器', '旗艦級空冷。', 'Noctua', 'cooler', 5290, 72, false, now() - interval '28 days'),
  (27, 'AK400', 'DeepCool AK400 塔型空冷散熱器', '入門熱銷空冷。', 'DeepCool', 'cooler', 990, 24, false, now() - interval '27 days'),
  (28, 'GA2T36B', 'Lian Li Galahad II Trinity 360 水冷散熱器', '360mm 一體式水冷。', 'Lian Li', 'cooler', 4990, 72, false, now() - interval '26 days'),
  (29, 'UF-SLV2-3B', 'Lian Li UNI FAN SL120 V2 ARGB 風扇 3入組', '可串接免理線設計。', 'Lian Li', 'fan', 2590, 24, false, now() - interval '15 days'),
  (30, 'VG27AQ3A', 'ASUS TUF Gaming VG27AQ3A 27吋 2K 180Hz 電競螢幕', 'Fast IPS 面板。', 'ASUS', 'monitor', 6990, 36, true, now() - interval '12 days'),
  (31, '27GR93U-B', 'LG UltraGear 27GR93U 27吋 4K 144Hz 電競螢幕', '4K IPS 144Hz。', 'LG', 'monitor', 10990, 36, true, now() - interval '10 days'),
  (32, '920-012144', 'Logitech G PRO X TKL LIGHTSPEED 無線電競鍵盤', '職業選手設計。', 'Logitech', 'keyboard', 5990, 24, false, now() - interval '9 days'),
  (33, 'K2-V2-RGB', 'Keychron K2 V2 無線機械鍵盤', 'Mac / Windows 雙系統。', 'Keychron', 'keyboard', 2590, 12, false, now() - interval '8 days'),
  (34, '910-006632', 'Logitech G PRO X SUPERLIGHT 2 無線電競滑鼠', '60g 超輕量化。', 'Logitech', 'mouse', 4290, 24, false, now() - interval '7 days'),
  (35, 'RZ01-04640100', 'Razer DeathAdder V3 有線電競滑鼠', '人體工學經典。', 'Razer', 'mouse', 2290, 24, false, now() - interval '6 days'),
  (36, 'GA403WR-0052E5080H', 'ASUS ROG Zephyrus G14 (2025) 14吋 電競筆電', 'Ryzen AI 9 HX 370 / RTX 5070 Ti。', 'ASUS', 'laptop', 69990, 24, true, now() - interval '5 days'),
  (37, 'MW123TA/A', 'Apple MacBook Air 13吋 M4 16GB/256GB 筆記型電腦', '輕薄長續航。', 'Apple', 'laptop', 30470, 12, true, now() - interval '3 days');
SELECT setval('product_productid_seq', 37);

INSERT INTO product_spec (productid, field_id, value) VALUES
  (1,1,'AM5'),(1,2,'8'),(1,3,'16'),(1,4,'4.7'),(1,5,'120'),
  (2,1,'AM5'),(2,2,'6'),(2,3,'12'),(2,4,'3.9'),(2,5,'65'),
  (3,1,'LGA1851'),(3,2,'20'),(3,3,'20'),(3,4,'3.9'),(3,5,'125'),
  (4,1,'LGA1700'),(4,2,'10'),(4,3,'16'),(4,4,'2.5'),(4,5,'65'),
  (5,6,'AM5'),(5,7,'B850'),(5,8,'DDR5'),(5,9,'ATX'),
  (6,6,'AM5'),(6,7,'B650'),(6,8,'DDR5'),(6,9,'ATX'),
  (7,6,'LGA1851'),(7,7,'Z890'),(7,8,'DDR5'),(7,9,'ATX'),
  (8,6,'LGA1700'),(8,7,'B760'),(8,8,'DDR4'),(8,9,'mATX'),
  (9,10,'DDR5'),(9,11,'32'),(9,12,'6000'),
  (10,10,'DDR5'),(10,11,'32'),(10,12,'6400'),
  (11,10,'DDR4'),(11,11,'16'),(11,12,'3200'),
  (12,13,'GeForce RTX 5070 Ti'),(12,14,'16'),(12,15,'750'),
  (13,13,'GeForce RTX 5060 Ti'),(13,14,'16'),(13,15,'600'),
  (14,13,'Radeon RX 9070 XT'),(14,14,'16'),(14,15,'850'),
  (15,13,'GeForce RTX 4060'),(15,14,'8'),(15,15,'550'),
  (16,16,'2000'),(16,17,'PCIe 4.0 NVMe'),
  (17,16,'1000'),(17,17,'PCIe 4.0 NVMe'),
  (18,16,'1000'),(18,17,'PCIe 4.0 NVMe'),
  (19,16,'4000'),(19,17,'SATA III'),
  (20,18,'850'),(20,19,'Gold'),
  (21,18,'750'),(21,19,'Gold'),
  (22,18,'650'),(22,19,'Bronze'),
  (23,20,'ATX'),(24,20,'ATX'),(25,20,'mATX'),
  (26,21,'空冷'),(27,21,'空冷'),(28,21,'水冷'),
  (30,22,'27'),(30,23,'2560x1440'),(30,24,'180'),
  (31,22,'27'),(31,23,'3840x2160'),(31,24,'144'),
  (32,25,'GX 紅軸'),(32,26,'無線'),
  (33,25,'Gateron 茶軸'),(33,26,'藍牙 / 有線'),
  (34,27,'無線'),(34,28,'32000'),
  (35,27,'有線'),(35,28,'30000');

-- ---------- 庫存（各倉庫） ---------------------------------------------
-- 商品 31 全倉缺貨、商品 1 少量，其他依公式產生
INSERT INTO inventory (productid, storeid, on_hand_qty, bin_id)
SELECT p.productid, w.storeid,
       CASE
         WHEN p.productid = 31 THEN 0
         WHEN p.productid = 1 THEN CASE w.storeid WHEN 1 THEN 2 WHEN 2 THEN 1 ELSE 0 END
         WHEN p.category IN ('gpu', 'laptop') THEN 3 + (p.productid + w.storeid) % 4
         WHEN p.sn_required THEN 4 + (p.productid * 3 + w.storeid) % 5
         ELSE 8 + (p.productid * 7 + w.storeid * 3) % 17
       END,
       (SELECT b.bin_id FROM storage_bin b WHERE b.storeid = w.storeid
         ORDER BY b.bin_id OFFSET (p.productid % 27) LIMIT 1)
  FROM product p CROSS JOIN warehouse w;

-- 需序號管理商品的產品序號（每一件在庫商品對應一個序號）
INSERT INTO serial_number (productid, sn, storeid, status)
SELECT i.productid,
       'SN' || lpad(i.productid::text, 3, '0') || '-' || i.storeid || '-' || lpad(n::text, 4, '0'),
       i.storeid, 'in_stock'
  FROM inventory i JOIN product p ON p.productid = i.productid
  CROSS JOIN LATERAL generate_series(1, i.on_hand_qty) n
 WHERE p.sn_required;

-- 期初進貨的庫存異動紀錄（BR-013）
INSERT INTO wh_log (storeid, productid, employee_id, type, quantity, qty_after, source_type, logged_at)
SELECT i.storeid, i.productid, e.employee_id, 'inbound', i.on_hand_qty, i.on_hand_qty, 'purchase', now() - interval '45 days'
  FROM inventory i JOIN employee e ON e.storeid = i.storeid
 WHERE i.on_hand_qty > 0;

-- ---------- 折扣活動（日期相對於今日） ---------------------------------
INSERT INTO discount (code, type, description, start_date, end_date, threshold, method, rate) VALUES
  ('FREESHIP3000', 'shipping', '全站滿 NT$3,000 免運', CURRENT_DATE - 60, CURRENT_DATE + 300, 3000, 'free_shipping', NULL),
  ('SEASON90',     'seasonal', '年終慶：滿 NT$20,000 整筆 9 折', CURRENT_DATE - 10, CURRENT_DATE + 45, 20000, 'rate', 0.90),
  ('NEWYEAR95',    'seasonal', '新年 95 折（尚未開始）', CURRENT_DATE + 50, CURRENT_DATE + 80, NULL, 'rate', 0.95),
  ('SPCGPU88',     'special',  '顯示卡限時特價 88 折', CURRENT_DATE - 5, CURRENT_DATE + 20, NULL, 'rate', 0.88),
  ('SPCFANBOGO',   'special',  'ARGB 風扇買一送一', CURRENT_DATE - 3, CURRENT_DATE + 30, NULL, 'bogo', NULL),
  ('SPCSSD85',     'special',  'SSD 週年慶 85 折', CURRENT_DATE - 7, CURRENT_DATE + 14, NULL, 'rate', 0.85);

INSERT INTO discount_product (code, productid) VALUES
  ('SPCGPU88', 12), ('SPCGPU88', 14),
  ('SPCFANBOGO', 29),
  ('SPCSSD85', 16), ('SPCSSD85', 18);

COMMIT;
