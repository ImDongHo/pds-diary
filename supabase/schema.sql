-- PDS Diary — Supabase (Postgres) schema
-- Supabase 대시보드 → SQL Editor에 전체 붙여넣고 실행하세요.
-- (이미 6번 과제 버전으로 만든 프로젝트가 있다면 이 파일 대신 supabase/migration_auth.sql을 실행하세요.
--  이 파일은 처음부터 새로 만드는 프로젝트를 위한 최종본입니다.)

create table if not exists plans (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  plan_id bigint not null references plans(id) on delete cascade,
  changed_at timestamptz not null default now(),
  previous_json jsonb not null
);

create table if not exists tasks (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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

-- 돌아보기의 "고칠 점 한 줄"은 이제 계정마다 하나씩 (예전엔 id=1 단일 행이었음)
create table if not exists next_plan (
  user_id uuid primary key references auth.users(id) on delete cascade,
  text text not null default ''
);


-- =====================================================
-- Row Level Security
-- 7번 과제: 로그인한 본인 소유의 행만 읽기/쓰기 가능하게 잠근다.
-- 클라이언트는 insert 시 user_id를 넣지 않아도 된다 — 컬럼 default가
-- 요청자의 auth.uid()로 자동 채워주고, RLS가 그 값과 실제 로그인한
-- 사용자가 같은지 확인한다(auth.uid() = user_id).
-- =====================================================

alter table plans enable row level security;
alter table plan_history enable row level security;
alter table tasks enable row level security;
alter table executions enable row level security;
alter table next_plan enable row level security;

create policy "own_plans" on plans for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_plan_history" on plan_history for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_tasks" on tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_executions" on executions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_next_plan" on next_plan for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- =====================================================
-- 계정 삭제 (T07-C134)
-- 프론트엔드에 서버 코드가 없으므로, "내 계정 삭제" 버튼은 이 함수를
-- supabase.rpc('delete_own_account')로 호출한다. auth.users에서 본인
-- 행을 지우면 위 모든 테이블의 user_id가 ON DELETE CASCADE로 걸려
-- 있어서 그 계정의 자료가 전부 함께 지워진다.
-- =====================================================

create or replace function delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function delete_own_account() to authenticated;
