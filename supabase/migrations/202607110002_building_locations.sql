-- Coordinates and city for the shared building picker.
alter table if exists public.buildings
  add column if not exists city text,
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists total_apartments integer not null default 0;

create index if not exists idx_buildings_city on public.buildings (city);

alter table public.buildings enable row level security;

drop policy if exists "buildings_select_authenticated" on public.buildings;
create policy "buildings_select_authenticated"
  on public.buildings for select to authenticated using (true);

drop policy if exists "buildings_insert_by_chairman" on public.buildings;
create policy "buildings_insert_by_chairman"
  on public.buildings for insert to authenticated
  with check (
    chairman_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role::text, p.user_type::text) in ('osi', 'chairman', 'admin')
    )
  );
