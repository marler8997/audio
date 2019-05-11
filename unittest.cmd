@REM Example: unittest audio\render.d
@if [%1]==[] (
    echo Example: unittest audiolib\audio\render.d
    goto EXIT
)
rund -unittest -betterC -i -I=%~dp0..\mar\src -I=%~dp0audiolib %~dp0%1
:EXIT
