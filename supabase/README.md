# PDS Diary — Supabase 연동 안내

Cloudflare Workers 버전보다 훨씬 간단합니다. 터미널 명령어가 거의 없어요.

## 1. Supabase 프로젝트 만들기
1. https://supabase.com 접속 → 무료 가입
2. "New Project" 클릭 → 이름/비밀번호 아무거나 설정 (DB 비밀번호는 나중에 안 씀)
3. 리전은 가까운 곳(Northeast Asia, Seoul 등) 선택 → 생성 (1~2분 소요)

## 2. 스키마 적용
1. 왼쪽 메뉴에서 **SQL Editor** 클릭
2. **New query** 클릭
3. 이 폴더의 `schema.sql` 내용을 전부 복사해서 붙여넣기
4. 우측 하단 **Run** 클릭
5. 성공 메시지 뜨면 끝 — plans/tasks/executions/plan_history/next_plan 테이블이 다 만들어졌어요

## 3. 연결 정보 확인
1. 왼쪽 메뉴에서 **Project Settings → API Keys**
2. 이 두 값을 복사:
   - **Project URL** (예: `https://abcdefgh.supabase.co`)
   - **Publishable key** (`sb_publishable_...`로 시작. 예전엔 "anon public" 키라고 불렸어요)

> Supabase가 2026년에 키 이름을 바꿨어요. "Publishable and secret API keys" 탭에 있는 **Publishable key**를 쓰면 되고, 예전 이름인 `anon` 키와 성격·안전성이 완전히 같습니다. "Legacy anon, service_role API keys" 탭에 있는 옛날 키를 써도 아직은 동작해요.

## 4. 프론트엔드에 연결
`index.html` 맨 위쪽 `<script>` 안의 이 두 줄을 방금 복사한 값으로 바꿔주세요.

```js
const SUPABASE_URL = "https://REPLACE_WITH_YOUR_PROJECT.supabase.co";
const SUPABASE_ANON_KEY = "REPLACE_WITH_YOUR_ANON_KEY"; // 여기에 Publishable key(sb_publishable_...)를 넣으세요
```

이게 끝입니다. 별도 배포 명령어(wrangler deploy 같은 것)가 필요 없어요 —
`index.html`을 GitHub Pages 등에 올리기만 하면, 그 안의 JS가 바로 Supabase와 통신합니다.

## 참고 — Publishable(anon) key는 비밀키가 아닙니다
`Publishable key`(구 `anon` 키)는 브라우저 코드에 그대로 노출되도록 설계된 공개 키입니다.
GitHub에 그대로 커밋해도 괜찮습니다 (T06-C58과 무관) — **단, `schema.sql`대로 각 테이블에 RLS(Row Level Security)가 켜져 있을 때만** 안전합니다.
반대로 **Secret key(`sb_secret_...`, 구 service_role 키)는 절대 프론트 코드에 넣지 마세요** — RLS를 무시하고 DB 전체에 접근할 수 있는 키라, 이번 과제에서는 아예 쓸 일이 없습니다.

## 데이터 확인하는 법
Supabase 대시보드 왼쪽 메뉴 **Table Editor**에서 plans/tasks/executions 표를
스프레드시트처럼 직접 눈으로 확인할 수 있습니다. SQL을 몰라도 됩니다.

## 7번 과제(로그인) 때 참고
`schema.sql` 안의 RLS policy(`public_all_...`)를 지우고,
각 테이블에 `user_id` 컬럼을 추가한 뒤 아래처럼 바꾸면 로그인 잠금이 됩니다.

```sql
drop policy "public_all_plans" on plans;
create policy "own_plans" on plans for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

프론트에서는 `sb.auth.signUp()` / `sb.auth.signInWithPassword()`로 로그인을 붙이면 됩니다.
