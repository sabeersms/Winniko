@echo off
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set GRADLE_USER_HOME=d:\projects\antigravity\Winniko\.gradle_local
set PATH=C:\src\flutter\bin;%PATH%
echo Starting Flutter build with isolated environment...
call flutter build apk --debug --verbose
echo Build finished with exit code %ERRORLEVEL%
