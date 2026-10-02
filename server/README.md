# AquaConnect API

Express + Postgres backend for the AquaConnect Flutter app: institute login,
farms, memos, generated reports, share links, and a NIFS 실시간 수온 proxy
(ported from `D:\202609\index.mjs`, avoiding the NIFS API's CORS restriction
for Flutter Web).

## Railway 배포

1. Railway 프로젝트를 만들고 이 `server/` 폴더를 GitHub 저장소로 연결하거나
   Railway CLI로 배포합니다 (`railway up`, 이 폴더 기준).
2. **Postgres 플러그인을 이 서비스에 연결**합니다 — Railway가 자동으로
   `DATABASE_URL` 환경변수를 주입합니다. 직접 설정할 필요 없음.
3. 서비스 환경변수에 다음을 추가합니다:
   - `JWT_SECRET` — 임의의 긴 랜덤 문자열 (`node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`)
   - `NIFS_API_KEY` — (선택) 발급받은 키. 비워두면 `D:\202609`와 동일한 기본 데모 키로 동작.
   - `SEED_DEMO_PASSWORD` — (선택) `npm run seed`가 만드는 소유자 계정 비밀번호. 기본값 `demo1234`.
   - `SEED_ORG_NAME` / `SEED_OWNER_NAME` / `SEED_OWNER_EMAIL` / `SEED_OWNER_PHONE` — (선택) 시드할 관리원명·소유자
     이름·로그인 이메일·전화번호. 기본값 해강수산질병관리원 / 이동길 / `leedonggil@haegang.kr` / 없음.
     전화번호는 공유 리포트의 "담당 관리사에게 연락하기" 버튼이 거는 번호입니다.
   - `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT` — (선택) 휴대폰 알림(Web Push) 서명 키.
     비워두면 서버가 처음 필요할 때 키 쌍을 만들어 DB(`app_config`)에 저장하고 계속 그 키를 씁니다.
     키를 바꾸면 기존 기기 구독이 모두 무효가 되니(앱을 열면 자동 재구독) 한 번 정한 뒤엔 바꾸지 마세요.
4. 마이그레이션은 `npm start`(= `scripts/start.js`)가 서버 기동 전에
   자동으로 적용합니다 (`_migrations` 테이블로 이미 적용된 파일은 건너뜀).
   최초 1회만 Railway 콘솔의 "Run a command" (또는 `railway run`)로 시드를
   넣습니다:
   ```
   npm run seed
   ```
   시드는 관리원(organization)과 소유자 로그인 계정만 만듭니다 — 양식장·메모·
   질병정보·공유링크 같은 데모 데이터는 넣지 않습니다. 이미 같은 이메일 계정이
   있으면 아무것도 하지 않으므로 다시 실행해도 안전합니다.

   예전 시드(데모 양식장 신일수산 1양식장 등, `/r/demo` 링크)가 이미 들어간
   DB라면 한 번 정리하세요 — 정확히 그 데모 행만 지웁니다:
   ```
   npm run clear-demo            # 지울 행 수만 출력 (dry run)
   npm run clear-demo -- --yes   # 실제 삭제
   ```
5. Flutter 쪽에서 이 서비스의 공개 URL을 가리키도록 빌드/실행합니다:
   ```
   flutter run -d chrome --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://<railway-service>.up.railway.app
   ```

## 로컬 개발

```
cp .env.example .env   # DATABASE_URL을 로컬 Postgres로 지정
npm install
npm run migrate
npm run seed
npm run dev             # http://localhost:8080
```

Postgres가 로컬에 없다면 `npm run smoke-test`로 (pg-mem 기반 인메모리
에뮬레이터에 대해) 마이그레이션 SQL과 주요 쿼리 모양이 유효한지만 빠르게
확인할 수 있습니다 — 실제 Postgres를 대체하진 않으니, 실서비스 전에는
`npm run migrate && npm run seed`를 진짜 Postgres에 대해 꼭 한 번 실행해
보세요.

## API 개요

모든 `/api/*` 라우트(로그인 제외)는 `Authorization: Bearer <token>` 필요.
`/api/public/*`와 `/api/ocean/*`는 인증 불필요(공유링크로 받은 양식장주,
그리고 헬스체크용).

| Method | Path | 설명 |
|---|---|---|
| POST | `/api/auth/login` | 이메일/비밀번호 로그인 → JWT |
| GET | `/api/auth/me` | 현재 세션 복원 |
| GET | `/api/farms`, `/api/farms/:id` | 담당 양식장 목록/상세 |
| POST | `/api/farms` | 양식장 등록 (양식장명/위치/전화번호 필수) |
| PUT | `/api/farms/:id` | 양식장 정보 수정 |
| DELETE | `/api/farms/:id` | 양식장 삭제 |
| GET/POST | `/api/memos` | 메모 조회(`?farmId=`)/작성 |
| GET | `/api/disease-info` | 수산질병 정보 |
| GET | `/api/reports/:farmId` | 최신 리포트(없으면 즉시 생성) |
| GET | `/api/reports?farmIds=a,b` | 여러 양식장 최신 리포트 일괄 조회 |
| POST | `/api/reports/:farmId/generate` | 리포트 새로 생성 |
| POST/GET | `/api/share-links` | 공유링크 발급/목록 |
| GET | `/api/public/reports/:token` | **공개** — 공유링크로 리포트 조회 |
| GET | `/api/ocean/realtime?station=` | **공개** — NIFS 실시간 수온 프록시 |

## 알아둘 점

- "AI 정리 소견"은 `src/lib/reportGenerator.js`의 규칙 기반 로직이며 실제
  LLM 호출이 아닙니다 (Flutter 쪽 `report_generator.dart`와 동일한 로직을
  유지하려고 노력했지만, 백엔드가 붙은 뒤로는 이 파일이 정본입니다).
- NIFS `risaList` API는 실시간 수온만 제공하고 7일 이력/염도/용존산소/적조는
  주지 않습니다 — `oceanSnapshotForFarm()`은 그 사실을 숨기지 않고 그대로
  단일 값만 리포트 생성에 반영합니다.

## 알림 (Web Push)

- 알림이 생기는 경우: 양식장 위험도가 올라갈 때(양호→주의/위험, 주의→위험 — 조직 전체), 다른 구성원이
  메모를 남길 때(작성자 제외). 각 구성원이 마이페이지 > 알림 설정에서 종류별로 끌 수 있고, 끈 종류는 알림함에도 쌓이지 않습니다.
- `GET /api/notifications` 알림함, `POST /api/notifications/:id/read`, `POST /api/notifications/read-all`,
  `GET|PUT /api/notifications/settings`, `GET /api/notifications/push/public-key`,
  `POST|DELETE /api/notifications/push/subscriptions`, `POST /api/notifications/test`.
- 기기 쪽은 `web/push_sw.js` 서비스워커가 받습니다. 안드로이드 Chrome·PC 브라우저는 바로 되고,
  아이폰(iOS 16.4+)은 Safari에서 "홈 화면에 추가"로 설치한 앱에서만 알림을 켤 수 있습니다.

## 어가 문의 (공유 리포트)

- `POST /api/public/reports/:token/inquiries` (**공개**, 로그인 불필요) — body `{ "message": "..." }`, 500자 이내,
  링크당 1시간 10건까지(초과 시 429). 만료·회수된 링크는 404.
- 접수되면 `inquiries`에 저장되고, 메모 목록에 `어가 · <양식장명>` 작성자·`문의` 태그로 남으며, 관리원 전원에게
  `inquiry` 알림(휴대폰 푸시 포함)이 갑니다. 문의 알림은 알림 설정과 관계없이 항상 갑니다.
- 공유 리포트의 "전화 걸기"는 양식장 담당 구성원의 `members.phone`으로 겁니다 (`SEED_OWNER_PHONE` 참고).
