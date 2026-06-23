-- ============================================================
-- 餐飲業成本物料控管系統 — Supabase 資料庫建表 SQL
-- 建立順序：依序在 Supabase SQL Editor 執行此檔案
-- ============================================================

-- 1. 啟用 UUID 擴充
create extension if not exists "uuid-ossp";

-- 2. 門店表
create table if not exists stores (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  code text unique,
  created_at timestamptz default now()
);

-- 3. 用戶檔案（連結 Supabase auth.users）
create table if not exists profiles (
  id uuid references auth.users primary key,
  full_name text,
  role text check (role in ('admin', 'store_manager')) default 'store_manager',
  store_id uuid references stores(id),
  created_at timestamptz default now()
);

-- 4. 品項基本資料
create table if not exists items (
  id uuid default uuid_generate_v4() primary key,
  store_id uuid references stores(id) on delete cascade,
  name text not null,
  unit text default '個',
  selling_price numeric(10,2) default 0,
  min_stock_qty numeric(10,2) default 0,
  category text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 5. 每日進出記錄
create table if not exists inventory_records (
  id uuid default uuid_generate_v4() primary key,
  item_id uuid references items(id) on delete cascade,
  store_id uuid references stores(id) on delete cascade,
  record_date date not null default current_date,
  purchase_qty numeric(10,2) default 0,
  purchase_cost numeric(10,2) default 0,
  waste_qty numeric(10,2) default 0,
  current_stock numeric(10,2) default 0,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================
alter table stores enable row level security;
alter table profiles enable row level security;
alter table items enable row level security;
alter table inventory_records enable row level security;

-- Helper: 判斷是否為 admin
create or replace function is_admin()
returns boolean language sql security definer as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Helper: 取得目前用戶的 store_id
create or replace function get_user_store_id()
returns uuid language sql security definer as $$
  select store_id from profiles where id = auth.uid();
$$;

-- profiles: 只能讀寫自己
create policy "profiles_select" on profiles for select using (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);

-- stores: admin 看全部，store_manager 看自己的店
create policy "stores_admin" on stores for all using (is_admin());
create policy "stores_manager" on stores for select using (id = get_user_store_id());

-- items: admin 管全部，store_manager 管自己店
create policy "items_admin" on items for all using (is_admin());
create policy "items_manager" on items for all using (store_id = get_user_store_id());

-- inventory_records: admin 管全部，store_manager 管自己店
create policy "records_admin" on inventory_records for all using (is_admin());
create policy "records_manager" on inventory_records for all using (store_id = get_user_store_id());

-- 注意：profile 由 setup.html 前端在用戶登入後手動 upsert，不使用 trigger。
-- 若要重設，確保 Supabase 沒有 on_auth_user_created trigger 在 auth.users 上。
