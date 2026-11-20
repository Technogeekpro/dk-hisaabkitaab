-- Staff incentives: a fixed amount per item on each product, who sold each
-- sale (with the standard price and incentive captured at the time), and
-- payouts made to staff. Existing rows keep working: old sales have no seller,
-- so they carry no incentive.
alter table public.dk_products
  add column incentive numeric(12,2) not null default 15 check (incentive >= 0);

alter table public.dk_sales
  add column seller text
    check (seller is null or length(btrim(seller)) between 1 and 50),
  add column standard_price numeric(12,2)
    check (standard_price is null or standard_price >= 0),
  add column incentive_per_item numeric(12,2) not null default 0
    check (incentive_per_item >= 0);

create table public.dk_staff_payouts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  employee text not null check (length(btrim(employee)) between 1 and 50),
  amount numeric(12,2) not null check (amount > 0),
  method text not null check (method in ('cash', 'upi')),
  paid_on date not null,
  note text not null default '' check (length(note) <= 100),
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);

create index dk_staff_payouts_owner_date_idx
  on public.dk_staff_payouts (owner_id, paid_on desc);

alter table public.dk_staff_payouts enable row level security;

create policy "Owners read staff payouts" on public.dk_staff_payouts
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy "Owners insert staff payouts" on public.dk_staff_payouts
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "Owners delete staff payouts" on public.dk_staff_payouts
  for delete to authenticated using ((select auth.uid()) = owner_id);

grant select, insert, delete on public.dk_staff_payouts to authenticated;
revoke all on public.dk_staff_payouts from anon;
