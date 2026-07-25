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

// Some third-party Flutter plugins (e.g. vosk_flutter_2) still declare their
// package only in AndroidManifest and omit the `namespace` that AGP 8 now
// requires, which fails the build. Inject a namespace (the plugin's group) for
// any Android subproject missing one. Reflection avoids putting the AGP types
// on the root buildscript classpath, and the null-check makes it a no-op for
// every plugin that already sets a namespace. Registered BEFORE the
// evaluationDependsOn block below so no subproject is force-evaluated yet.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val getNamespace = androidExt.javaClass.methods
            .firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
        val setNamespace = androidExt.javaClass.methods
            .firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
        if (getNamespace != null && setNamespace != null &&
            getNamespace.invoke(androidExt) == null
        ) {
            setNamespace.invoke(androidExt, project.group.toString())
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
