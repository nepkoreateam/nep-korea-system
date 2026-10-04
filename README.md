# NEP Korea v46 업체관리 CustomersDB

v46은 v45의 Supabase 로그인/AppState 저장을 유지하면서, 업체관리 데이터를 Supabase `customers` 테이블에도 직접 저장합니다.

## 먼저 실행할 SQL
Supabase SQL Editor에서 아래 파일 내용을 실행하세요.

- `03_NEP_Supabase_CustomersDB_v46.sql`

성공하면 결과에 아래 문구가 나옵니다.

```text
v46 customers direct ready
```

## GitHub 업로드
이 폴더의 파일을 GitHub Pages 저장소에 업로드하세요.
기존 `index.html`은 덮어쓰기 합니다.

접속:

```text
https://nepkoreateam.github.io/nep-korea-system/?v=46&fresh=1
```

## 첫 사용
1. 관리자 로그인
2. 업체관리 화면 이동
3. `업체DB 동기화` 버튼 클릭
4. 새로고침 후 업체목록이 정상 유지되는지 확인

주의: 아직 기사/고객 개별 로그인은 다음 단계에서 직접 테이블 방식으로 분리합니다.


---

# NEP Korea 수거관리 v44 최종 깔끔 업로드용

GitHub Pages 테스트/설치용 정적 앱입니다.

로그인:
- 관리자: admin / 1111
- 기사: driver1 / 1111, driver2 / 1111
- 고객: cust1 / 1111, cust2 / 1111

이번 최종 정리:
- v44 동선관리 적용
- 코스 지도 상단 배치
- 지도 위 하단 정보박스 겹침 제거
- 현재지점/시간/정차시간/지도상태 박스는 지도 아래로 분리
- 기사별 회사 경고함
- API 키 없이도 루트 지도 표시
- 네이버지도는 현재 지점 외부 열기 가능
- 네이버지도 API 키 입력 시 실제 지도 모드 전환 가능
- GitHub Pages용 필수 파일만 포함

업로드:
1. 이 ZIP을 압축 해제합니다.
2. 폴더 안의 파일/폴더를 GitHub 저장소 맨 바깥에 업로드합니다.
3. Commit changes 합니다.
4. 접속 주소:
   https://nepkoreateam.github.io/nep-korea-system/?v=44&fresh=1

주의:
- 이 버전은 테스트용 정적 앱입니다.
- 실제 고객정보, 연락처, 미납정보, 문서파일은 Public GitHub에 올리면 안 됩니다.
- 실제 기사 GPS 자동수집과 여러 기기 실시간 공유는 서버/DB 연결 버전에서 구현해야 합니다.
