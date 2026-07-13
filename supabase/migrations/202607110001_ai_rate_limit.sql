create table if not exists public.ai_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.ai_rate_limits enable row level security;

create or replace function public.consume_ai_quota(
  p_user_id uuid,
  p_limit integer default 10
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed boolean;
begin
  if p_limit < 1 then
    raise exception 'p_limit must be positive';
  end if;

  insert into public.ai_rate_limits as limits (
    user_id, window_started_at, request_count, updated_at
  )
  values (p_user_id, now(), 1, now())
  on conflict (user_id) do update
    set window_started_at = case
          when now() - limits.window_started_at >= interval '1 minute' then now()
          else limits.window_started_at
        end,
        request_count = case
          when now() - limits.window_started_at >= interval '1 minute' then 1
          else limits.request_count + 1
        end,
        updated_at = now()
  where now() - limits.window_started_at >= interval '1 minute'
     or limits.request_count < p_limit
  returning true into allowed;

  return coalesce(allowed, false);
end;
$$;

revoke all on function public.consume_ai_quota(uuid, integer) from public;
grant execute on function public.consume_ai_quota(uuid, integer) to service_role;
