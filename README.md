# 아멘모아 · AmenMoa

함께 기도하고 기도제목을 나누는 아멘모아의 Flutter 프런트엔드입니다.
하나의 Dart 코드로 iOS, Android, 웹을 개발합니다.

## 시작하기

- Flutter **3.47.9 stable** / Dart **3.13.7**을 기준으로 구성했습니다.
- Flutter 설치: <https://docs.flutter.dev/install>
- Android: Android Studio와 Android SDK가 필요합니다.
- iOS: macOS와 Xcode가 필요합니다. 기기 실행에는 Apple 서명 설정이 필요합니다.
- 웹: Chrome으로 실행할 수 있습니다.

```bash
git clone --branch dev https://github.com/nhs0912/amenmoa_front.git
cd amenmoa_front
flutter doctor
flutter pub get
flutter run -d chrome
```

Android 에뮬레이터나 iOS 시뮬레이터를 켠 뒤 아래 명령으로 실행합니다.

```bash
flutter devices
flutter run -d <device-id>
```

FVM을 사용하는 경우 `.fvmrc`의 버전을 설치한 뒤 `fvm flutter` 명령을 사용할 수 있습니다.
FVM 설치는 필수가 아닙니다.

초기 프로젝트는 `dev` 브랜치에서 개발합니다.

## 현재 포함된 내용

- iOS / Android / 웹 플랫폼 프로젝트
- 녹색 Material 3 테마와 한국어 기본 설정
- 홈 / 모임 / 기도제목 / 프로필 하단 탭과 빈 상태 화면
- 좁은 화면에서 스크롤 가능한 레이아웃과 웹 텍스트 선택
- 탭 이동, 모바일·태블릿 크기, 큰 글씨 화면 테스트
- GitHub Actions: 포맷 검사 → 정적 분석 → 테스트 → 웹 릴리스 빌드

로그인, 이메일 인증, 자동 로그인, QR 가입, 기도 타이머, 서버 통신과 데이터 저장은 아직 구현하지 않았습니다.
현재 탭의 내용은 기능을 추가하기 위한 시작 화면이며 실제 계정이나 기도 데이터는 생성하지 않습니다.

## 코드 구조

| 경로 | 역할 |
| --- | --- |
| `lib/main.dart` | 앱 시작점 |
| `lib/app/app.dart` | MaterialApp과 언어 설정 |
| `lib/app/app_shell.dart` | 하단 탭과 페이지 전환 |
| `lib/app/theme/` | 공통 색상과 테마 |
| `lib/features/home/presentation/` | 홈 화면 |
| `lib/features/groups/presentation/` | 모임 화면 |
| `lib/features/prayer_requests/presentation/` | 기도제목 화면 |
| `lib/features/profile/presentation/` | 프로필 화면 |
| `lib/shared/widgets/` | 공통 UI 컴포넌트 |
| `test/` | 화면과 탐색 테스트 |

기능별로 필요한 시점에 `data/`, `domain/` 등을 추가하세요.
초기 상태에서는 별도의 라우팅·상태관리·HTTP 패키지를 사용하지 않습니다.

## 검사와 빌드

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build web --release
```

```bash
# Android 개발용 APK
flutter build apk --debug

# macOS에서 iOS 시뮬레이터용 빌드
flutter build ios --simulator
```

웹 빌드 결과는 `build/web/`에 생성됩니다. 자동 배포는 설정하지 않았습니다.
iOS/Android 릴리스 전에는 앱 식별자, 개발자 계정, 서명, 앱 아이콘과 배포 설정을 확인해야 합니다.
현재 앱 식별자는 `com.amenmoa.app`이며 개발을 시작하기 위한 기본값입니다.

생성물, 로컬 SDK 경로, 인증서와 키 파일은 커밋하지 않습니다.
앱 프로젝트의 의존성 버전을 재현할 수 있도록 `pubspec.lock`은 커밋합니다.
