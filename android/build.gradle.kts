allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins compile against whatever `compileSdk` they each declare, and several
// still pin 34. `flutter_plugin_android_lifecycle` publishes AAR metadata
// demanding API 36+, so any plugin below that — `file_picker` first — fails the
// build at `checkDebugAarMetadata`. Raising every plugin to the app's level
// only widens the APIs they may compile against; `minSdk` and `targetSdk` are
// untouched, so neither device support nor runtime behaviour changes.
//
// This must be registered *before* the `evaluationDependsOn` below, which
// evaluates every subproject — `afterEvaluate` throws once that has happened.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            if (android is com.android.build.gradle.LibraryExtension) {
                android.compileSdk = 36
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
