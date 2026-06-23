-- ============================================================
-- 人事成本模組 — 新增資料表
-- 在 Supabase SQL Editor 執行此檔案（接在原本 schema.sql 後面）
-- ============================================================

-- 1. 員工基本資料表
create table if not exists staff (
  id uuid default uuid_generate_v4() primary key,
  store_id uuid references stores(id) on delete cascade,
  name text not null,
  position text not null,
  base_salary numeric(10,0) not null default 0,
  position_allowance numeric(10,0) not null default 0,
  attendance_bonus_amount numeric(10,0) not null default 0,
  hire_date date,
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. 每月薪資發放記錄
create table if not exists payroll_records (
  id uuid default uuid_generate_v4() primary key,
  store_id uuid references stores(id) on delete cascade,
  staff_id uuid references staff(id) on delete cascade,
  year int not null,
  month int not null,
  base_salary numeric(10,0) not null default 0,
  position_allowance numeric(10,0) not null default 0,
  attendance_bonus numeric(10,0) not null default 0,
  performance_bonus numeric(10,0) not null default 0,
  special_bonus numeric(10,0) not null default 0,
  deductions numeric(10,0) not null default 0,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(staff_id, year, month)
);

-- 3. RLS 政策 — staff
alter table staff enable row level security;

create policy "admin_all_staff" on staff
  for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "store_view_own_staff" on staff
  for select
  using (
    exists (select 1 from profiles where id = auth.uid() and store_id = staff.store_id)
  );

-- 4. RLS 政策 — payroll_records
alter table payroll_records enable row level security;

create policy "admin_all_payroll" on payroll_records
  for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "store_view_own_payroll" on payroll_records
  for select
  using (
    exists (select 1 from profiles where id = auth.uid() and store_id = payroll_records.store_id)
  );

-- 5. 自動更新 updated_at
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger staff_updated_at
  before update on staff
  for each row execute function update_updated_at();

create trigger payroll_updated_at
  before update on payroll_records
  for each row execute function update_updated_at();
