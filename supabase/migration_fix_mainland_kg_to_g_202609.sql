-- ============================================================
-- 修正 BOM 換算：進貨單位 kg、BOM 以 g 計 → 換算必為 1 kg = 1000 g
-- 請在 Supabase Dashboard → SQL Editor 執行
--
-- 現況（2026-09-07 檢視 32 筆大陸相關品項後確認）：
--   ‧ 大陸廠商 + kg 的中藥材大多已是 1000（山藥（乾）、玉竹片…先前已修正）
--   ‧ 仍是「換算 1」的 kg→g 品項：栀子、竹笙（乾）（廠商欄空白、成本 0）
--   ‧ 非 kg 但換算異常（要人工給每單位重量、無法自動改）：
--       豆醬（大陸／調味類，1 桶 = ? g）、響鈴捲（大陸／食材類，1 箱 = ? g）、
--       無花果-切片、無花果-剖半（中藥材，1 箱 = ? g，目前無成本）
--
-- 1 kg = 1000 g 是恆等式，這裡不限廠商，只要「kg 進貨 + g 計量 + 換算 ≠ 1000」就修。
-- ============================================================

-- ── 步驟 1：預覽會被改到的品項（換算不是 1000 的 kg→g 品項）─────────
SELECT name AS 品名, category AS 類別, supplier AS 廠商,
       unit AS 進貨單位, bom_unit AS BOM單位, bom_conversion AS 目前換算, unit_cost AS 每kg成本
FROM items
WHERE is_active
  AND lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
  AND bom_unit = 'g'
  AND coalesce(bom_conversion, 0) <> 1000
ORDER BY name;

-- ── 步驟 2：確認步驟 1 列出的品名都對，再執行 ────────────────────────
UPDATE items
SET bom_conversion = 1000
WHERE is_active
  AND lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
  AND bom_unit = 'g'
  AND coalesce(bom_conversion, 0) <> 1000;

-- ── 步驟 3：驗證——所有 kg→g 品項都應是 1000，每 g 成本回到合理值 ──────
SELECT name AS 品名, category AS 類別, supplier AS 廠商,
       unit AS 進貨單位, bom_conversion AS 換算,
       round(unit_cost / 1000.0, 4) AS 每g成本
FROM items
WHERE is_active
  AND lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
  AND bom_unit = 'g'
ORDER BY category, name;

-- ============================================================
-- 響鈴捲：1 箱 = 300 卷 → BOM 以「卷」計，每卷成本 = 每箱成本 ÷ 300
-- （進貨單位維持「箱」，配方裡用「卷」計價）
-- ============================================================

-- 預覽
SELECT name, category, supplier, unit AS 進貨單位, bom_unit AS BOM單位,
       bom_conversion AS 目前換算, unit_cost AS 每箱成本,
       round(unit_cost / 300.0, 4) AS 改後每卷成本
FROM items
WHERE is_active AND name = '響鈴捲';

-- 修正
UPDATE items
SET bom_unit = '卷', bom_conversion = 300
WHERE is_active AND name = '響鈴捲';

-- 驗證
SELECT name, unit AS 進貨單位, bom_unit AS BOM單位, bom_conversion AS 換算,
       round(unit_cost / NULLIF(bom_conversion,0), 4) AS 每卷成本
FROM items
WHERE is_active AND name = '響鈴捲';

-- ============================================================
-- 豆醬：1 桶 = 5 公斤 = 5000 g → BOM 以 g 計，每 g 成本 = 每桶成本 ÷ 5000
-- （進貨單位維持「桶」）
-- ============================================================

-- 預覽
SELECT name, unit AS 進貨單位, bom_unit AS BOM單位, bom_conversion AS 目前換算,
       unit_cost AS 每桶成本, round(unit_cost / 5000.0, 4) AS 改後每g成本
FROM items
WHERE is_active AND name = '豆醬';

-- 修正
UPDATE items
SET bom_unit = 'g', bom_conversion = 5000
WHERE is_active AND name = '豆醬';

-- 驗證
SELECT name, unit AS 進貨單位, bom_unit AS BOM單位, bom_conversion AS 換算,
       round(unit_cost / NULLIF(bom_conversion,0), 4) AS 每g成本
FROM items
WHERE is_active AND name = '豆醬';
