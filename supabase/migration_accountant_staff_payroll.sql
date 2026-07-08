-- ============================================================
-- Migration：補上 staff / payroll_records 的 accountant 寫入權限
-- 背景：schema_staff_payroll.sql 建表時只給了 admin 全權限、
--       其他角色只有 SELECT，導致會計角色無法新增/編輯/刪除員工、
--       也無法新增/編輯薪資記錄。比照 monthly_overhead 的作法
--       （見 migration_accountant_role.sql）補上 accountant 政策。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

-- 1. staff：accountant 在自己門店全部操作（新增/編輯/刪除員工、辦理離職、恢復在職）
DROP POLICY IF EXISTS "staff_accountant_all" ON staff;
CREATE POLICY "staff_accountant_all" ON staff
  FOR ALL
  USING (is_accountant() AND store_id = get_user_store_id())
  WITH CHECK (is_accountant() AND store_id = get_user_store_id());

-- 2. payroll_records：accountant 在自己門店全部操作（新增/編輯薪資記錄）
DROP POLICY IF EXISTS "payroll_accountant_all" ON payroll_records;
CREATE POLICY "payroll_accountant_all" ON payroll_records
  FOR ALL
  USING (is_accountant() AND store_id = get_user_store_id())
  WITH CHECK (is_accountant() AND store_id = get_user_store_id());
