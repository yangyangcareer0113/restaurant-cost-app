-- ============================================================
-- Migration：員工管理新增手動排序功能
-- 背景：員工管理頁改為可拖曳調整順序。新增 sort_order 欄位，
--       並將「目前依姓名排序」的順序凍結為初始值，
--       之後新增員工預設排在最後，可再手動拖曳調整。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

ALTER TABLE staff ADD COLUMN IF NOT EXISTS sort_order integer;

UPDATE staff SET sort_order = sub.rn
FROM (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY name) AS rn
  FROM staff
) sub
WHERE staff.id = sub.id;
