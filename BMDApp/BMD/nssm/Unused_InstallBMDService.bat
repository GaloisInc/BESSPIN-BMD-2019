set BMDFolderLocation=C:\Wrapper_bmd
set BMDStaticFolderLocation=C:\Wrapper_bmd\build
set /A port=7777
set username=egadmin

nssm install EG_BMD_WebService "C:\Program Files\nodejs\node.exe" AppDirectory %BMDFolderLocation% AppParameters "C:\Users\%username%\AppData\Roaming\npm\node_modules\http-server\bin\http-server %BMDStaticFolderLocation% -p %port%"

REM nssm install EG_BMD_WebService
REM nssm set EG_BMD_WebService Application C:\Program Files\nodejs\node.exe
REM nssm set EG_BMD_WebService AppDirectory %BMDFolderLocation%
REM nssm set EG_BMD_WebService AppParameters C:\Users\%username%\AppData\Roaming\npm\node_modules\http-server\bin\http-server %BMDStaticFolderLocation% -p %port%
REM nssm start EG_BMD_WebService 