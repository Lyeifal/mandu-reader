allprojects {
    repositories {
        // 国际出口限速：阿里镜像优先，官方源兜底（maven.google.com 在本网络 TLS 握手失败）
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://dl.google.com/dl/android/maven2/")
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
// 统一 JVM target：flutter_avif 等插件模块 Java 11 / Kotlin 17 不一致会导致
// compileDebugKotlin 报 Inconsistent JVM-target compatibility，这里全部钉到 17。
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks
        .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
            )
        }
}
// flutter_avif_android 的 compileSdk=31 等修正直接在 pub 缓存里改（见 AGENTS.md）。

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
