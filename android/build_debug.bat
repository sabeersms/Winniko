@echo off
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set GRADLE_USER_HOME=d:\projects\antigravity\Winniko\.gradle_local
echo Starting build with isolated environment...
.\gradlew assembleDebug --no-daemon --stacktrace
echo Build finished with exit code %ERRORLEVEL%
