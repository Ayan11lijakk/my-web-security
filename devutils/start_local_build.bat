@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_ROOT=%~dp0.."
pushd "%REPO_ROOT%" || exit /b 1

set "THREADS=6"
set "PROXY_URL=http://127.0.0.1:1081"
set "POSITIONAL_INDEX=0"
set "DEBUG_MODE=0"
set "START_STEP=1"
set "WITH_HOOKS=0"
set "BUILD_VB_ASSETS=0"
set "WITH_INSTALLER=0"
set "LOCAL_DISABLE_PGO=1"
set "TEMP_SRC_JUNCTION=0"
set "LOG_DIR=%REPO_ROOT%\build\logs"
set "LOG_FILE="

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--threads" (
  if "%~2"=="" (
    echo ERROR: --threads requires a value.
    popd
    exit /b 1
  )
  set "THREADS=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--proxy" (
  if "%~2"=="" (
    echo ERROR: --proxy requires a value.
    popd
    exit /b 1
  )
  set "PROXY_URL=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--no-proxy" (
  set "PROXY_URL="
  shift
  goto parse_args
)
if /I "%~1"=="--no-proxies" (
  set "PROXY_URL="
  shift
  goto parse_args
)
if /I "%~1"=="--debug" (
  set "DEBUG_MODE=1"
  shift
  goto parse_args
)
if /I "%~1"=="--debug-file" (
  set "DEBUG_MODE=2"
  shift
  goto parse_args
)
if /I "%~1"=="--step" (
  if "%~2"=="" (
    echo ERROR: --step requires a value 1, 2 or 3.
    popd
    exit /b 1
  )
  set "START_STEP=%~2"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--with-hooks" (
  set "WITH_HOOKS=1"
  shift
  goto parse_args
)
if /I "%~1"=="--build-vb-assets" (
  set "BUILD_VB_ASSETS=1"
  shift
  goto parse_args
)
if /I "%~1"=="--with-installer" (
  set "WITH_INSTALLER=1"
  shift
  goto parse_args
)
echo "%~1" | findstr /b /c:"--" >nul
if not errorlevel 1 (
  echo ERROR: Unknown option %~1
  popd
  exit /b 1
)
set /a POSITIONAL_INDEX=%POSITIONAL_INDEX%+1
set "ARG_VALUE=%~1"
set "NON_NUM="
for /f "delims=0123456789" %%A in ("%ARG_VALUE%") do set "NON_NUM=%%A"
if "%POSITIONAL_INDEX%"=="1" (
  if defined NON_NUM (
    set "PROXY_URL=%ARG_VALUE%"
  ) else (
    set "THREADS=%ARG_VALUE%"
  )
  shift
  goto parse_args
)
if "%POSITIONAL_INDEX%"=="2" (
  set "PROXY_URL=%ARG_VALUE%"
  shift
  goto parse_args
)
echo ERROR: Unexpected positional argument: %ARG_VALUE%
popd
exit /b 1

:args_done

set "PY_CMD=py -3.11"
%PY_CMD% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>nul
if errorlevel 1 (
  set "PY_CMD=py -3.12"
  %PY_CMD% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>nul
)
if errorlevel 1 (
  set "PY_CMD=python3"
  %PY_CMD% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>nul
)
if errorlevel 1 (
  echo ERROR: Python 3.10+ is required. Install Python 3.11 or 3.12.
  popd
  exit /b 1
)

for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import sys; print(sys.executable)"`) do set "PY_EXE=%%i"
if "%PY_EXE%"=="" (
  echo ERROR: Failed to locate Python executable.
  popd
  exit /b 1
)

if not exist ".local-bin" mkdir ".local-bin"
(
  echo @echo off
  echo "%PY_EXE%" "%REPO_ROOT%\devutils\vpython3_shim.py" %%*
) > ".local-bin\vpython3.bat"
(
  echo @echo off
  echo "%PY_EXE%" %%*
) > ".local-bin\python3.bat"
(
  echo @echo off
  echo "%PY_EXE%" %%*
) > ".local-bin\python.bat"

set "PATH=%REPO_ROOT%\.local-bin;%PATH%"
if exist "C:\Program Files\Git\usr\bin\sh.exe" set "PATH=C:\Program Files\Git\usr\bin;%PATH%"
if exist "C:\Program Files\Git\bin\sh.exe" set "PATH=C:\Program Files\Git\bin;%PATH%"
set "DEPOT_TOOLS_UPDATE=0"
set "DEPOT_TOOLS_DIR=%REPO_ROOT%\build\src\uc_staging\depot_tools"
set "GCLIENT_FILE=%REPO_ROOT%\build\src\uc_staging\.gclient"
set "PYTHONPATH=%REPO_ROOT%\build\src\uc_staging\depot_tools"

if defined PROXY_URL (
  set "HTTP_PROXY=%PROXY_URL%"
  set "HTTPS_PROXY=%PROXY_URL%"
  set "ALL_PROXY=%PROXY_URL%"
  set "http_proxy=%PROXY_URL%"
  set "https_proxy=%PROXY_URL%"
  set "all_proxy=%PROXY_URL%"
  git config --global http.proxy "%PROXY_URL%" >nul 2>nul
  git config --global https.proxy "%PROXY_URL%" >nul 2>nul
) else (
  set "HTTP_PROXY="
  set "HTTPS_PROXY="
  set "ALL_PROXY="
  set "http_proxy="
  set "https_proxy="
  set "all_proxy="
  git config --global --unset-all http.proxy >nul 2>nul
  git config --global --unset-all https.proxy >nul 2>nul
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
for /f %%i in ('%PY_CMD% -c "from datetime import datetime; print(datetime.now().strftime('%%Y%%m%%d_%%H%%M%%S'))"') do set "NOW_TS=%%i"
set "LOG_FILE=%LOG_DIR%\start_local_build_%NOW_TS%.log"

set "CL_APPEND_FLAGS=/utf-8 /wd4819 /WX-"

echo Threads: %THREADS%
echo Python command: %PY_CMD%
if defined PROXY_URL (
  echo Proxy: %PROXY_URL%
) else (
  echo Proxy: disabled
)
if "%DEBUG_MODE%"=="1" (
  echo Debug mode: console+file
) else if "%DEBUG_MODE%"=="2" (
  echo Debug mode: file-only
) else (
  echo Debug mode: off
)
echo Start step: %START_STEP%
if "%WITH_HOOKS%"=="1" (
  echo Sync hooks: enabled
) else (
  echo Sync hooks: disabled
)
if "%BUILD_VB_ASSETS%"=="1" (
  echo VirtualBrowser assets: build before packaging
) else (
  echo VirtualBrowser assets: use existing dist outputs
)
if "%WITH_INSTALLER%"=="1" (
  echo Installer artifact: enabled
) else (
  echo Installer artifact: disabled
)
if "%LOCAL_DISABLE_PGO%"=="1" (
  echo Local PGO: disabled ^(chrome_pgo_phase=0^)
) else (
  echo Local PGO: enabled
)
echo Log file: %LOG_FILE%
echo CL append flags: %CL_APPEND_FLAGS%
echo Python urllib proxies:
call %PY_CMD% -c "import urllib.request; print(urllib.request.getproxies())"
if not "%START_STEP%"=="1" if not "%START_STEP%"=="2" if not "%START_STEP%"=="3" (
  echo ERROR: --step must be 1, 2 or 3.
  popd
  exit /b 1
)
for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "TOTAL_START=%%i"
echo Build start: %DATE% %TIME%
>> "%LOG_FILE%" echo Build start: %DATE% %TIME%

if not exist "build\src\uc_staging\depot_tools\gclient.bat" (
  echo ERROR: gclient.bat not found. Run source clone stage first.
  popd
  exit /b 1
)
if exist "build\src\uc_staging\.gclient" (
  call "%PY_EXE%" "%REPO_ROOT%\devutils\ensure_gclient_vars.py" "%REPO_ROOT%\build\src\uc_staging\.gclient"
  if errorlevel 1 (
    echo ERROR: Failed to update .gclient custom vars.
    popd
    exit /b 1
  )
)

if %START_STEP% LEQ 1 (
  echo [1/3] Sync dependencies...
  set "GCLIENT_SYNC_ARGS=sync -v -f -D -R --no-history --sysroot=None"
  if not "%WITH_HOOKS%"=="1" set "GCLIENT_SYNC_ARGS=!GCLIENT_SYNC_ARGS! --nohooks"
  if "%WITH_HOOKS%"=="1" (
    if exist "%REPO_ROOT%\build\src\build\landmines.py" if not exist "%REPO_ROOT%\src" (
      cmd /c mklink /J "%REPO_ROOT%\src" "%REPO_ROOT%\build\src" >nul
      if not errorlevel 1 (
        set "TEMP_SRC_JUNCTION=1"
        echo INFO: Created temporary junction: %REPO_ROOT%\src -> %REPO_ROOT%\build\src
      )
    )
  )
  echo Running: gclient !GCLIENT_SYNC_ARGS!
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP1_START=%%i"
  set "SYNC_RC=0"
  if "%DEBUG_MODE%"=="1" (
    powershell -NoProfile -Command "& { cmd /c \"\"%REPO_ROOT%\\build\\src\\uc_staging\\depot_tools\\gclient.bat\" !GCLIENT_SYNC_ARGS! 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    set "SYNC_RC=!ERRORLEVEL!"
  ) else if "%DEBUG_MODE%"=="2" (
    call "build\src\uc_staging\depot_tools\gclient.bat" !GCLIENT_SYNC_ARGS! >> "%LOG_FILE%" 2>&1
    set "SYNC_RC=!ERRORLEVEL!"
  ) else (
    call "build\src\uc_staging\depot_tools\gclient.bat" !GCLIENT_SYNC_ARGS!
    set "SYNC_RC=!ERRORLEVEL!"
  )
  if not "!SYNC_RC!"=="0" (
    echo WARNING: gclient sync failed with code !SYNC_RC!. Trying one cleanup+retry...
    powershell -NoProfile -Command "& { $base='%REPO_ROOT%\build\src\uc_staging\depot_tools\external_bin\gsutil'; if (Test-Path $base) { Get-ChildItem -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }; Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }; $tmp='%REPO_ROOT%\build\src\third_party\node\node_modules'; if (Test-Path $tmp) { Get-ChildItem -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }; Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } }"
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"%REPO_ROOT%\\build\\src\\uc_staging\\depot_tools\\gclient.bat\" !GCLIENT_SYNC_ARGS! 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "build\src\uc_staging\depot_tools\gclient.bat" !GCLIENT_SYNC_ARGS! >> "%LOG_FILE%" 2>&1
    ) else (
      call "build\src\uc_staging\depot_tools\gclient.bat" !GCLIENT_SYNC_ARGS!
    )
    set "SYNC_RC=!ERRORLEVEL!"
  )
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP1_END=%%i"
  if not defined STEP1_START set "STEP1_START=0"
  if not defined STEP1_END set "STEP1_END=!STEP1_START!"
  set /a STEP1_SEC=!STEP1_END!-!STEP1_START!
  if !STEP1_SEC! LSS 0 set "STEP1_SEC=0"
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "s=int('!STEP1_SEC!'); h=s//3600; m=(s%%3600)//60; ss=s%%60; print(f'{h}h {m}m {ss}s, total {s}s')"` ) do set "STEP1_FMT=%%i"
  if not "!SYNC_RC!"=="0" (
    if "%TEMP_SRC_JUNCTION%"=="1" (
      rmdir "%REPO_ROOT%\src" >nul 2>nul
      set "TEMP_SRC_JUNCTION=0"
    )
    echo [Timing] Step 1 Sync ^(failed^): !STEP1_FMT!
    >> "%LOG_FILE%" echo [Timing] Step 1 Sync ^(failed^): !STEP1_FMT!
    echo ERROR: gclient sync failed after retry.
    popd
    exit /b 1
  )
  echo [Timing] Step 1 Sync: !STEP1_FMT!
  >> "%LOG_FILE%" echo [Timing] Step 1 Sync: !STEP1_FMT!
  if "%TEMP_SRC_JUNCTION%"=="1" (
    rmdir "%REPO_ROOT%\src" >nul 2>nul
    set "TEMP_SRC_JUNCTION=0"
  )
) else (
  echo [1/3] Skipped by --step %START_STEP%
)

if %START_STEP% LEQ 2 (
  if not defined vs2022_install (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$vs='C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe'; if (Test-Path $vs) { $p=& $vs -latest -products * -requires Microsoft.Component.MSBuild -property installationPath; if ($p) { $p.Trim() } }"`) do set "vs2022_install=%%i"
  )
  set "vs2022_install=!vs2022_install:"=!"
  set "vs2022_install=!vs2022_install:'=!"
  if defined vs2022_install (
    set "GYP_MSVS_OVERRIDE_PATH=!vs2022_install!"
    set "DEPOT_TOOLS_WIN_TOOLCHAIN=0"
  )
  if not defined WINSDK_VER (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$roots=@('D:\\Windows Kits\\10\\Include','C:\\Program Files (x86)\\Windows Kits\\10\\Include'); $vers=@(); foreach($r in $roots){ if(Test-Path $r){ $vers += Get-ChildItem $r -Directory | Where-Object { $_.Name -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' } | ForEach-Object { $_.Name } } }; if($vers){ ($vers | Sort-Object {[version]$_} -Descending | Select-Object -First 1) }"`) do set "WINSDK_VER=%%i"
  )
  if defined WINSDK_VER (
    if exist "D:\Windows Kits\10\Include\!WINSDK_VER!" (
      set "WindowsSdkDir=D:\Windows Kits\10\"
    ) else if exist "C:\Program Files (x86)\Windows Kits\10\Include\!WINSDK_VER!" (
      set "WindowsSdkDir=C:\Program Files (x86)\Windows Kits\10\"
    )
    set "WindowsSDKVersion=!WINSDK_VER!\"
    set "UCRTVersion=!WINSDK_VER!"
    echo INFO: using Windows SDK !WINSDK_VER!
  )
  if not exist "build\src\third_party\rust-toolchain\bin\cargo.exe" (
    echo INFO: cargo.exe missing. Trying prebuilt Rust toolchain download first...
    pushd "build\src" >nul
    set "RUST_UPDATE_RC=0"
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"%PY_EXE%\" tools\\rust\\update_rust.py 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
      set "RUST_UPDATE_RC=!ERRORLEVEL!"
    ) else if "%DEBUG_MODE%"=="2" (
      call "%PY_EXE%" tools\rust\update_rust.py >> "%LOG_FILE%" 2>&1
      set "RUST_UPDATE_RC=!ERRORLEVEL!"
    ) else (
      call "%PY_EXE%" tools\rust\update_rust.py
      set "RUST_UPDATE_RC=!ERRORLEVEL!"
    )
    popd >nul
    if "!RUST_UPDATE_RC!"=="0" (
      if exist "%REPO_ROOT%\build\src\third_party\rust-toolchain\bin\cargo.exe" (
        echo INFO: prebuilt Rust toolchain downloaded.
      )
    )
  )
  if not exist "build\src\third_party\rust-toolchain\bin\cargo.exe" (
    echo INFO: prebuilt Rust toolchain unavailable. Building Rust toolchain locally...
    set "LOCAL_CL_BACKUP=!CL!"
    set "LOCAL__CL_BACKUP=!_CL_!"
    set "CL="
    set "_CL_="
    if not defined vs2022_install (
      for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$vs='C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe'; if (Test-Path $vs) { $p=& $vs -latest -products * -requires Microsoft.Component.MSBuild -property installationPath; if ($p) { $p.Trim() } }"`) do set "vs2022_install=%%i"
    )
    set "vs2022_install=!vs2022_install:"=!"
    set "vs2022_install=!vs2022_install:'=!"
    if defined vs2022_install echo INFO: vs2022_install=!vs2022_install!
    if not defined vs2022_install (
      echo ERROR: Unable to detect Visual Studio installation path.
      popd
      exit /b 1
    )
    set "VCVARS_BAT=!vs2022_install!\VC\Auxiliary\Build\vcvars64.bat"
    echo INFO: using vcvars: !VCVARS_BAT!
    if not exist "!VCVARS_BAT!" (
      echo ERROR: vcvars64.bat not found: !VCVARS_BAT!
      popd
      exit /b 1
    )
    set "RUST_BOOTSTRAP_BAT=%REPO_ROOT%\.local-bin\run_rust_toolchain_build.bat"
    (
      echo @echo off
      if defined WINSDK_VER (
        echo call "!VCVARS_BAT!" -winsdk=!WINSDK_VER! ^>nul
      ) else (
        echo call "!VCVARS_BAT!" ^>nul
      )
      echo if errorlevel 1 exit /b %%errorlevel%%
      echo set DEPOT_TOOLS_WIN_TOOLCHAIN=0
      echo "%PY_EXE%" tools\rust\build_rust.py
      echo exit /b %%errorlevel%%
    ) > "!RUST_BOOTSTRAP_BAT!"
    pushd "build\src" >nul
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"!RUST_BOOTSTRAP_BAT!\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "!RUST_BOOTSTRAP_BAT!" >> "%LOG_FILE%" 2>&1
    ) else (
      call "!RUST_BOOTSTRAP_BAT!"
    )
    set "RUST_RC=!ERRORLEVEL!"
    popd >nul
    if not "!RUST_RC!"=="0" (
      echo WARNING: build_rust.py failed with code !RUST_RC!. Falling back to gclient runhooks...
      if exist "%REPO_ROOT%\build\src\build\landmines.py" if not exist "%REPO_ROOT%\src" (
        cmd /c mklink /J "%REPO_ROOT%\src" "%REPO_ROOT%\build\src" >nul
        if not errorlevel 1 (
          set "TEMP_SRC_JUNCTION=1"
          echo INFO: Created temporary junction: %REPO_ROOT%\src -> %REPO_ROOT%\build\src
        )
      )
      if "%DEBUG_MODE%"=="1" (
        powershell -NoProfile -Command "& { cmd /c \"\"%REPO_ROOT%\\build\\src\\uc_staging\\depot_tools\\gclient.bat\" runhooks 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
      ) else if "%DEBUG_MODE%"=="2" (
        call "build\src\uc_staging\depot_tools\gclient.bat" runhooks >> "%LOG_FILE%" 2>&1
      ) else (
        call "build\src\uc_staging\depot_tools\gclient.bat" runhooks
      )
      if errorlevel 1 (
        if "%TEMP_SRC_JUNCTION%"=="1" (
          rmdir "%REPO_ROOT%\src" >nul 2>nul
          set "TEMP_SRC_JUNCTION=0"
        )
        echo ERROR: gclient runhooks failed.
        popd
        exit /b 1
      )
      if "%TEMP_SRC_JUNCTION%"=="1" (
        rmdir "%REPO_ROOT%\src" >nul 2>nul
        set "TEMP_SRC_JUNCTION=0"
      )
    )
    set "CL=!LOCAL_CL_BACKUP!"
    set "_CL_=!LOCAL__CL_BACKUP!"
    if not exist "%REPO_ROOT%\build\src\third_party\rust-toolchain\bin\cargo.exe" (
      echo ERROR: cargo.exe is still missing after rust toolchain setup.
      popd
      exit /b 1
    )
  )
  if exist "build\src\third_party\rust-toolchain\bin\rustc.exe" if not exist "build\src\third_party\rust-toolchain\INSTALLED_VERSION" (
    > "build\src\third_party\rust-toolchain\INSTALLED_VERSION" call "build\src\third_party\rust-toolchain\bin\rustc.exe" --version
    if errorlevel 1 (
      echo WARNING: Failed to generate rust-toolchain\INSTALLED_VERSION
    ) else (
      echo INFO: Generated rust-toolchain\INSTALLED_VERSION
    )
  )
  if not exist "build\src\tools\gn\build\gen.py" (
    echo WARNING: build\src\tools\gn is incomplete. Repairing from uc_staging\gn...
    powershell -NoProfile -Command "& { $src='%REPO_ROOT%\build\src\uc_staging\gn'; $dst='%REPO_ROOT%\build\src\tools\gn'; if (!(Test-Path $src)) { Write-Error 'Missing source GN tree: ' + $src; exit 1 }; New-Item -ItemType Directory -Force -Path $dst | Out-Null; Get-ChildItem -LiteralPath $src -Force | Where-Object { $_.Name -notin '.git','out' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dst $_.Name) -Recurse -Force } }"
    if errorlevel 1 (
      echo ERROR: Failed to repair tools\gn from uc_staging\gn.
      popd
      exit /b 1
    )
  )
  if not exist "build\src\tools\gn\bootstrap\last_commit_position.h" (
    echo WARNING: Missing tools\gn\bootstrap\last_commit_position.h. Regenerating...
    pushd "build\src\uc_staging\gn" >nul
    call "%PY_EXE%" build\gen.py
    if errorlevel 1 (
      popd >nul
      echo ERROR: Failed to run uc_staging\gn\build\gen.py.
      popd
      exit /b 1
    )
    popd >nul
    if not exist "build\src\uc_staging\gn\out\last_commit_position.h" (
      echo ERROR: Generated file not found: build\src\uc_staging\gn\out\last_commit_position.h
      popd
      exit /b 1
    )
    copy /Y "build\src\uc_staging\gn\out\last_commit_position.h" "build\src\tools\gn\bootstrap\last_commit_position.h" >nul
    if errorlevel 1 (
      echo ERROR: Failed to copy last_commit_position.h into tools\gn\bootstrap.
      popd
      exit /b 1
    )
  )
  if exist "build\src\tools\gn\bootstrap\bootstrap.py" (
    call "%PY_EXE%" "%REPO_ROOT%\devutils\patch_gn_bootstrap.py" "%REPO_ROOT%\build\src\tools\gn\bootstrap\bootstrap.py"
    if errorlevel 1 (
      echo ERROR: Failed to patch tools\gn\bootstrap\bootstrap.py.
      popd
      exit /b 1
    )
  )
  if not exist "build\src\third_party\ninja\ninja.exe" (
    echo INFO: third_party\ninja\ninja.exe missing. Running gclient sync to fetch deps...
    if exist "%REPO_ROOT%\build\src\build\landmines.py" if not exist "%REPO_ROOT%\src" (
      cmd /c mklink /J "%REPO_ROOT%\src" "%REPO_ROOT%\build\src" >nul
      if not errorlevel 1 (
        set "TEMP_SRC_JUNCTION=1"
        echo INFO: Created temporary junction: %REPO_ROOT%\src -> %REPO_ROOT%\build\src
      )
    )
    set "NINJA_SYNC_ARGS=sync -v -f -D -R --no-history --sysroot=None --nohooks"
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"%REPO_ROOT%\\build\\src\\uc_staging\\depot_tools\\gclient.bat\" !NINJA_SYNC_ARGS! 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "build\src\uc_staging\depot_tools\gclient.bat" !NINJA_SYNC_ARGS! >> "%LOG_FILE%" 2>&1
    ) else (
      call "build\src\uc_staging\depot_tools\gclient.bat" !NINJA_SYNC_ARGS!
    )
    if "%TEMP_SRC_JUNCTION%"=="1" (
      rmdir "%REPO_ROOT%\src" >nul 2>nul
      set "TEMP_SRC_JUNCTION=0"
    )
    if errorlevel 1 (
      echo ERROR: gclient sync failed while preparing ninja.
      popd
      exit /b 1
    )
    if not exist "build\src\third_party\ninja\ninja.exe" (
      echo WARNING: third_party\ninja\ninja.exe is still missing after gclient sync. Trying PATH ninja fallback...
      for /f "usebackq delims=" %%i in (`where ninja.exe 2^>nul`) do (
        if not defined NINJA_PATH_FALLBACK set "NINJA_PATH_FALLBACK=%%i"
      )
      if defined NINJA_PATH_FALLBACK (
        if not exist "build\src\third_party\ninja" mkdir "build\src\third_party\ninja"
        copy /Y "!NINJA_PATH_FALLBACK!" "build\src\third_party\ninja\ninja.exe" >nul
        if errorlevel 1 (
          echo ERROR: Failed to copy fallback ninja from !NINJA_PATH_FALLBACK!
          popd
          exit /b 1
        )
        echo INFO: Fallback ninja copied from !NINJA_PATH_FALLBACK!
      ) else (
        echo ERROR: third_party\ninja\ninja.exe is still missing and no ninja.exe found in PATH.
        popd
        exit /b 1
      )
    )
  )
  if not exist "build\src\third_party\lzma_sdk\bin\host_platform\7za.exe" (
    echo INFO: 7za.exe missing in lzma_sdk. Downloading via CIPD...
    if not exist "%REPO_ROOT%\.local-bin" mkdir "%REPO_ROOT%\.local-bin"
    set "CIPD_ENSURE_FILE=%REPO_ROOT%\.local-bin\cipd_ensure_7z.txt"
    > "!CIPD_ENSURE_FILE!" echo infra/3pp/tools/7z/windows-amd64 version:3@24.09
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"%DEPOT_TOOLS_DIR%\\cipd.bat\" ensure -root \"%REPO_ROOT%\\build\\src\\third_party\\lzma_sdk\\bin\\host_platform\" -ensure-file \"!CIPD_ENSURE_FILE!\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "%DEPOT_TOOLS_DIR%\cipd.bat" ensure -root "%REPO_ROOT%\build\src\third_party\lzma_sdk\bin\host_platform" -ensure-file "!CIPD_ENSURE_FILE!" >> "%LOG_FILE%" 2>&1
    ) else (
      call "%DEPOT_TOOLS_DIR%\cipd.bat" ensure -root "%REPO_ROOT%\build\src\third_party\lzma_sdk\bin\host_platform" -ensure-file "!CIPD_ENSURE_FILE!"
    )
    if errorlevel 1 (
      echo ERROR: Failed to download lzma_sdk host_platform 7za via CIPD.
      popd
      exit /b 1
    )
  )
  if not exist "build\src\third_party\lzma_sdk\bin\win64\7za.exe" (
    echo INFO: 7za.exe missing in lzma_sdk\\bin\\win64. Downloading via CIPD...
    if not exist "%REPO_ROOT%\.local-bin" mkdir "%REPO_ROOT%\.local-bin"
    set "CIPD_ENSURE_FILE=%REPO_ROOT%\.local-bin\cipd_ensure_7z.txt"
    > "!CIPD_ENSURE_FILE!" echo infra/3pp/tools/7z/windows-amd64 version:3@24.09
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"%DEPOT_TOOLS_DIR%\\cipd.bat\" ensure -root \"%REPO_ROOT%\\build\\src\\third_party\\lzma_sdk\\bin\\win64\" -ensure-file \"!CIPD_ENSURE_FILE!\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "%DEPOT_TOOLS_DIR%\cipd.bat" ensure -root "%REPO_ROOT%\build\src\third_party\lzma_sdk\bin\win64" -ensure-file "!CIPD_ENSURE_FILE!" >> "%LOG_FILE%" 2>&1
    ) else (
      call "%DEPOT_TOOLS_DIR%\cipd.bat" ensure -root "%REPO_ROOT%\build\src\third_party\lzma_sdk\bin\win64" -ensure-file "!CIPD_ENSURE_FILE!"
    )
    if errorlevel 1 (
      echo ERROR: Failed to download lzma_sdk win64 7za via CIPD.
      popd
      exit /b 1
    )
  )
  if "%LOCAL_DISABLE_PGO%"=="1" (
    call "%PY_EXE%" "%REPO_ROOT%\devutils\normalize_args_gn.py" "%REPO_ROOT%\build\src\out\Default\args.gn" --set "chrome_pgo_phase=0"
    if errorlevel 1 (
      echo ERROR: Failed to set chrome_pgo_phase=0 in out\Default\args.gn
      popd
      exit /b 1
    )
  )
  call "%PY_EXE%" "%REPO_ROOT%\devutils\normalize_args_gn.py" "%REPO_ROOT%\build\src\out\Default\args.gn" --set "safe_browsing_mode=1"
  if errorlevel 1 (
    echo ERROR: Failed to set safe_browsing_mode=1 in out\Default\args.gn
    popd
    exit /b 1
  )
  call "%PY_EXE%" "%REPO_ROOT%\devutils\normalize_args_gn.py" "%REPO_ROOT%\build\src\out\Default\args.gn" --set "build_with_tflite_lib=true"
  if errorlevel 1 (
    echo ERROR: Failed to set build_with_tflite_lib=true in out\Default\args.gn
    popd
    exit /b 1
  )
  if not exist "build\src\out\Default\build.ninja" (
    echo INFO: out\Default\build.ninja missing. Generating GN files...
    pushd "build\src" >nul
    if not exist "third_party\llvm-build-tools\Release+Asserts\cr_build_revision" (
      echo INFO: clang package missing. Running tools\clang\scripts\update.py...
      if "%DEBUG_MODE%"=="1" (
        powershell -NoProfile -Command "& { cmd /c \"\"%PY_EXE%\" tools\\clang\\scripts\\update.py 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
      ) else if "%DEBUG_MODE%"=="2" (
        call "%PY_EXE%" tools\clang\scripts\update.py >> "%LOG_FILE%" 2>&1
      ) else (
        call "%PY_EXE%" tools\clang\scripts\update.py
      )
      if errorlevel 1 (
        popd >nul
        echo ERROR: tools\clang\scripts\update.py failed.
        popd
        exit /b 1
      )
    )
    set "VCVARS_BAT=!vs2022_install!\VC\Auxiliary\Build\vcvars64.bat"
    if not exist "!VCVARS_BAT!" (
      popd >nul
      echo ERROR: vcvars64.bat not found: !VCVARS_BAT!
      popd
      exit /b 1
    )
    if not exist "out\Default\gn.exe" (
      set "GN_BOOTSTRAP_BAT=%REPO_ROOT%\.local-bin\run_gn_bootstrap.bat"
      (
        echo @echo off
        if defined WINSDK_VER (
          echo call "!VCVARS_BAT!" -winsdk=!WINSDK_VER! ^>nul
        ) else (
          echo call "!VCVARS_BAT!" ^>nul
        )
        echo if errorlevel 1 exit /b %%errorlevel%%
        echo set DEPOT_TOOLS_WIN_TOOLCHAIN=0
        echo "%PY_EXE%" tools\gn\bootstrap\bootstrap.py -o out\Default\gn.exe --skip-generate-buildfiles
        echo exit /b %%errorlevel%%
      ) > "!GN_BOOTSTRAP_BAT!"
      if "%DEBUG_MODE%"=="1" (
        powershell -NoProfile -Command "& { cmd /c \"\"!GN_BOOTSTRAP_BAT!\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
      ) else if "%DEBUG_MODE%"=="2" (
        call "!GN_BOOTSTRAP_BAT!" >> "%LOG_FILE%" 2>&1
      ) else (
        call "!GN_BOOTSTRAP_BAT!"
      )
      if errorlevel 1 (
        popd >nul
        echo ERROR: GN bootstrap failed.
        popd
        exit /b 1
      )
    )
    set "GN_GEN_BAT=%REPO_ROOT%\.local-bin\run_gn_gen.bat"
    (
      echo @echo off
      if defined WINSDK_VER (
        echo call "!VCVARS_BAT!" -winsdk=!WINSDK_VER! ^>nul
      ) else (
        echo call "!VCVARS_BAT!" ^>nul
      )
      echo if errorlevel 1 exit /b %%errorlevel%%
      echo set DEPOT_TOOLS_WIN_TOOLCHAIN=0
      echo out\Default\gn.exe gen out\Default --fail-on-unused-args
      echo exit /b %%errorlevel%%
    ) > "!GN_GEN_BAT!"
    if "%DEBUG_MODE%"=="1" (
      powershell -NoProfile -Command "& { cmd /c \"\"!GN_GEN_BAT!\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
    ) else if "%DEBUG_MODE%"=="2" (
      call "!GN_GEN_BAT!" >> "%LOG_FILE%" 2>&1
    ) else (
      call "!GN_GEN_BAT!"
    )
    if errorlevel 1 (
      popd >nul
      echo ERROR: gn gen failed.
      popd
      exit /b 1
    )
    popd >nul
  )
  if not exist "build\src\buildtools\win\gn.exe" (
    if exist "build\src\out\Default\gn.exe" (
      if not exist "build\src\buildtools\win" mkdir "build\src\buildtools\win"
      copy /Y "build\src\out\Default\gn.exe" "build\src\buildtools\win\gn.exe" >nul
      if errorlevel 1 (
        echo ERROR: Failed to copy out\Default\gn.exe to buildtools\win\gn.exe
        popd
        exit /b 1
      )
      echo INFO: synced buildtools\win\gn.exe from out\Default\gn.exe
    )
  )
  if not exist "build\src\buildtools\win\gn.exe" (
    echo ERROR: buildtools\win\gn.exe is missing. Please run with --step 2 to bootstrap GN first.
    popd
    exit /b 1
  )
  echo INFO: Ensuring local patch set on existing source tree...
  if "%DEBUG_MODE%"=="1" (
    powershell -NoProfile -Command "& { cmd /c \"\"%PY_EXE%\" \"%REPO_ROOT%\\devutils\\apply_local_patches.py\" --repo-root \"%REPO_ROOT%\" --source-tree \"%REPO_ROOT%\\build\\src\" 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
  ) else if "%DEBUG_MODE%"=="2" (
    call "%PY_EXE%" "%REPO_ROOT%\devutils\apply_local_patches.py" --repo-root "%REPO_ROOT%" --source-tree "%REPO_ROOT%\build\src" >> "%LOG_FILE%" 2>&1
  ) else (
    call "%PY_EXE%" "%REPO_ROOT%\devutils\apply_local_patches.py" --repo-root "%REPO_ROOT%" --source-tree "%REPO_ROOT%\build\src"
  )
  if errorlevel 1 (
    echo ERROR: local patch ensure failed.
    popd
    exit /b 1
  )
  echo [2/3] Build Chromium...
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP2_START=%%i"
  set "PREV__CL=!_CL_!"
  set "_CL_=%CL_APPEND_FLAGS%"
  set "BUILD_ARGS=--ci -j %THREADS%"
  if "%WITH_INSTALLER%"=="1" set "BUILD_ARGS=!BUILD_ARGS! --with-installer"
  if "%DEBUG_MODE%"=="1" (
    powershell -NoProfile -Command "& { cmd /c \"\"%PY_EXE%\" build.py !BUILD_ARGS! 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
  ) else if "%DEBUG_MODE%"=="2" (
    call "%PY_EXE%" build.py !BUILD_ARGS! >> "%LOG_FILE%" 2>&1
  ) else (
    call "%PY_EXE%" build.py !BUILD_ARGS!
  )
  set "BUILD_RC=!ERRORLEVEL!"
  set "_CL_=!PREV__CL!"
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP2_END=%%i"
  if not defined STEP2_START set "STEP2_START=0"
  if not defined STEP2_END set "STEP2_END=!STEP2_START!"
  set /a STEP2_SEC=!STEP2_END!-!STEP2_START!
  if !STEP2_SEC! LSS 0 set "STEP2_SEC=0"
  for /f "usebackq delims=" %%i in (`%PY_CMD% -c "s=int('!STEP2_SEC!'); h=s//3600; m=(s%%3600)//60; ss=s%%60; print(f'{h}h {m}m {ss}s, total {s}s')"` ) do set "STEP2_FMT=%%i"
  if not "!BUILD_RC!"=="0" (
    echo [Timing] Step 2 Build ^(failed^): !STEP2_FMT!
    >> "%LOG_FILE%" echo [Timing] Step 2 Build ^(failed^): !STEP2_FMT!
    echo ERROR: build.py failed.
    popd
    exit /b 1
  )
  echo [Timing] Step 2 Build: !STEP2_FMT!
  >> "%LOG_FILE%" echo [Timing] Step 2 Build: !STEP2_FMT!
) else (
  echo [2/3] Skipped by --step %START_STEP%
)

echo [3/3] Package...
for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP3_START=%%i"
set "PACKAGE_ARGS="
if "%BUILD_VB_ASSETS%"=="1" set "PACKAGE_ARGS=--build-vb-assets"
if "%WITH_INSTALLER%"=="1" set "PACKAGE_ARGS=!PACKAGE_ARGS! --with-installer"
if "%DEBUG_MODE%"=="1" (
  powershell -NoProfile -Command "& { cmd /c \"\"%PY_EXE%\" package.py !PACKAGE_ARGS! 2^>^&1\" | ForEach-Object { $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false)) }; exit $LASTEXITCODE }"
) else if "%DEBUG_MODE%"=="2" (
  call "%PY_EXE%" package.py !PACKAGE_ARGS! >> "%LOG_FILE%" 2>&1
) else (
  call "%PY_EXE%" package.py !PACKAGE_ARGS!
)
set "PKG_RC=%ERRORLEVEL%"
for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "STEP3_END=%%i"
if not defined STEP3_START set "STEP3_START=0"
if not defined STEP3_END set "STEP3_END=%STEP3_START%"
set /a STEP3_SEC=%STEP3_END%-%STEP3_START%
if %STEP3_SEC% LSS 0 set "STEP3_SEC=0"
for /f "usebackq delims=" %%i in (`%PY_CMD% -c "s=int(%STEP3_SEC%); h=s//3600; m=(s%%3600)//60; ss=s%%60; print(f'{h}h {m}m {ss}s, total {s}s')"` ) do set "STEP3_FMT=%%i"
if not "%PKG_RC%"=="0" (
  echo [Timing] Step 3 Package ^(failed^): %STEP3_FMT%
  >> "%LOG_FILE%" echo [Timing] Step 3 Package ^(failed^): %STEP3_FMT%
  echo ERROR: package.py failed.
  popd
  exit /b 1
)
echo [Timing] Step 3 Package: %STEP3_FMT%
>> "%LOG_FILE%" echo [Timing] Step 3 Package: %STEP3_FMT%

for /f "usebackq delims=" %%i in (`%PY_CMD% -c "import time; print(int(time.time()))"`) do set "TOTAL_END=%%i"
if not defined TOTAL_START set "TOTAL_START=0"
if not defined TOTAL_END set "TOTAL_END=%TOTAL_START%"
set /a TOTAL_SEC=%TOTAL_END%-%TOTAL_START%
if %TOTAL_SEC% LSS 0 set "TOTAL_SEC=0"
for /f "usebackq delims=" %%i in (`%PY_CMD% -c "s=int(%TOTAL_SEC%); h=s//3600; m=(s%%3600)//60; ss=s%%60; print(f'{h}h {m}m {ss}s, total {s}s')"` ) do set "TOTAL_FMT=%%i"
echo [Timing] Total: %TOTAL_FMT%
>> "%LOG_FILE%" echo [Timing] Total: %TOTAL_FMT%

echo Done.
popd
exit /b 0


