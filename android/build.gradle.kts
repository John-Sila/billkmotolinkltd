import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.1") // Android Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Kotlin
        classpath("com.google.gms:google-services:4.4.2") // Firebase / Google Services
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: move build output outside module
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
