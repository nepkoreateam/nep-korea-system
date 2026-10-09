# NEP Korea v48.2 로그인 완전 수정본

- 로그인 화면에 v48.2 표시가 보입니다.
- 빈칸으로 로그인 버튼을 누르면 “아이디와 비밀번호를 입력하세요.” 문구가 떠야 합니다.
- 기사 계정 driver1 / driver2 로그인 버튼 이벤트를 강제로 다시 연결했습니다.
- service-worker 캐시를 삭제하고 네트워크 우선으로 동작하도록 수정했습니다.

접속: https://nepkoreateam.github.io/nep-korea-system/?v=48.2&fresh=100
# NEP Korea v48.1 기사 로그인 버튼 수정본

수정 내용:
- 기사 로그인 버튼을 별도 이벤트로 안전하게 연결
- driver1 / driver2 / 이메일 로그인 모두 지원
- 로그인 버튼 클릭 시 상태 문구 표시
- 서비스워커 캐시 갱신용 service-worker.js 포함

업로드 후 접속:
https://nepkoreateam.github.io/nep-korea-system/?v=48.1&fresh=1

기사 로그인:
- driver1 / 기사 비밀번호
- driver2 / 기사 비밀번호
- 또는 driver1@nepkorea.local / driver2@nepkorea.local
