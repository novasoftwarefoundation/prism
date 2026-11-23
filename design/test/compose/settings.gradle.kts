// Prism's components rendered on the JVM (Robolectric) at the default font size and at
// Android's largest, 200%: a box that holds text grows with it and cuts none of it off.
// The library is the committed targets/kotlin, built from source here.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "prism-checks"
includeBuild("../../../targets/kotlin")
