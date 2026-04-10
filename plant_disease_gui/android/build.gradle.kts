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
}

// Removemos o bloco que causava erro de "already evaluated"
// Se os avisos de Java 8 persistirem, a melhor forma é atualizar os plugins no pubspec.yaml
// ou ignorar, já que não impedem a construção do APK.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
