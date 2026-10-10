# NEP Korea v51 문자 발송대기 DB 연결

## 1. Supabase SQL 실행
`08_NEP_Supabase_문자발송대기DB_v51.sql` 전체를 SQL Editor에서 실행하세요.

성공 문구:

`v51 message queue DB ready`

## 2. GitHub 업로드
압축을 풀어 기존 GitHub Pages 파일에 덮어쓰기 후 Commit changes.

접속 주소:

`https://nepkoreateam.github.io/nep-korea-system/?v=51&fresh=1`

## 3. 테스트 순서
관리자 로그인 → 월말 관리대장 → 수거DB 새로고침 → 관리대장 DB 저장 → 고객발송 → 전체 문자대기 저장.

v51에서는 실제 문자가 바로 발송되지 않습니다. Supabase `message_queue`에 `queued` 상태로 쌓이고, 추후 메인 PC의 KT SmartMessage 연동 프로그램이 이 목록을 읽어 발송하는 구조입니다.
