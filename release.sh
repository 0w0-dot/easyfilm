#!/bin/zsh
# 새 버전을 낸다: 배포 파일을 만들어 GitHub 릴리스에 올리고, Homebrew 설치 정보를 고친다.
# 사용: ./release.sh
# 먼저 Resources/Info.plist와 Resources/Helper-Info.plist의 버전을 올리고 커밋해 둔다.
set -euo pipefail
cd "${0:A:h}"

REPO="0w0-dot/easyfilm"
TAP_DIR="../홈브류-탭"
CASK="$TAP_DIR/Casks/easyfilm.rb"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
HELPER_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Helper-Info.plist)
TAG="v$VERSION"
ZIP="dist/Easyfilm-$VERSION.zip"

[[ "$VERSION" == "$HELPER_VERSION" ]] || { echo "본 앱($VERSION)과 도우미($HELPER_VERSION)의 버전이 다릅니다."; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "커밋하지 않은 변경이 있습니다. 먼저 커밋하세요."; exit 1; }
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "$TAG 는 이미 있습니다. 버전을 올리세요."
  exit 1
fi
python3 -I tools/check_localization.py

./build.sh --package
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

git tag "$TAG"
git push origin HEAD "$TAG"
gh release create "$TAG" "$ZIP" --repo "$REPO" --title "Easyfilm $VERSION" \
  --notes "brew install --cask 0w0-dot/tap/easyfilm"

# Homebrew 설치 정보의 버전과 파일 확인값을 새 것으로 바꾼다.
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
git -C "$TAP_DIR" commit -am "easyfilm $VERSION"
git -C "$TAP_DIR" push

rm -rf dist
echo "배포 완료: $TAG"
