#!/bin/bash
# XcodeのないLinuxで、Apple固有のフレームワークに依存しないロジック（Domain/、Export/ と列挙型）を
# Swift Testingで検証する。Dockerの swift イメージを使う。
#   使い方: scripts/linux-check.sh
# SwiftData、SwiftUI、UIKitを import するファイルは対象外（CIのmacOSでだけ検証する）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.linux-check"
IMAGE="${SWIFT_IMAGE:-swift:6.2}"

rm -rf "$WORK"
mkdir -p "$WORK/Sources/MedakaLedger" "$WORK/Tests/MedakaLedgerTests"

is_portable() {
  ! grep -qE '^import (SwiftData|SwiftUI|UIKit|StoreKit|PhotosUI|Charts|XCTest)' "$1"
}

for file in "$ROOT"/MedakaLedger/Domain/*.swift "$ROOT"/MedakaLedger/Export/*.swift "$ROOT"/MedakaLedger/Models/Enums.swift "$ROOT"/MedakaLedger/Models/Enums+Label.swift; do
  if is_portable "$file"; then cp "$file" "$WORK/Sources/MedakaLedger/"; fi
done
for file in "$ROOT"/MedakaLedgerTests/*.swift; do
  if is_portable "$file"; then cp "$file" "$WORK/Tests/MedakaLedgerTests/"; fi
done

# Linux の Foundation には String(localized:) が無いので、文字列をそのまま返す代用を置く
cat > "$WORK/Sources/MedakaLedger/LinuxShim.swift" <<'EOF'
#if !canImport(Darwin)
import Foundation
extension String {
    init(localized value: String) { self = value }
}
#endif
EOF

cat > "$WORK/Package.swift" <<'EOF'
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MedakaLedgerLinuxCheck",
    targets: [
        .target(name: "MedakaLedger"),
        .testTarget(name: "MedakaLedgerTests", dependencies: ["MedakaLedger"]),
    ]
)
EOF

echo "sources: $(ls "$WORK/Sources/MedakaLedger" | tr '\n' ' ')"
echo "tests:   $(ls "$WORK/Tests/MedakaLedgerTests" | tr '\n' ' ')"
docker run --rm -v "$WORK":/work -w /work "$IMAGE" \
  bash -c "swift build --build-tests -Xswiftc -warnings-as-errors 2>&1 && swift test --skip-build 2>&1"
