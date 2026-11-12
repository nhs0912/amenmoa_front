# 아멘모아 · AmenMoa

Flutter로 만드는 아멘모아입니다. 로고 시작 화면, 이메일 가입·인증·로그인, 로그인 유지, 홈 / 그룹 / 기도 / 기록 / 프로필을 연결했습니다.

## 실행

Flutter **3.47.9 stable** / Dart **3.13.7** 기준입니다.

```bash
git clone --branch dev https://github.com/nhs0912/amenmoa_front.git
cd amenmoa_front
flutter pub get
flutter run -d chrome --web-port 3000
```

기본 실행은 `moa` 조직의 아멘모아 개발용 Supabase 프로젝트에 연결됩니다. 연결에 사용하는 URL과 publishable key는 공개 클라이언트 설정입니다. secret/service-role 키나 SMTP 비밀번호는 앱에 포함하지 않습니다.

## 이메일 인증 설정

현재 개발 프로젝트에는 Email provider와 **Confirm email**이 켜져 있습니다. 가입 메일은 Supabase의 기본 **인증 링크**를 사용합니다.

- 가입 폼 → 인증 메일 요청 → 메일의 `Confirm email address` 링크 클릭 → 원래 앱의 **인증했어요 · 계속하기** → 서버 확인 후 가입 완료·로그인
- 확인 전 버튼을 눌러도 서버에서 미인증 상태면 홈으로 이동하지 않습니다.
- 가입 때 입력한 비밀번호는 인증 대기 화면의 메모리에만 잠시 유지하며 파일·환경설정·인증 저장소에 저장하지 않습니다. 앱을 종료했다면 이메일 인증 뒤 이메일 로그인으로 이어가면 됩니다.
- 기본 메일 발송은 Supabase가 허용한 프로젝트 팀원의 이메일로 제한됩니다. 처음 테스트할 때는 Supabase 계정에 사용한 이메일을 이용하세요. 일반 사용자를 위한 발송에는 custom SMTP 설정이 필요합니다.
- 무료 프로젝트에서 custom SMTP 없이 메일 템플릿을 편집할 수 없으므로 코드 대신 기본 인증 링크를 사용합니다. SMTP를 연결하면 `supabase/templates/confirmation.html`을 적용하고 아래 code 모드를 사용할 수 있습니다.
- 서버의 Email OTP length는 **8자리**입니다. 보안 정책을 낮추지 않고 코드 모드 입력도 8자리로 맞췄습니다.

현재 Site URL은 기본값 `http://localhost:3000`입니다. 메일에서 링크를 누른 뒤 개발 PC의 웹 앱으로 이동시키려면 아래 명령으로 웹 앱을 같은 포트에서 실행하세요. Android/iOS에서 가입했다면 메일 확인 후 원래 앱으로 돌아와 인증 확인 버튼을 누르면 됩니다. 실제 배포 전 Site URL을 운영 서비스 주소로 변경해야 합니다.

```bash
flutter run -d chrome --web-port 3000
flutter run -d emulator-5554
```

다른 Supabase 프로젝트를 쓰거나 메일 템플릿 방식을 바꿀 때만 `config/auth.example.json`을 `config/auth.local.json`으로 복사해 공개 설정을 변경합니다. `EMAIL_VERIFICATION_METHOD`는 기본 `link`이며 custom SMTP와 코드 메일 템플릿을 설정한 경우 `code`로 지정합니다. 이전 프로젝트의 anon key는 `SUPABASE_ANON_KEY`로도 지원합니다.

```bash
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/auth.local.json
flutter build web --release --dart-define-from-file=config/auth.local.json
```

로컬 설정 파일은 Git에서 제외됩니다. SMTP 비밀번호와 Supabase secret/service-role 키는 이 파일이나 앱 코드에 넣지 않습니다.

공식 설정 문서: [이메일 템플릿](https://supabase.com/docs/guides/auth/auth-email-templates), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [세션 유지](https://supabase.com/docs/guides/auth/sessions).

## 가입·로그인 흐름

- 앱을 새로 실행하면 네이티브 로고에 이어 Flutter 시작 화면을 최소 1.6초 표시합니다.
- 저장한 세션이 유효하면 홈을 엽니다. 토큰이 만료되었으면 갱신하고, 서버에서 인증된 이메일 계정인지 확인합니다.
- 비로그인이면 **아멘모아 시작하기**로 이동합니다.
- **이메일로 로그인**: 이메일과 비밀번호를 입력합니다.
- **이메일로 가입**: 이메일·비밀번호(8자 이상)·비밀번호 확인을 입력하고 인증 메일을 요청합니다.
- **이메일 인증**: 기본 링크 모드에서는 메일의 인증 링크를 누른 뒤 앱에서 확인합니다. 코드 모드에서는 8자리 인증코드를 입력합니다. 서버 인증이 성공한 경우에만 홈을 열고 로그인 상태를 저장합니다.
- 미인증 계정이나 틀리거나 만료된 코드는 오류를 표시하며, 60초 뒤 인증 메일을 다시 요청할 수 있습니다. 이메일 주소 수정 시 비밀번호는 다시 입력합니다.
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

화면·입력 검증·인증 흐름은 테스트용 인증 저장소로 검증하며, 실제 메일 수신·링크 인증의 최종 확인에는 사용자의 실제 가입과 메일 확인이 필요합니다. 테스트는 가짜 성공을 제품에 사용하지 않습니다.
