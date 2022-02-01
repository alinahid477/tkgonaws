@ECHO OFF


echo "Unix convert start,..." 

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './converter.ps1'"

echo "Unix convert end,..."

set name=%1
set doforcebuild=%2

if "%name%" == "forcebuild" (
    set name=
    set doforcebuild="forcebuild"    
)

if "%name%" == "" (
    echo "assuming default name is: merlin-tkgonaws"
    set name="merlin-tkgonaws"
)


set isexists=
FOR /F "delims=" %%i IN ('docker images  ^| findstr /i "%name%"') DO set isexists=%%i

if "%name%" == "%isexists%" (
    echo "docker image name %isexists% already exists. Will avoide build if not forcebuild..."
)

set dobuild=
if "%isexists%" == "" (set dobuild=y)

if "%doforcebuild%" == "forcebuild" (set dobuild=y)
if "%dobuild%" == "y" (docker build . -t %name%)


setlocal enableextensions
set count=0
for %%x in (binaries/*.tar.*) do set /a count+=1
echo %count%
if %count% NEQ 1 (
    echo "Found 0 or more than 1 tar file in the binaries dir. binaries dir must contain eactly 1 tar file..."
    EXIT /B 0
)

set dodockercopy="no"
if exist Dockerfile (
	isexist="Dockerfile"
) else (
	dodockercopy="yes"
)
@REM if exist binaries/Dockerfile (
@REM 	isexist2="binaries/Dockerfile"
@REM ) else (
@REM 	dodockercopy="yes"
@REM )

if "%dodockercopy%" == "yes" (
	set tanzubundlename=
	for %%x in (binaries/*.tar.*) do set tanzubundlename=%%x
	if "%tanzubundlename:~0,3%" == "tce" (
		echo "tce detected"
		copy Dockerfile.tce0.9.1 Dockerfile
	) ELSE (
		echo "tkg detected"
		copy Dockerfile.tkg1.4 Dockerfile
	)
)
	
endlocal

set currdir=%cd%
docker run -it --rm --net=host --add-host kubernetes:127.0.0.1 -v %currdir%:/root/ --name %name% %name%
PAUSE
