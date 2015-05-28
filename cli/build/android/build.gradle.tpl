<%! import json %>
import org.apache.tools.ant.taskdefs.condition.Os

buildscript {
  repositories {
    mavenCentral()
  }
  dependencies {
    classpath 'com.android.tools.build:gradle:1.2.0'
  }
}

apply plugin: 'com.android.application'
android {
  compileSdkVersion ${ app['android']['target'] }
  buildToolsVersion '${ app['android']['build_tools'] }'

  defaultConfig {
    applicationId '${ app['id'] }'
    minSdkVersion 9
    targetSdkVersion ${ app['android']['target'] }
    versionCode ${ app['version_num'] }
    versionName "${ str(app['version']) }"
    ndk {
      % for abi in app['android']['arch']:
          abiFilter '${ abi }'
      % endfor
    }
  }

  sourceSets {
    main {
      manifest.srcFile "AndroidManifest.xml"
      java.srcDirs = [
        % for src in native_modules:
            ${ 'native/' + src + '/java' | json.dumps },
        % endfor
      ]
      res.srcDirs = [
        % for src in native_modules:
            ${ 'native/' + src + '/res' | json.dumps },
        % endfor
      ]
      assets.srcDirs = [
        % for src in native_modules:
            ${ 'native/' + src + '/assets' | json.dumps },
        % endfor
        "package",
      ]
      jni.srcDirs = []
      jniLibs.srcDirs = [
        % for src in native_modules:
            ${ 'native/' + src + '/libs' | json.dumps },
        % endfor
      ]
    }
  }

  buildTypes {
    release {
      minifyEnabled true
      proguardFile getDefaultProguardFile('proguard-android.txt')
    }
  }

  % if app['android']['ndk']:
      task ndkBuild(type: Exec) {
        % for src in native_modules:
            % if path.exists(path.join(build_path, 'native', src, 'jni')):
                workingDir file(${ 'native/' + src + '/jni' | json.dumps })
                commandLine getNdkBuildCmd()
            % endif
        % endfor
      }

      tasks.withType(JavaCompile) {
        compileTask -> compileTask.dependsOn ndkBuild
      }

      task cleanNative(type: Exec) {
        % for src in native_modules:
            % if path.exists(path.join(build_path, 'native', src, 'jni')):
                workingDir file(${ 'native/' + src + '/jni' | json.dumps })
                commandLine getNdkBuildCmd(), 'clean'
            % endif
        % endfor
      }

      clean.dependsOn cleanNative
  % endif
}

def getNdkBuildCmd() {
  def ndkbuild = project.android.ndkDirectory.toString() + '/ndk-build'
  if (Os.isFamily(Os.FAMILY_WINDOWS)) ndkbuild += '.cmd'
  return ndkbuild
}
