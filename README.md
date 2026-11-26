# Screenshots for Flux 10549420830: the same look on Android, iOS and the web

Before (`develop` at 7d4dc55) and after the PR, the same screen on each target:

| File | Target | Size |
|---|---|---|
| `android-100.png`, `android-200.png` | Compose, Robolectric with Android's native graphics (SDK 34), 393 dp wide | font size 100% and 200% |
| `ios-default.png`, `ios-ax5.png` | SwiftUI on the iPhone 17 simulator (iOS 27.0, Xcode 27.0) | Dynamic Type Large and AX5 |
| `web-100.png`, `web-200.png` | The CSS in Chrome (headless), a 393 px screen (the dashed line is its edge) | zoom 100% and 200% |

`harness/` has the code that made them, not part of the PR: `ScreenshotTest.kt` goes in
`design/test/compose/src/test/kotlin/org/novasoftwarefoundation/prism/checks/` (run with
`PRISM_SHOTS=<folder> gradle -p design/test/compose testDebugUnitTest --tests '*ScreenshotTest*'`),
`ScreenshotTests.swift` in `design/test/swiftui/Tests/PrismTests/` (run with
`TEST_RUNNER_PRISM_SHOTS=<folder> xcodebuild test … -only-testing:PrismTests/ScreenshotTests`),
and `web-shots.sh` renders `screen.html` and `screen-zoom.html`, which link the checkout's CSS
by absolute path (replace `PRISM_CHECKOUT`). `all-shots.sh` runs all three; set `PRISM` to the
checkout and `SCRATCH` to a folder with Gradle 9.9.2 and an Android SDK with the 37.1 platform.

Written by an AI agent (Claude Code · claude-opus-5-5, herdr-projects next · t-0489).
