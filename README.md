# NEP Korea v47 오늘배정 RoutesDB

## 이번 버전

v46에서 업체관리(customers) 저장이 성공한 다음 단계입니다.

v47은 오늘배정 화면의 코스를 Supabase의 `routes`, `route_stops` 테이블에 직접 저장합니다.

## 먼저 Supabase에서 실행

SQL Editor에서 아래 파일 내용을 실행하세요.

- `04_NEP_Supabase_RoutesDB_v47.sql`

성공 문구:

```text
v47 routes direct ready
```

## GitHub 업로드

압축을 풀고 전체 파일을 GitHub 저장소에 업로드하세요.

접속 주소:

```text
https://nepkoreateam.github.io/nep-korea-system/?v=47&fresh=1
```

## 테스트 순서

1. 관리자 로그인
2. 오늘배정 화면 이동
3. 업체관리 기준 자동생성 클릭
4. 코스DB 동기화 클릭
5. 새로고침
6. 코스DB 불러오기 클릭
7. 오늘배정이 다시 뜨면 성공

## 의미

- v45: 로그인 + 앱 전체 저장
- v46: 업체관리 customers 직접 저장
- v47: 오늘배정 routes / route_stops 직접 저장
