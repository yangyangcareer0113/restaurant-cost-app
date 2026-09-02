-- ============================================================
-- 修正部分品項單位（2026-09-02）
-- 請在 Supabase Dashboard → SQL Editor 執行
--
-- 紙杯、飲料杯、吸管         → 箱
-- 耐熱袋PP10*15（佳唯）      → 包
-- 可樂、雪碧                 → 罐
-- ============================================================

-- ── 步驟 1：先預覽會被改到的品項，確認品名沒抓錯 ──────────────
SELECT id, name, category, unit,
  CASE
    WHEN name LIKE '%紙杯%' OR name LIKE '%飲料杯%' OR name LIKE '%吸管%' THEN '箱'
    WHEN name LIKE '耐熱袋PP10%' THEN '包'
    WHEN name LIKE '%可樂%' OR name LIKE '%雪碧%' THEN '罐'
  END AS new_unit
FROM items
WHERE name LIKE '%紙杯%' OR name LIKE '%飲料杯%' OR name LIKE '%吸管%'
   OR name LIKE '耐熱袋PP10%'
   OR name LIKE '%可樂%' OR name LIKE '%雪碧%'
ORDER BY name;

-- ── 步驟 2：確認上面列出的都對，再跑這段 ─────────────────────
UPDATE items SET unit = '箱'
WHERE name LIKE '%紙杯%' OR name LIKE '%飲料杯%' OR name LIKE '%吸管%';

UPDATE items SET unit = '包'
WHERE name LIKE '耐熱袋PP10%';

UPDATE items SET unit = '罐'
WHERE name LIKE '%可樂%' OR name LIKE '%雪碧%';

-- ── 步驟 3：驗證 ────────────────────────────────────────────
SELECT name, unit FROM items
WHERE name LIKE '%紙杯%' OR name LIKE '%飲料杯%' OR name LIKE '%吸管%'
   OR name LIKE '耐熱袋PP10%'
   OR name LIKE '%可樂%' OR name LIKE '%雪碧%'
ORDER BY name;
