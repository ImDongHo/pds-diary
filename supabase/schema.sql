-- PDS Diary — Supabase (Postgres) schema
-- Supabase 대시보드 → SQL Editor에 전체 붙여넣고 실행하세요.

create table if not exists plans (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  start_date date not null,
  end_date date not null,
  priority text not null,
  success text,
  estimated_minutes integer not null default 0,
  color text not null default 'mint',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 계획을 수정할 때마다 수정 전 행 전체를 JSON으로 스냅샷해서 쌓는다 (T06-C08)
create table if not exists plan_history (
  id bigint generated always as identity primary key,
  plan_id bigint not null references plans(id) on delete cascade,
  changed_at timestamptz not null default now(),
  previous_json jsonb not null
);

create table if not exists tasks (
  id bigint generated always as identity primary key,
  plan_id bigint not null references plans(id) on delete cascade,
  title text not null,
  priority text not null default 'medium',
  deadline date not null,
  tag text,
  estimated_minutes integer not null default 0,
  status text not null default 'todo',
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists executions (
  id bigint generated always as identity primary key,
  task_id bigint not null references tasks(id) on delete cascade,
  start_time timestamptz not null,
  end_time timestamptz not null,
  actual_minutes integer not null default 0,
  blocked_reason text,
  memo text,
  completion boolean not null default false,
  created_at timestamptz not null default now(),
  unique (task_id, start_time, end_time)  -- 같은 완료/기록 요청이 두 번 들어와도 DB가 막아준다 (T06-C21, C22)
);

create table if not exists next_plan (
  id integer primary key default 1,
  text text not null default '',
  constraint next_plan_singleton check (id = 1)
);
insert into next_plan (id, text) values (1, '') on conflict (id) do nothing;


-- =====================================================
-- Row Level Security
-- 지금은 로그인이 없는 과제라 "누구나 읽기/쓰기 가능"으로 열어둔다.
-- 7번 과제(로그인 잠그기)에서 user_id 컬럼을 추가하고
-- policy를 auth.uid() = user_id 로 교체하면 된다.
-- =====================================================

alter table plans enable row level security;
alter table plan_history enable row level security;
alter table tasks enable row level security;
alter table executions enable row level security;
alter table next_plan enable row level security;

create policy "public_all_plans" on plans for all using (true) with check (true);
create policy "public_all_plan_history" on plan_history for all using (true) with check (true);
create policy "public_all_tasks" on tasks for all using (true) with check (true);
create policy "public_all_executions" on executions for all using (true) with check (true);
create policy "public_all_next_plan" on next_plan for all using (true) with check (true);
