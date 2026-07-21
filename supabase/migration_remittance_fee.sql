-- ============================================================
-- Migration：月度費用補充新增「匯費」欄位
-- 背景：薪資計算頁的「月度費用補充」區塊新增匯費輸入欄位，
--       計入總人事成本。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

ALTER TABLE monthly_overhead ADD COLUMN IF NOT EXISTS remittance_fee numeric DEFAULT 0;
