# NEP Korea v49 — 기사 마감기능 DB 연결

추가된 직접 DB 연결:
- 주유 입력/수정/삭제 → `fuel_logs`
- 공장 총중량/공차중량/실중량 → `factory_weigh_logs`
- 수거 수정/미입력 되돌리기 → `pickup_records` + `route_stops`

## 설치
1. Supabase SQL Editor에서 `06_NEP_Supabase_기사마감DB_v49.sql` 전체 실행
2. 결과가 `v49 driver close DB ready`인지 확인
3. 이 폴더의 파일을 GitHub Pages 저장소에 덮어쓰기
4. `?v=49&fresh=1`로 접속

주의: v49는 현재 소규모 운영 테스트 단계라 기사 로그인 사용자의 DB 정책을 넓게 허용합니다. 운영 안정화 단계에서 기사 본인 데이터만 접근하도록 RLS를 다시 좁혀야 합니다.
