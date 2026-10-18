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

// ponytail: some transitive plugin modules (better_player_plus previously,
// screen_brightness_android from media_kit_video now) compile Java with 1.8
// while their Kotlin targets 17 — AGP 9 fails on the mismatch. Pin Java and
// Kotlin to 17 for the whole module tree. Drop when upstream guards cover
// AGP >= 9. Registered before evaluationDependsOn (below) triggers
// evaluation, so the afterEvaluate fires after each module's own android{}
// block and its compileOptions don't win.
subprojects {
    // AGP 9's built-in Kotlin ignores screen_brightness_android 2.1.6's own
    // jvmTarget pin, so its Kotlin builds at 17 while its Java stays 1.8 —
    // mismatch fails the build. Align this one module's Kotlin to its
    // declared Java (1.8). Keep to that module: :app is already 17/17.
    if (name == "screen_brightness_android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
