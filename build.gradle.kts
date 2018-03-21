import groovy.lang.Closure
import org.apache.commons.collections.buffer.CircularFifoBuffer
import org.gradle.api.tasks.GradleBuild
import org.openbakery.xcode.Destination
import java.nio.file.Files

buildscript {
    dependencies {
        classpath("gradle.plugin.org.openbakery:plugin:0.15.2")
    }

    repositories {
        maven { url = uri("http://repository.openbakery.org/") }
    }
}

plugins {
    id("org.openbakery.xcode-plugin").version("0.15.2")
}

xcodebuild {
    xcode.commandRunner.commandOutputBuffer = (object : CircularFifoBuffer(100) {} as Collection<String>)
    println("${xcode.commandRunner.commandOutputBuffer}")

    bundleName = "SnipsPlatform"
    workspace = "SnipsPlatformDemo.xcworkspace"
    scheme = "SnipsPlatform"
    configuration = "Debug" // TODO Implement build types
    destination(closureOf<Destination> {
        platform = "iOS Simulator"
        name = "iPhone X"
//        os = "latest"
//        arch = "x86_64-apple-ios"
    })
    derivedDataPath = file("build/DerivedData")
    target = "SnipsPlatform"
}
