@REM Example: unittest audio\render.d
@if [%1]==[] (
    echo Example: unittest audiolib\audio\render.d
    goto EXIT
)
@REM Unittesting not really working right now, so to unittest
@REM    1. add a main function to the module
@REM    2. replace 'unittest' with 'void unittestA()'
@REM    3. call the unittestX() functions in main
rund -unittest -betterC -i -I=%~dp0..\mar\src -I=%~dp0audiolib %~dp0%1
:EXIT
