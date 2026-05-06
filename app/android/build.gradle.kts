import java.io.File

/** Prefer an SDK-installed CMake; h3_flutter pins 3.18.1 which is often missing (CXX1300). */
fun resolvedCmakeVersionFromSdk(): String {
    val sdkRoot = System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT") ?: return "3.22.1"
    val cmakeRoot = File(sdkRoot, "cmake")
    if (!cmakeRoot.isDirectory) return "3.22.1"
    val preferred = listOf("3.22.1", "3.24.0", "3.30.3", "3.31.1", "3.18.1")
    for (v in preferred) {
        val bin = File(File(cmakeRoot, v), "bin")
        val exe = sequenceOf(File(bin, "cmake"), File(bin, "cmake.exe")).firstOrNull { it.isFile }
        if (exe != null) return v
    }
    return cmakeRoot.listFiles()?.filter { it.isDirectory }?.map { it.name }?.lastOrNull()
        ?: "3.22.1"
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

// h3_flutter: override pinned CMake 3.18.1 → version present under $ANDROID_HOME/cmake (CXX1300).
gradle.beforeProject {
    if (name != "h3_flutter") return@beforeProject
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val override = rootProject.findProperty("cmake.version.override") as? String
        val ver = override?.trim()?.takeIf { it.isNotEmpty() }
            ?: resolvedCmakeVersionFromSdk()
        runCatching {
            val enb = androidExt.javaClass.getMethod("getExternalNativeBuild").invoke(androidExt)
            val cmakeOpts = enb.javaClass.getMethod("getCmake").invoke(enb)
            cmakeOpts.javaClass.getMethod("setVersion", String::class.java).invoke(cmakeOpts, ver)
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires every Android library module to declare `namespace`. Older
// Flutter plugins (e.g. h3_flutter 0.6.x) omit it; derive from manifest package.
// Use plugins.withId (not afterEvaluate): evaluationDependsOn(":app") can leave
// subprojects already evaluated, so afterEvaluate throws "already evaluated".
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val existingNs = runCatching {
                androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
            }.getOrNull()
            if (existingNs.isNullOrBlank()) {
                val manifest = file("${project.projectDir}/src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = Regex("package=\"([^\"]+)\"")
                        .find(manifest.readText())
                        ?.groupValues
                        ?.get(1)
                    if (pkg != null) {
                        runCatching {
                            androidExt.javaClass.getMethod(
                                "setNamespace",
                                String::class.java,
                            ).invoke(androidExt, pkg)
                        }
                    }
                }
            }
        }
    }
}

// Suppress noisy Java 8 source/target obsolete warnings
// coming from some transitive Android plugin modules.
subprojects {
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
