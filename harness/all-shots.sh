#!/bin/sh
# Every target's comparison screen into $1, one build at a time.
out=$1
cp $SCRATCH/harness/ScreenshotTest.kt $PRISM/design/test/compose/src/test/kotlin/org/novasoftwarefoundation/prism/checks/
cp $SCRATCH/harness/ScreenshotTests.swift $PRISM/design/test/swiftui/Tests/PrismTests/
sh $SCRATCH/harness/web-shots.sh $out
JAVA_HOME=/opt/homebrew/opt/openjdk@17 ANDROID_HOME=$SCRATCH/tools/sdk PRISM_SHOTS=$out $SCRATCH/tools/gradle-9.9.2/bin/gradle -p $PRISM/design/test/compose --no-daemon testDebugUnitTest --tests '*ScreenshotTest*' > $out.gradle.log 2>&1 || echo gradle failed
(cd $PRISM/design/test/swiftui && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TEST_RUNNER_PRISM_SHOTS=$out xcodebuild test -scheme PrismChecks-Package -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath $SCRATCH/dd-swiftui -only-testing:PrismTests/ScreenshotTests > $out.xcode.log 2>&1) || echo xcode failed
ls $out
