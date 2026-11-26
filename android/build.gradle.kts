allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildDirOverride = System.getenv("DARPLUS_BUILD_DIR")
val newBuildDir: Directory =
    if (buildDirOverride.isNullOrBlank()) {
        rootProject.layout.buildDirectory
            .dir("../../build")
            .get()
    } else {
        rootProject.layout.dir(
            providers.provider { rootProject.file(buildDirOverride) },
        ).get()
    }
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
