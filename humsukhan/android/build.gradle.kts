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

subprojects {
    project.evaluationDependsOn(":app")

    // permission_handler_android's release annotation extraction invokes an
    // incompatible lint/IntelliJ API combination in the current Android toolchain.
    // Annotation extraction is not required to package the application, so disable
    // only that dependency task instead of weakening the application's lint checks.
    if (name == "permission_handler_android") {
        tasks.matching { it.name == "extractReleaseAnnotations" }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
