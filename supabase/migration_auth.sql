-- PDS Diary — 7번 과제(인증) 마이그레이션
-- 이미 6번 과제로 배포해둔 Supabase 프로젝트(=public 정책으로 열려있는 상태)를
-- 로그인 잠금 구조로 옮길 때 이 파일을 순서대로 실행하세요.
-- 이미 만든 프로젝트가 아니라 처음부터 새로 만드는 거라면, 이 파일 대신
-- supabase/schema.sql을 통째로 실행하면 됩니다.

-- =====================================================
-- 0단계. 먼저 이 파일을 실행하기 전에
--  1) Supabase 대시보드 → Authentication → Providers에서 Email 로그인이 켜져 있는지 확인
--  2) 본인 실제 계정을 하나 만들어 두세요 (index.html의 회원가입 화면 또는
--     Authentication → Users → Add user)
--  3) Authentication → Users에서 방금 만든 계정의 UUID를 복사해 두세요.
--     아래 스크립트의 'YOUR-UUID-HERE' 부분을 전부 그 값으로 바꿔서 실행합니다.
-- =====================================================


-- =====================================================
-- 1단계. user_id 컬럼을 일단 "nullable"로 추가한다
-- (기존에 넣어둔 행들은 아직 주인이 없으므로 NOT NULL을 바로 걸 수 없음)
-- =====================================================
alter table plans add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table plan_history add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table tasks add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table executions add column if not exists user_id uuid references auth.users(id) on delete cascade;


-- =====================================================
-- 2단계. 기존에 넣어둔 실제 데이터를 본인 계정 소유로 옮긴다 (T07-C100)
-- 'YOUR-UUID-HERE'를 본인 계정의 UUID로 바꿔서 아래 4줄만 따로 실행하세요.
-- 테스트용으로 넣었다가 지울 더미 데이터뿐이라면 이 단계는 건너뛰고
-- Settings의 "전체 데이터 초기화"를 나중에 써도 됩니다.
-- =====================================================
-- update plans set user_id = 'YOUR-UUID-HERE' where user_id is null;
-- update plan_history set user_id = 'YOUR-UUID-HERE' where user_id is null;
-- update tasks set user_id = 'YOUR-UUID-HERE' where user_id is null;
-- update executions set user_id = 'YOUR-UUID-HERE' where user_id is null;

-- 주인이 없는 행이 하나도 없는지 확인 (전부 0이어야 3단계로 넘어갈 수 있음)
-- select
--   (select count(*) from plans where user_id is null) as plans_orphan,
--   (select count(*) from plan_history where user_id is null) as plan_history_orphan,
--   (select count(*) from tasks where user_id is null) as tasks_orphan,
--   (select count(*) from executions where user_id is null) as executions_orphan;


-- =====================================================
-- 3단계. NOT NULL로 잠그고, 앞으로 들어올 행은 자동으로 로그인한
-- 사람의 id가 채워지도록 default를 건다 (2단계까지 끝난 뒤에 실행)
-- =====================================================
alter table plans alter column user_id set not null;
alter table plans alter column user_id set default auth.uid();
alter table plan_history alter column user_id set not null;
alter table plan_history alter column user_id set default auth.uid();
alter table tasks alter column user_id set not null;
alter table tasks alter column user_id set default auth.uid();
alter table executions alter column user_id set not null;
alter table executions alter column user_id set default auth.uid();


-- =====================================================
-- 4단계. next_plan을 "단일 행(id=1)"에서 "계정마다 한 행"으로 바꾼다
-- 이전에 next_plan에 적어둔 텍스트를 유지하고 싶다면, 이 단계 실행 전에
-- 아래 select로 먼저 값을 확인해 적어 두세요.
-- select text from next_plan where id = 1;
-- =====================================================
alter table next_plan drop constraint if exists next_plan_singleton;
alter table next_plan drop constraint if exists next_plan_pkey;
alter table next_plan drop column if exists id;
alter table next_plan add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- 위에서 확인해둔 이전 텍스트를 본인 계정으로 옮기고 싶다면 (선택):
-- update next_plan set user_id = 'YOUR-UUID-HERE' where user_id is null;
-- 주인이 없는 행(빈 값이었거나 옮기지 않기로 한 행)은 정리한다
delete from next_plan where user_id is null;

alter table next_plan add primary key (user_id);


-- =====================================================
-- 5단계. RLS 정책 교체 — 누구나 접근하던 정책을 지우고, 본인 소유만
-- 읽기/쓰기 가능한 정책으로 바꾼다
-- =====================================================
drop policy if exists "public_all_plans" on plans;
drop policy if exists "public_all_plan_history" on plan_history;
drop policy if exists "public_all_tasks" on tasks;
drop policy if exists "public_all_executions" on executions;
drop policy if exists "public_all_next_plan" on next_plan;

create policy "own_plans" on plans for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_plan_history" on plan_history for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_tasks" on tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_executions" on executions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_next_plan" on next_plan for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- =====================================================
-- 6단계. 계정 삭제 함수 (T07-C134) — index.html의 "계정 삭제" 버튼이
-- supabase.rpc('delete_own_account')로 이 함수를 부른다.
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


-- =====================================================
-- 다 끝난 뒤 확인할 것
--  - Table Editor에서 plans/tasks/executions/plan_history/next_plan 모두
--    user_id 컬럼이 생겼고 값이 채워져 있는지
--  - Authentication → Policies에서 각 테이블에 own_* 정책만 남았는지
--    (public_all_* 정책이 안 남아있어야 함)
-- =====================================================
