# Easyfilm

넣어 둔 이미지를 누르면 바로 바탕화면이 바뀌는 맥 앱.

[English](#english) · [日本語](#日本語)

## 설치

```
brew install --cask 0w0-dot/tap/easyfilm
```

macOS 14 이상. Apple Silicon 맥과 인텔 맥 모두 됩니다.

## 처음 한 번

- Easyfilm을 열면 메뉴 막대에 필름 통 아이콘이 생깁니다.
- "손쉬운 사용" 권한을 묻는 창이 뜨면 **시스템 설정 열기**를 누르고, 열린 목록에서 **Easyfilm Helper**를 켜 주세요. Dock 클릭으로 최소화에 필요합니다.
- 그 창을 놓쳤다면 메뉴 막대 아이콘에서 "Dock 클릭으로 최소화"를 누르면 설정 화면이 열립니다.

## 기능

- 창에 이미지를 끌어다 놓고, 누르면 바로 바탕화면이 바뀝니다.
- 꽉 채우기, 또는 원본 비율 유지(남는 부분은 검정이나 흰색).
- 이름 옆 연필을 누르면 그 자리에서 이름을 고칩니다.
- 메뉴 막대 아이콘에서 배경화면 폴더를 바꾸고, Dock 클릭으로 최소화를 켜고 끕니다.
- Dock 클릭으로 최소화: 이미 앞에 있는 앱의 Dock 아이콘을 다시 누르면 그 앱의 창이 Dock으로 내려갑니다.
- 한국어, 영어, 일본어.

## 지우기

```
brew uninstall --cask easyfilm
```

설정까지 지우려면 `brew uninstall --zap --cask easyfilm`. 넣어 둔 이미지는 지우지 않습니다.

## 알아 두기

애플 공증을 받지 않은 앱이라, Homebrew로 설치할 때 macOS의 첫 실행 확인을 건너뛰게 되어 있습니다. 믿을 수 있는 사람에게 받은 경우에만 설치하세요.

응원은 메뉴 막대의 "초콜릿 하나 사주기"나 [Ko-fi](https://ko-fi.com/iwanthappyworld)에서.

---

## English

A Mac app that sets your wallpaper the moment you click an image you've added.

```
brew install --cask 0w0-dot/tap/easyfilm
```

Requires macOS 14 or later, on Apple silicon or Intel.

- When the Accessibility prompt appears, click **Open System Settings** and turn on **Easyfilm Helper** in the list. "Minimize on Dock Click" needs it. If you missed it, choose "Minimize on Dock Click" from the menu bar icon to open the setting.
- Drop images into the window and click one to set it as your wallpaper.
- Choose Fill Screen or Fit to Screen, with black or white margins.
- Click the pencil next to a name to rename it.
- From the film icon in the menu bar, change the wallpaper folder or turn "Minimize on Dock Click" on or off.
- Minimize on Dock Click: click the Dock icon of the app you're already using, and its windows go down to the Dock.

Remove with `brew uninstall --cask easyfilm`. Add `--zap` to remove settings too. Your images stay.

This app isn't notarized by Apple. The Homebrew install skips the macOS first-launch check, so install it only if you trust where you got it.

## 日本語

追加した画像をクリックすると、すぐに壁紙が変わるMacアプリです。

```
brew install --cask 0w0-dot/tap/easyfilm
```

macOS 14以降。Apple シリコンとIntelのMacに対応しています。

- アクセシビリティの許可を求める画面が出たら、**「システム設定を開く」**をクリックし、表示されたリストで **Easyfilm Helper** をオンにしてください。「Dockクリックでしまう」に必要です。見逃した場合は、メニューバーアイコンの「Dockクリックでしまう」を選ぶと設定画面が開きます。
- ウインドウに画像をドロップし、クリックすると壁紙になります。
- 「画面全体に表示」か「画面サイズに合わせる」（余白は黒か白）を選べます。
- 名前の横の鉛筆をクリックすると、その場で名前を変更できます。
- メニューバーのフィルムアイコンから、壁紙フォルダの変更や「Dockクリックでしまう」のオン／オフができます。
- Dockクリックでしまう：使用中のアプリのDockアイコンをもう一度クリックすると、そのアプリのウインドウがDockにしまわれます。

削除は `brew uninstall --cask easyfilm`。設定も消すには `--zap` を付けます。画像は消えません。

このアプリはAppleの公証を受けていません。Homebrewでのインストール時にmacOSの初回起動チェックを省略するため、信頼できる相手から受け取った場合だけインストールしてください。

---

## 개발

### 빌드

```
./build.sh            # 빌드해서 /Applications 에 설치하고 실행
./build.sh --package  # 배포용 dist/Easyfilm-<버전>.zip 만들기
```

Xcode 없이 Command Line Tools만 있으면 됩니다. 인텔과 Apple Silicon 겸용으로 빌드합니다.

로그인 키체인의 `0w0-dot Code Signing` 인증서로 서명합니다. 그래서 새 버전을 깔아도 손쉬운 사용 권한이 유지됩니다. 인증서가 없으면 임시 서명으로 빌드되고, 그때는 빌드할 때마다 권한을 다시 켜야 합니다.

### 새 버전 내기

1. `Resources/Info.plist`와 `Resources/Helper-Info.plist`의 `CFBundleShortVersionString`을 올립니다.
2. 바뀐 내용을 커밋합니다.
3. `./release.sh`를 실행합니다. GitHub 릴리스를 만들고 Homebrew 설치 정보(`0w0-dot/homebrew-tap`)까지 고칩니다.

### 번역

화면 글의 키는 코드에 쓴 한국어 문장입니다. 번역은 `Resources/en.lproj`, `Resources/ja.lproj`의 `Localizable.strings`에 있습니다. 글을 더하거나 고친 뒤 `python3 -I tools/check_localization.py`로 빠진 번역이 없는지 확인합니다.

### 구조

- `Sources/App/` 본 앱: 이미지 목록 창(SwiftUI), 메뉴, 도우미 등록
- `Sources/Helper/` 도우미(Easyfilm Helper): 메뉴 막대 아이콘과 메뉴, 초콜릿 창, Dock 클릭으로 최소화
- `Sources/Shared/` 둘이 함께 쓰는 설정과 번역 함수
- `Resources/` Info.plist, 앱 아이콘, 번역 파일
- `tools/` 아이콘 그리기(`make_icon.swift`), 번역 확인(`check_localization.py`)

도우미는 앱 안의 `Contents/Helpers/Easyfilm Helper.app`에 있습니다. Easyfilm을 한 번 열면 `~/Library/LaunchAgents/io.github.0w0-dot.easyfilm.helper.plist`로 등록됩니다. 그 뒤로는 맥을 켤 때마다 시작되고, 비정상으로 꺼지면 다시 켜집니다. 메뉴의 "종료"로 끄면 다음에 Easyfilm을 열거나 맥을 켤 때까지 꺼져 있습니다. Easyfilm은 열릴 때 도우미가 새 버전인지 보고, 새 버전일 때만 도우미를 다시 띄웁니다.

공용 설정(배경화면 폴더)은 본 앱 설정 영역(`io.github.0w0-dot.easyfilm`)에 둡니다. Dock 기능 켜짐 여부는 도우미 설정 영역(`io.github.0w0-dot.easyfilm.helper`)에 둡니다.
