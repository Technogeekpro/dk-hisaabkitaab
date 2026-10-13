-- Tables owned by the D.K. Mobiles profit app. Existing Case Point tables are untouched.
create table public.dk_products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  name text not null check (length(btrim(name)) between 1 and 100),
  cost numeric(12,2) not null check (cost >= 0),
  price numeric(12,2) not null check (price >= 0),
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);

create table public.dk_sales (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  product_name text not null check (length(btrim(product_name)) between 1 and 100),
  cost numeric(12,2) not null check (cost >= 0),
  price numeric(12,2) not null check (price >= 0),
  quantity integer not null check (quantity > 0),
  sold_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);

create table public.dk_expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  amount numeric(12,2) not null check (amount > 0),
  note text not null check (length(btrim(note)) between 1 and 100),
  expense_date date not null,
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);

create table public.dk_payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  amount numeric(12,2) not null check (amount > 0),
  method text not null check (method in ('cash', 'upi')),
  paid_on date not null,
  note text not null default '' check (length(note) <= 100),
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);

create index dk_sales_owner_date_idx on public.dk_sales (owner_id, sold_at desc);
create index dk_expenses_owner_date_idx on public.dk_expenses (owner_id, expense_date desc);
create index dk_payments_owner_date_idx on public.dk_payments (owner_id, paid_on desc);

alter table public.dk_products enable row level security;
alter table public.dk_sales enable row level security;
alter table public.dk_expenses enable row level security;
alter table public.dk_payments enable row level security;

create policy "Owners read products" on public.dk_products for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Owners insert products" on public.dk_products for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Owners update products" on public.dk_products for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "Owners delete products" on public.dk_products for delete to authenticated
  using ((select auth.uid()) = owner_id);

create policy "Owners read sales" on public.dk_sales for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Owners insert sales" on public.dk_sales for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Owners delete sales" on public.dk_sales for delete to authenticated
  using ((select auth.uid()) = owner_id);

create policy "Owners read expenses" on public.dk_expenses for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Owners insert expenses" on public.dk_expenses for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Owners delete expenses" on public.dk_expenses for delete to authenticated
  using ((select auth.uid()) = owner_id);

create policy "Owners read payments" on public.dk_payments for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "Owners insert payments" on public.dk_payments for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "Owners delete payments" on public.dk_payments for delete to authenticated
  using ((select auth.uid()) = owner_id);

grant select, insert, update, delete on public.dk_products to authenticated;
grant select, insert, delete on public.dk_sales, public.dk_expenses, public.dk_payments to authenticated;
revoke all on public.dk_products, public.dk_sales, public.dk_expenses, public.dk_payments from anon;
