# 아멘모아 · AmenMoa

스토리보드의 포레스트 그린·크림색 디자인과 홈 / 그룹 / 기도 / 기록 / 프로필을 구현한 Flutter 앱입니다.

## 실행

Flutter **3.47.9 stable** / Dart **3.13.7** 기준입니다. 프로젝트 루트에서 실행하세요.

```bash
git clone --branch dev https://github.com/nhs0912/amenmoa_front.git
cd amenmoa_front
flutter pub get
flutter run -d chrome
```

기기 실행은 Android 에뮬레이터 또는 iOS 시뮬레이터를 켠 뒤 진행합니다.

```bash
flutter doctor
flutter devices
flutter run -d <device-id>
```

iOS 빌드 중 `resource fork, Finder information, or similar detritus not allowed`가 나오면 Documents/iCloud 폴더의 파일 속성 때문에 Flutter 엔진 서명이 실패한 경우입니다. 동기화되지 않는 로컬 개발 폴더(예: `~/Developer/amenmoa_front`)에 새로 clone해서 실행하세요. 이 작업에서는 파일 속성 없는 `/private/tmp/amenmoa-native-verify` 복사본으로 iOS를 검증합니다.

iOS에는 Xcode, Android에는 Android SDK가 필요합니다. iPhone 실기기는 개발자 서명 설정도 필요합니다.

## 시작과 로그인 화면

앱을 완전히 새로 실행하면 네이티브 시작 로고 다음에 Flutter 로고 시작 화면을 최소 1.6초 표시합니다. 이 동안 `SessionRepository.restoreSession()`으로 세션을 복원합니다.

- 유효한 인증 세션: 홈으로 이동
- 비로그인 또는 만료된 세션: 로그인 화면으로 이동
- 세션 복원 실패/10초 시간 초과: 로그인 화면에서 다시 확인 가능
- `기기 저장 모드로 둘러보기`: 이번 실행에서만 홈을 열며 로그인 상태를 만들지 않음
- 프로필의 `로그인 화면으로`: 기기 데이터를 보존하고 로그인 화면으로 복귀

현재 인증 서비스는 미연결이라 기본 `UnconfiguredSessionRepository`는 비로그인 상태를 반환합니다. 소셜/이메일 로그인 버튼도 준비 중으로 비활성화되어 있습니다. 서비스 연결 시 서버에서 검증한 세션을 반환하는 `SessionRepository` 구현을 앱에 주입해야 합니다. SharedPreferences의 기도 기록이나 임의 boolean을 로그인으로 취급하지 않습니다.

시작 화면/홈 상단 로고는 제공된 스토리보드에서 추출한 원본 이미지를 사용합니다. Android 12 이상 시스템 스플래시, 이전 Android 시작 화면, iOS LaunchScreen에도 같은 로고와 크림색 배경을 적용했습니다.

## 현재 동작

- 홈에서 오늘 기도 시간과 매일 60분 목표 확인
- 5개 하단 메뉴와 상세 화면 탐색
- 그룹 생성, 그룹별 화면, 기도제목 추가와 선택
- 기도 타이머 시작 / 일시정지 / 재개 / 마치기 / 메모
- 타이머가 화면 갱신 횟수 대신 Stopwatch의 실제 경과 시간을 측정
- 한 세션을 중복 저장해도 누적 시간에 한 번만 반영
- 기도 기록 달력, 날짜 선택, 이전/다음 달, 직접 기록과 삭제
- 이번 주 개인 기록을 집계하는 목표 화면
- 미래 날짜·시간의 기도 예약을 기기에 저장
- 프로필 이름·글씨 크기·알림 수신 선호 저장
- SharedPreferences를 통한 기도 기록·기도제목·그룹·프로필·예약 복원
- SafeArea, 스크롤 가능한 폼, 작은 화면과 큰 글씨 지원

## 서버 연동 범위

현재는 **기기 저장 모드**입니다. 초기 그룹과 기도제목은 예시이며, 라이브 기도방은 미리보기입니다. 서버 수치나 다른 사용자의 활동을 실제 데이터로 표시하지 않습니다.

다음 기능은 서버 및 서비스 설정이 필요하며 아직 구현되지 않았습니다.

- 카카오 / Google / Apple / 이메일 가입·인증·로그인·세션과 비밀번호 재설정
- QR 초대·딥링크·그룹 가입 및 멤버 권한
- 실시간 참여자·공동 기도방·친구 약속과 톡톡
- 그룹 목표·목표기도방 공동 집계
- 푸시 알림·예약 자동 알림·백그라운드 종료 알림
- 서버 동기화, 사진 업로드, 댓글, 기도제목별 개별 타이머
- 잠금 화면 Live Activities / Android 진행 알림

예약과 알림 선호를 저장해도 기기 알림을 발송하지 않습니다. 타이머는 종료 시 저장되며 앱 강제 종료 시 진행 중인 시간은 복구되지 않습니다. 앱 데이터 삭제 시 기기 기록도 삭제됩니다.

## 검사

```bash
dart format --output=none --set-exit-if-changed lib test
dart analyze lib test
flutter test
flutter build web --release
```

테스트는 로고 시작 화면에서 비로그인/유효/만료/복원 오류 상태별 이동, 기기 저장 모드의 비영속성, 작은 화면·1.6배 글씨, 5개 메뉴 이동, 기도 기록 복원과 중복 방지, 타이머 일시정지·재개·저장을 검증합니다.

`lib/features/experience/experience.dart`에 현재 기기 저장 모델과 연결된 화면이 있습니다. `lib/app/app_shell.dart`가 5개 탭을 구성하고 `lib/app/theme/app_theme.dart`가 공통 테마를 정의합니다.
