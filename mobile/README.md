# NEP KOREA 휴대폰 설치형 앱 v1.0.0

운영 앱 주소: https://nepkoreateam.github.io/nep-korea-system/
패키지/번들 ID: kr.co.nepkorea.mobile

## 운영 방식
Android 및 iOS의 설치형 WebView 클라이언트가 기존 운영 웹앱을 HTTPS로 엽니다. 업체·수거·정산·경영현황·고객발송은 기존 웹앱/DB를 사용합니다. UI와 일반 기능 업데이트는 운영 main 브랜치의 GitHub Pages 배포를 따라갑니다. 네이티브 권한, 앱 아이콘 등 껍데기의 변경만 APK/IPA 재빌드가 필요합니다.

- 앱 진입 주소와 외부 링크를 분리하고 HTTPS 연결만 허용합니다.
- 인터넷 연결이 필요합니다. 백그라운드 GPS와 오프라인 수거 저장은 포함하지 않습니다.
- 카메라, 사진, GPS, 파일 다운로드 및 기사 현장 사용은 실제 기기로 별도 확인해야 합니다.
- KT MMS는 기존 메인 PC의 릴레이를 사용합니다. 휴대폰이 직접 KT 발송 프로그램을 실행하지 않습니다.
- 운영 Supabase 데이터와 main 브랜치 웹앱은 이번 작업에서 변경하지 않았습니다.

## Android
- Android 8.0(API 26) 이상, target 35.
- 무료 공개 저장소 GitHub Actions로 SDK 빌드, 서명/검증을 수행합니다.
- `bash mobile/android/build.sh` (Android SDK 35, build-tools 35.0.0, JDK 설치 필요).
- CI의 Pilot APK는 매 빌드마다 바뀌는 임시 테스트 서명입니다. 대표자용 정식 배포 APK는 별도로 생성한 영구 서명키로 서명한 버전을 사용합니다. 서로 서명키가 다르므로 Pilot APK와 정식 APK를 혼용하지 않습니다.
- 정식 재빌드 시 환경 변수 NEP_KEYSTORE, NEP_KEY_ALIAS, NEP_KEYSTORE_PASSWORD, NEP_KEY_PASSWORD를 사용합니다. 영구 서명키는 공개 저장소나 CI 아티팩트에 넣지 않습니다.
- 최종 배포 APK 인증서 SHA-256: 49dea9bf157b754a32050da0787e2f5c901216aff249dbf4162bb3a8ecf0342a
- v1.0.0 배포 APK SHA-256: f25dcea02c27b83538375bdf5c071f2093bc8cf6617bef80b09b59d7aa6d5786
- 새 버전의 덮어쓰기 설치에는 동일 패키지명/서명키와 더 높은 versionCode가 필요합니다.

## iOS
- iOS 16 이상, Swift/UIKit, WKWebView, Xcode 프로젝트 포함.
- `bash mobile/ios/prepare.sh` 실행으로 기존 NEP 로고를 Xcode 아이콘으로 준비.
- `open mobile/ios/NEPKorea.xcodeproj` 및 Xcode Signing & Capabilities에서 소유자 Team을 선택.
- 무료 Apple 계정의 Personal Team은 제한된 본인 기기 테스트(7일 만료) 용도입니다. 직원용 지속 배포는 Apple Developer Program, 서명 및 TestFlight/App Store 등 적절한 배포 절차가 필요합니다.
- 시뮬레이터 빌드는 기기 설치 가능한 IPA가 아닙니다.
- 무료 실사용 대안은 기존 웹앱을 Safari 홈 화면에 추가하는 것입니다.

## 최초 현장 검증
1. Android 기기 한 대에 대표자용 APK 설치 후 기존 관리자 계정으로 로그인.
2. 기사 계정 로그인, 코스 및 GPS 허용/거부 동작 확인.
3. 테스트용 업체만 대상으로 수거 저장 및 PC에서 재조회.
4. 파일 내보내기 및 앱 종료/재실행 확인.
5. KT MMS는 기존 릴레이의 테스트 모드에서만 확인.
