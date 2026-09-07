-- ============================================================
-- 修正「大陸廠商」品項的 BOM 換算：進貨單位 kg → BOM 單位 g 應為 1 kg = 1000 g
-- 請在 Supabase Dashboard → SQL Editor 執行
--
-- 背景：進貨成本參考裡，部分大陸進貨的中藥材（例：山藥（乾）、玉竹片）
-- 進貨單位是 kg，但 BOM 換算沒設成 1000，導致「每 g 成本」被當成「每 kg 成本」
-- （顯示 $250.000/g 這種明顯過大的數字）。這裡把 kg 進貨、g 計量、換算不是 1000 的
-- 全部修正為 1 kg = 1000 g。
--
-- 只動「進貨單位是 kg」且「BOM 計量單位是 g（或未設）」的列，
-- 不碰以份／包／盒／顆…計價的品項。
-- ============================================================

-- ── 步驟 1：先預覽所有大陸相關品項的換算狀態，確認要改的對不對 ──────
SELECT
  name AS 品名, category AS 類別, supplier AS 廠商,
  unit AS 進貨單位, bom_unit AS BOM單位, bom_conversion AS 換算數量,
  unit_cost AS 每進貨單位成本,
  round(unit_cost / NULLIF(bom_conversion, 0), 4) AS 目前每BOM單位成本,
  CASE
    WHEN lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
         AND (bom_unit = 'g' OR bom_unit IS NULL OR bom_unit = '')
         AND coalesce(bom_conversion, 0) <> 1000
      THEN '❌ 需修正 → 1 kg = 1000 g（改後每 g ≈ ' || round(unit_cost / 1000.0, 4) || '）'
    WHEN lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
         AND bom_unit = 'g' AND bom_conversion = 1000
      THEN '✅ 已正確（1 kg = 1000 g）'
    ELSE '— 非 kg→g，請人工確認'
  END AS 檢視結果
FROM items
WHERE is_active
  AND ( supplier ILIKE '%大陸%'
        OR category IN ('中藥材','中藥類','大陸進貨') )
ORDER BY
  (lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
   AND (bom_unit = 'g' OR bom_unit IS NULL OR bom_unit = '')
   AND coalesce(bom_conversion, 0) <> 1000) DESC,
  supplier, name;

-- ── 步驟 2：確認步驟 1 標「❌ 需修正」的品名都對，再跑這段 ───────────
UPDATE items
SET bom_conversion = 1000,
    bom_unit = 'g'
WHERE is_active
  AND supplier ILIKE '%大陸%'
  AND lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
  AND (bom_unit = 'g' OR bom_unit IS NULL OR bom_unit = '')
  AND coalesce(bom_conversion, 0) <> 1000;

-- ── 步驟 3：驗證（所有大陸 kg 品項都應該是 1 kg = 1000 g，每 g 成本回到合理值）──
SELECT
  name AS 品名, supplier AS 廠商, unit AS 進貨單位,
  bom_unit AS BOM單位, bom_conversion AS 換算數量,
  round(unit_cost / NULLIF(bom_conversion, 0), 4) AS 每g成本
FROM items
WHERE is_active
  AND supplier ILIKE '%大陸%'
  AND lower(regexp_replace(coalesce(unit,''), '\s', '', 'g')) IN ('kg','公斤','千克')
ORDER BY name;
