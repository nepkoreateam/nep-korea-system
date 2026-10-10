# NEP Korea v51.1 문자대기 오류수정

- v51에서 message_queue 오류가 모두 “08 SQL 먼저 실행”으로만 표시되던 문제 수정
- 문자대기 저장을 upsert 대신 insert로 변경해 app_message_key 충돌/스키마캐시 문제를 피함
- 실제 발송은 하지 않고 Supabase message_queue에 queued 상태로 저장

## 적용 순서
1. 이미 08 SQL을 실행했다면 GitHub 파일만 덮어쓰기
2. 안 됐다면 08 SQL을 다시 실행
3. 접속: https://nepkoreateam.github.io/nep-korea-system/?v=51.1&fresh=1
