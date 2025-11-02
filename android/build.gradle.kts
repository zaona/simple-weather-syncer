allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 只对主应用项目应用构建目录重定向，避免 Flutter 插件的跨驱动器路径问题
project(":app").layout.buildDirectory.value(
    rootProject.layout.projectDirectory.dir("../build/app")
)

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
