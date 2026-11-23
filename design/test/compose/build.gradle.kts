// The toolchain is the library's (Prism.Generator.Kotlin.versions/0).
plugins {
    id("com.android.library") version "9.5.2"
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.21"
}

android {
    namespace = "org.novasoftwarefoundation.prism.checks"
    compileSdk {
        version = release(37) { minorApiLevel = 1 }
    }
    defaultConfig {
        minSdk = 23
    }
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

kotlin {
    jvmToolchain(17)
    compilerOptions {
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    // The included build of targets/kotlin stands in for this, whatever the version.
    implementation("org.novasoftwarefoundation:prism-compose:0")
    testImplementation(platform("androidx.compose:compose-bom:2026.11.01"))
    testImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    testImplementation("org.robolectric:robolectric:4.18.1")
    testImplementation("junit:junit:4.13.2")
}
