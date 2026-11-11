# 아멘모아 · AmenMoa

Flutter로 만드는 아멘모아입니다. 로고 시작 화면, 이메일 가입·인증·로그인, 로그인 유지, 홈 / 그룹 / 기도 / 기록 / 프로필을 연결했습니다.

## 실행

Flutter **3.47.9 stable** / Dart **3.13.7** 기준입니다.

```bash
git clone --branch dev https://github.com/nhs0912/amenmoa_front.git
cd amenmoa_front
flutter pub get
flutter run -d chrome
```

인증 설정 없이도 화면과 기기 저장 모드를 확인할 수 있습니다. 이메일 로그인/가입 버튼은 활성화되어 있지만 실제 메일 전송과 계정 인증에는 아래 Supabase 설정이 필요합니다. 설정이 없을 때 메일을 보냈다고 표시하거나 가짜 계정으로 로그인하지 않습니다.

## 실제 이메일 인증 연결

1. Supabase 프로젝트에서 Email provider와 **Confirm email**을 켭니다. 이메일 확인을 끄면 이 앱은 가입 즉시 발급되는 세션을 거부합니다.
2. Email OTP 길이를 **6자리**로 설정합니다. Authentication의 **Confirm signup** 메일 템플릿에 `supabase/templates/confirmation.html`을 적용합니다. 템플릿은 `{{ .Token }}` 인증코드를 표시합니다. 앱은 링크 대신 이메일과 코드로 인증하므로 앱 딥링크 설정은 필요하지 않습니다.
3. 실제 사용자에게 발송하려면 Supabase의 custom SMTP와 발신 주소를 설정합니다. 기본 발송 서비스에는 수신자와 발송 횟수 제한이 있어 일반 사용자용 발송을 보장하지 않습니다.
4. `config/auth.example.json`을 `config/auth.local.json`으로 복사하고 Project URL과 **publishable key**를 입력합니다. 이전 프로젝트의 anon key는 `SUPABASE_ANON_KEY`로도 지원합니다. secret/service-role 키는 앱에서 사용하지 않습니다.

```bash
flutter run -d chrome --dart-define-from-file=config/auth.local.json

# Android 에뮬레이터 예시 (flutter devices에서 ID 확인)
flutter emulators --launch Pixel_3a_API_34
flutter run -d emulator-5554 --dart-define-from-file=config/auth.local.json

# 실제 서비스 설정을 포함한 웹 빌드
flutter build web --release --dart-define-from-file=config/auth.local.json
```

로컬 설정 파일은 Git에서 제외됩니다. SMTP 비밀번호와 Supabase secret/service-role 키는 이 파일이나 앱 코드에 넣지 않습니다. CI의 기본 빌드는 인증 서비스 설정 없이 수행합니다.

공식 설정 문서: [이메일 템플릿](https://supabase.com/docs/guides/auth/auth-email-templates), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [세션 유지](https://supabase.com/docs/guides/auth/sessions).

## 가입·로그인 흐름

- 앱을 새로 실행하면 네이티브 로고에 이어 Flutter 시작 화면을 최소 1.6초 표시합니다.
- 저장한 세션이 유효하면 홈을 엽니다. 토큰이 만료되었으면 갱신하고, 서버에서 인증된 이메일 계정인지 확인합니다.
- 비로그인이면 **아멘모아 시작하기**로 이동합니다.
- **이메일로 로그인**: 이메일과 비밀번호를 입력합니다.
- **이메일로 가입**: 이메일·비밀번호(8자 이상)·비밀번호 확인을 입력하고 인증 메일을 요청합니다.
- **이메일 인증**: 메일의 6자리 인증코드를 입력합니다. 서버 인증이 성공한 경우에만 가입 완료 상태로 홈을 열고 로그인 상태를 저장합니다.
- 틀리거나 만료된 코드는 오류를 표시하며, 60초 뒤 인증 메일을 다시 요청할 수 있습니다. 이메일 주소 수정 시 비밀번호는 다시 입력합니다.
- **프로필 → 로그아웃**: 이 기기의 저장 세션과 메모리 세션을 해제하고 아멘모아 시작하기로 돌아옵니다. 로그아웃 뒤 재실행해도 자동 로그인되지 않습니다.
- **기기 저장 모드로 둘러보기**: 계정 로그인 없이 기존 기능을 확인합니다. 프로필의 **로그인 화면으로**에서 돌아갈 수 있습니다.

비밀번호와 인증코드는 앱 저장소에 저장하지 않습니다. 네이티브에서는 Keychain/Keystore 기반 저장소에 인증 세션을 보관합니다. 웹은 HTTPS(또는 localhost)와 브라우저 보안 저장소 구현을 사용하며 네이티브 Keychain과 같은 격리는 제공하지 않습니다. 네트워크 일시 오류로 갱신에 실패해도 저장한 refresh token을 지우지 않고 재시도합니다. 로그아웃, 서버의 세션 취소, 갱신 토큰 만료 시에는 다시 로그인해야 합니다.

## 기도 기록

기도 타이머(시작·일시정지·재개·종료), 메모, 달력, 날짜별 기록, 직접 기록·삭제, 개인 목표, 기도 예약, 기도제목·그룹 생성, 프로필 이름·글씨 크기를 기기에 저장합니다. 한 기도 세션을 중복 저장해도 한 번만 합산합니다.

로그인 계정의 기도 기록·프로필은 사용자 ID별로 저장합니다. 다른 계정이나 둘러보기 모드에서 해당 기록을 표시하지 않습니다. 로그아웃해도 기록은 유지되며 같은 계정으로 재로그인하면 다시 확인할 수 있습니다. 기존 둘러보기 기록은 기존 저장 위치에 그대로 남습니다. 클라우드 기도 기록 동기화는 아직 구현하지 않았습니다.

## 남은 기능

카카오 / Google / Apple 로그인, 비밀번호 초기화, QR 초대·그룹 가입, 실제 멤버·댓글·친구 약속·톡톡, 실시간 기도방, 그룹 공동 목표 집계, 푸시·예약 자동 알림, 잠금 화면 활동과 기록 동기화는 아직 연결되지 않았습니다. 초기 그룹과 기도방은 예시입니다. 예약과 알림 선호를 저장해도 기기 알림을 발송하지 않습니다. 타이머는 종료 시 저장되며 앱 강제 종료 시 진행 중인 시간은 복구되지 않습니다.

## 플랫폼 실행

```bash
flutter doctor
flutter devices
flutter run -d <device-id> --dart-define-from-file=config/auth.local.json
```

iOS는 Xcode, Android는 Android SDK가 필요합니다. iPhone 실기기는 개발자 서명도 필요합니다. iOS 빌드 중 `resource fork, Finder information, or similar detritus not allowed`가 나오면 Documents/iCloud의 파일 속성 때문에 엔진 서명이 실패했을 수 있으므로 동기화되지 않는 개발 폴더에 새로 clone하세요.

시작 로고는 제공된 스토리보드의 원본 이미지를 사용합니다. Android 12 이상·이전 버전과 iOS LaunchScreen에 같은 로고·크림색 배경을 적용했습니다. 입력 폼은 SafeArea와 스크롤·키보드 여백을 사용합니다.

## 검사

```bash
dart format --output=none --set-exit-if-changed lib test
dart analyze lib test
flutter test
flutter build web --release
flutter build apk --debug
```

화면·입력 검증·인증 흐름은 테스트용 인증 저장소로 검증하며, 실제 메일 전송은 서비스 설정과 실제 수신 주소가 있어야 확인할 수 있습니다. 테스트는 가짜 성공을 제품에 사용하지 않습니다.
