-- ============================================================
-- Migration：新增 accountant 角色
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

-- 1. profiles 新增 accountant 角色
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'store_manager', 'accountant'));

-- 2. 新增 is_accountant() helper function
CREATE OR REPLACE FUNCTION is_accountant()
RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'accountant');
$$;

-- 3. monthly_overhead RLS 更新
--    舊規則：store_manager 可全部操作
--    新規則：accountant 可全部操作；store_manager 只能讀；admin 全部操作
ALTER TABLE monthly_overhead ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "overhead_admin"            ON monthly_overhead;
DROP POLICY IF EXISTS "overhead_manager"          ON monthly_overhead;
DROP POLICY IF EXISTS "overhead_manager_all"      ON monthly_overhead;
DROP POLICY IF EXISTS "overhead_manager_select"   ON monthly_overhead;
DROP POLICY IF EXISTS "overhead_accountant"       ON monthly_overhead;
DROP POLICY IF EXISTS "overhead_accountant_all"   ON monthly_overhead;

-- admin：全部操作
CREATE POLICY "overhead_admin" ON monthly_overhead
  FOR ALL USING (is_admin());

-- accountant：在自己門店全部操作
CREATE POLICY "overhead_accountant_all" ON monthly_overhead
  FOR ALL
  USING (is_accountant() AND store_id = get_user_store_id())
  WITH CHECK (is_accountant() AND store_id = get_user_store_id());

-- store_manager：只能讀（KPI 顯示用）
CREATE POLICY "overhead_manager_select" ON monthly_overhead
  FOR SELECT USING (store_id = get_user_store_id());
