create extension if not exists pgcrypto;

alter table if exists public.profiles
  add column if not exists verification_status text default 'unverified',
  add column if not exists chairman_verification_status text default 'unverified',
  add column if not exists requested_role text,
  add column if not exists building_id uuid,
  add column if not exists apartment_id uuid,
  add column if not exists apartment_number text;

create table if not exists public.building_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  building_id uuid not null,
  apartment_id uuid,
  apartment_number text,
  member_role text not null default 'resident',
  verification_status text not null default 'pending',
  created_at timestamptz not null default now(),
  verified_at timestamptz,
  verified_by uuid,
  unique (user_id, building_id, apartment_id)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'building_members_member_role_check'
  ) then
    alter table public.building_members
      add constraint building_members_member_role_check
      check (member_role in ('resident', 'chairman', 'manager', 'master', 'admin'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'building_members_verification_status_check'
  ) then
    alter table public.building_members
      add constraint building_members_verification_status_check
      check (verification_status in ('pending', 'verified', 'approved', 'rejected', 'revoked'));
  end if;
end $$;

alter table if exists public.tasks
  add column if not exists building_id uuid,
  add column if not exists final_price numeric,
  add column if not exists priority text default 'medium';

alter table if exists public.announcements
  add column if not exists building_id uuid,
  add column if not exists is_urgent boolean default false;

alter table if exists public.proposals
  add column if not exists building_id uuid,
  add column if not exists author_id uuid,
  add column if not exists created_by uuid,
  add column if not exists description text,
  add column if not exists status text default 'active',
  add column if not exists is_active boolean default true,
  add column if not exists start_at timestamptz default now(),
  add column if not exists end_at timestamptz,
  add column if not exists quorum_rule text default 'simple_majority',
  add column if not exists created_at timestamptz default now();

alter table if exists public.votes
  add column if not exists building_id uuid,
  add column if not exists apartment_id uuid,
  add column if not exists apartment text,
  add column if not exists full_name text,
  add column if not exists choice text,
  add column if not exists decision text,
  add column if not exists signature_url text,
  add column if not exists signature_hash text,
  add column if not exists voted_at timestamptz default now(),
  add column if not exists created_at timestamptz default now();

create index if not exists idx_building_members_user
  on public.building_members (user_id);
create index if not exists idx_building_members_building
  on public.building_members (building_id);
create index if not exists idx_tasks_building
  on public.tasks (building_id);
create index if not exists idx_announcements_building
  on public.announcements (building_id);
create index if not exists idx_proposals_building_status
  on public.proposals (building_id, status);
create index if not exists idx_votes_proposal
  on public.votes (proposal_id);
create index if not exists idx_votes_building
  on public.votes (building_id);
create unique index if not exists idx_votes_proposal_user_unique
  on public.votes (proposal_id, user_id);

alter table public.building_members enable row level security;

drop policy if exists "building_members_select_own_or_manager" on public.building_members;
create policy "building_members_select_own_or_manager"
  on public.building_members
  for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.building_members bm
      where bm.user_id = auth.uid()
        and bm.building_id = building_members.building_id
        and bm.member_role in ('chairman', 'manager', 'admin')
        and bm.verification_status in ('verified', 'approved')
    )
  );

drop policy if exists "building_members_insert_own_pending" on public.building_members;
create policy "building_members_insert_own_pending"
  on public.building_members
  for insert
  with check (user_id = auth.uid());

do $$
begin
  if to_regclass('public.tasks') is not null then
    alter table public.tasks enable row level security;
    drop policy if exists "tasks_building_scope_select" on public.tasks;
    create policy "tasks_building_scope_select"
      on public.tasks
      for select
      using (
        user_id = auth.uid()
        or master_id = auth.uid()
        or exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = tasks.building_id
            and bm.verification_status in ('verified', 'approved')
        )
      );

    drop policy if exists "tasks_building_scope_insert" on public.tasks;
    create policy "tasks_building_scope_insert"
      on public.tasks
      for insert
      with check (
        user_id = auth.uid()
        and (
          building_id is null
          or exists (
            select 1
            from public.building_members bm
            where bm.user_id = auth.uid()
              and bm.building_id = tasks.building_id
              and bm.verification_status in ('verified', 'approved')
          )
        )
      );
  end if;
end $$;

do $$
begin
  if to_regclass('public.announcements') is not null then
    alter table public.announcements enable row level security;
    drop policy if exists "announcements_building_scope_select" on public.announcements;
    create policy "announcements_building_scope_select"
      on public.announcements
      for select
      using (
        exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = announcements.building_id
            and bm.verification_status in ('verified', 'approved')
        )
      );

    drop policy if exists "announcements_manager_insert" on public.announcements;
    create policy "announcements_manager_insert"
      on public.announcements
      for insert
      with check (
        exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = announcements.building_id
            and bm.member_role in ('chairman', 'manager', 'admin')
            and bm.verification_status in ('verified', 'approved')
        )
      );
  end if;
end $$;

do $$
begin
  if to_regclass('public.proposals') is not null then
    alter table public.proposals enable row level security;
    drop policy if exists "proposals_building_scope_select" on public.proposals;
    create policy "proposals_building_scope_select"
      on public.proposals
      for select
      using (
        exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = proposals.building_id
            and bm.verification_status in ('verified', 'approved')
        )
      );

    drop policy if exists "proposals_manager_insert" on public.proposals;
    create policy "proposals_manager_insert"
      on public.proposals
      for insert
      with check (
        exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = proposals.building_id
            and bm.member_role in ('chairman', 'manager', 'admin')
            and bm.verification_status in ('verified', 'approved')
        )
      );
  end if;
end $$;

do $$
begin
  if to_regclass('public.votes') is not null then
    alter table public.votes enable row level security;
    drop policy if exists "votes_building_scope_select" on public.votes;
    create policy "votes_building_scope_select"
      on public.votes
      for select
      using (
        exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = votes.building_id
            and bm.verification_status in ('verified', 'approved')
        )
      );

    drop policy if exists "votes_verified_member_insert" on public.votes;
    create policy "votes_verified_member_insert"
      on public.votes
      for insert
      with check (
        user_id = auth.uid()
        and exists (
          select 1
          from public.building_members bm
          where bm.user_id = auth.uid()
            and bm.building_id = votes.building_id
            and bm.apartment_id = votes.apartment_id
            and bm.verification_status in ('verified', 'approved')
        )
      );
  end if;
end $$;
