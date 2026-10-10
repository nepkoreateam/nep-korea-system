# NEP Korea v50 — 월말 관리대장 DB 연결

추가된 기능
- 월 선택 시 `pickup_records`의 실제 `completed` 수거기록을 불러옴
- 브라우저 샘플 수거내역 대신 실제 DB 수거내역으로 관리대장 표시
- `관리대장 DB 저장` 버튼으로 업체별 월 합계/수거건수/관리대장 문구를 `monthly_ledgers`에 저장
- 같은 업체/연월은 다시 저장하면 갱신(upsert)

설치
1. Supabase SQL Editor에서 `07_NEP_Supabase_월말관리대장DB_v50.sql` 실행
2. `v50 monthly ledger DB ready` 확인
3. 이 폴더 파일을 GitHub Pages 저장소에 덮어쓰기
4. `?v=50&fresh=1` 접속
5. 관리자 > 월말 관리대장 > 2026-07 선택 > 수거DB 새로고침 > 관리대장 DB 저장

주의
- v50부터 월말 관리대장 화면은 실제 `pickup_records`에 저장된 완료기록만 표시합니다.
- 과거 샘플 데이터가 DB에 저장되어 있지 않다면 화면에서 사라지는 것이 정상입니다.
- 고객 공개는 아직 기본 `false`입니다. 고객 계정 단계에서 공개 기능을 연결합니다.
