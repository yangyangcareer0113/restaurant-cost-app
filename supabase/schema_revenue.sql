-- ============================================================
-- 月營業額記錄表（手動從肚肚結帳系統輸入）
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

CREATE TABLE IF NOT EXISTS monthly_revenues (
  id          uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  period      text NOT NULL,           -- 格式 YYYY-MM
  revenue     numeric(12,2) DEFAULT 0, -- 肚肚當月營業額
  notes       text,
  updated_by  uuid REFERENCES auth.users(id),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(store_id, period)
);

ALTER TABLE monthly_revenues ENABLE ROW LEVEL SECURITY;

-- admin 全部操作；store_manager 只能讀自己門店
CREATE POLICY "revenue_admin"          ON monthly_revenues FOR ALL    USING (is_admin());
CREATE POLICY "revenue_manager_select" ON monthly_revenues FOR SELECT USING (store_id = get_user_store_id());
