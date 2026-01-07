@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
@CHCP 65001 > NUL
TITLE Pi-hole for Windows Installer

:: ===========================================================================
:: CONFIGURATION
:: ===========================================================================
SET "DEBIAN_URL=https://salsa.debian.org/debian/WSL/-/raw/cef1a29b4373fa5c69a0cd000dd7941fbdf9e193/x64/install.tar.gz?inline=false"
SET "PREREQ_URL=https://github.com/DesktopECHO/Pi-Hole-for-WSL1/archive/refs/heads/master.zip"
SET "IMG_NAME=Debian.tar.gz"
SET "PORT=60080"

:: ===========================================================================
:: ADMIN CHECK
:: ===========================================================================
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO.
    ECHO You need to run the Pi-hole installer with administrative rights.
    ECHO Is User Account Control enabled?
    PAUSE
    GOTO ENDSCRIPT
)
ECHO Administrator check passed...

:: ===========================================================================
:: WSL CHECK
:: ===========================================================================
POWERSHELL -Command "$WSL = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'; if ($WSL.State -eq 'Disabled') {Enable-WindowsOptionalFeature -FeatureName $WSL.FeatureName -Online}"

:INPUTS
CLS
ECHO.-------------------------------- 
ECHO. Pi-hole for Windows v.20260106 
ECHO.-------------------------------- 
ECHO.

:: ===========================================================================
:: INSTALL LOCATION
:: ===========================================================================
SET "PRGP=%PROGRAMFILES%"
SET /P "PRGP=Set Pi-hole install location, or hit enter for default [%PROGRAMFILES%] -> "
:: Remove trailing backslash if present
IF "%PRGP:~-1%"=="\" SET "PRGP=%PRGP:~0,-1%"
SET "INSTALL_DIR=%PRGP%\Pi-hole"

IF EXIST "%INSTALL_DIR%" (
    ECHO.
    ECHO Pi-hole folder already exists, uninstall Pi-hole first.
    PAUSE
    GOTO INPUTS
)

:: Check for existing WSL distro
WSL.EXE -d Pi-hole -e . > "%TEMP%\InstCheck.tmp" 2>NUL
FOR /f %%i in ("%TEMP%\InstCheck.tmp") do set CHKIN=%%~zi
IF "%CHKIN%"=="0" (
    ECHO.
    ECHO Existing Pi-hole installation detected, uninstall Pi-hole first.
    PAUSE
    GOTO INPUTS
)
ECHO.

:: ===========================================================================
:: DOWNLOADS
:: ===========================================================================
IF EXIST "%TEMP%\%IMG_NAME%" DEL "%TEMP%\%IMG_NAME%"
ECHO Downloading Debian 13 (Trixie) from https://salsa.debian.org . . .

:DLIMG
POWERSHELL.EXE -Command "Start-BitsTransfer -Source '%DEBIAN_URL%' -Destination '%TEMP%\%IMG_NAME%'" >NUL 2>&1
IF NOT EXIST "%TEMP%\%IMG_NAME%" GOTO DLIMG

IF NOT EXIST "%INSTALL_DIR%" MKDIR "%INSTALL_DIR%"
PUSHD "%INSTALL_DIR%"
IF NOT EXIST "logs" MKDIR "logs"
IF EXIST PH4WSL1.zip DEL PH4WSL1.zip

ECHO Downloading prerequisite packages . . .
:DLPRQ
POWERSHELL.EXE -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%PREREQ_URL%' -OutFile 'PH4WSL1.zip'" > NUL 2>&1
IF NOT EXIST PH4WSL1.zip GOTO DLPRQ

:: Extract Prerequisites and LXRunOffline
POWERSHELL.EXE -Command "Expand-Archive -Force 'PH4WSL1.zip'; Remove-Item 'PH4WSL1.zip'"
POWERSHELL.EXE -Command "Expand-Archive -Force -Path '.\PH4WSL1\Pi-Hole-for-WSL1-master\LxRunOffline-v3.5.0-33-gbdc6d7d-msvc.zip' -DestinationPath '%TEMP%'; Copy-Item '%TEMP%\LxRunOffline-v3.5.0-33-gbdc6d7d-msvc\LxRunOffline.exe' '%INSTALL_DIR%'"

:: Permissions
FOR /F "usebackq delims=" %%v IN (`PowerShell -Command "whoami"`) DO set "WAI=%%v"
ICACLS "%INSTALL_DIR%" /grant "%WAI%:(CI)(OI)F" > NUL

:: Define Runner Variable for easier calls
SET "GO="%INSTALL_DIR%\LxRunOffline.exe" r -n Pi-hole -c"

:: ===========================================================================
:: GENERATE UNINSTALL SCRIPT
:: ===========================================================================
(
    ECHO @ECHO OFF ^& CLS ^& NET SESSION ^>NUL 2^>^&1
    ECHO IF %%ERRORLEVEL%% == 0 ^(ECHO Pi-hole Uninstaller: Close window to abort or
    ECHO ^)ELSE ^(ECHO Please run uninstaller with admin rights! ^&^& pause ^&^& EXIT^)
    ECHO PAUSE ^& ECHO. ^& ECHO Uninstalling Pi-hole . . .
    ECHO COPY /Y "%INSTALL_DIR%\LxRunOffline.exe" "%TEMP%" ^> NUL 2^>^&1
    ECHO SCHTASKS /Delete /TN:"Pi-hole for Windows" /F ^> NUL 2^>^&1
    ECHO NetSH AdvFirewall Firewall del rule name="Pi-hole DNS Server"
    ECHO NetSH AdvFirewall Firewall del rule name="Pi-hole SSH"
    ECHO %INSTALL_DIR:~0,2% ^& CD "%INSTALL_DIR%" ^& WSLCONFIG /T Pi-hole ^> NUL 2^>^&1
    ECHO "%TEMP%\LxRunOffline.exe" ur -n Pi-hole ^> NUL 2^>^&1 ^& CD ..
    ECHO ECHO. ^& ECHO Uninstall Complete!
    ECHO START /MIN "Uninstall" "CMD.EXE" /C RD /S /Q "%INSTALL_DIR%"
) > "%INSTALL_DIR%\Pi-hole Uninstall.cmd"

:: ===========================================================================
:: INSTALL DISTRO
:: ===========================================================================
ECHO|SET /p="Installing Debian . . ."
START /WAIT /MIN "Installing Debian, one moment please..." "LxRunOffline.exe" "i" "-n" "Pi-hole" "-f" "%TEMP%\%IMG_NAME%" "-d" "."

:: Firewall Rules
NetSH AdvFirewall Firewall add rule name="Pi-hole DNS Server" dir=in action=allow program="%INSTALL_DIR%\rootfs\usr\bin\pihole-ftl" enable=yes > NUL
NetSH AdvFirewall Firewall add rule name="Pi-hole SSH"        dir=in action=allow program="%INSTALL_DIR%\rootfs\usr\sbin\sshd"      enable=yes > NUL

:: Debian packages
ECHO.
ECHO Please wait a few minutes for package installer . . .
FOR /f "tokens=2" %%a in ('nslookup . 2^>nul ^| findstr /C:"Address:"') do (set "DNS=nameserver %%a")
%GO% "echo -e '[network]\ngenerateResolvConf = false\n' > /etc/wsl.conf"
%GO% "dpkg --purge --force-all libdevmapper1.02.1 libargon2-1 dmsetup libsystemd-shared systemd systemd-sysv libsystemd-shared systemd libpam-systemd udev 2> /dev/null" > NUL
%GO% "rm -rf /etc/apt/apt.conf.d/20snapd.conf /etc/rc2.d/S01whoopsie /etc/init.d/console-setup.sh /etc/init.d/udev ; echo 'echo N 2' > /usr/sbin/runlevel ; chmod +x /usr/sbin/runlevel ; dpkg-divert --local --rename --add /sbin/initctl ; ln -fs /bin/true /sbin/initctl ; echo 'exit 0' > /usr/sbin/policy-rc.d ; chmod +x /usr/sbin/policy-rc.d" > NUL
%GO% "RUNLEVEL=0 dpkg -i --force-all ./PH4WSL1/Pi-Hole-for-WSL1-master/deb/*.deb 2> /dev/null" > "%INSTALL_DIR%\logs\Pi-hole package install.log"

:: Configure Setup
%GO% "cp ./PH4WSL1/Pi-Hole-for-WSL1-master/ss /.ss ; chmod +x /.ss ; cp /.ss /bin/ss ; cp ./PH4WSL1/Pi-Hole-for-WSL1-master/pi-hole.conf /etc/unbound/unbound.conf.d/pi-hole.conf"
%GO% "mkdir /etc/pihole ; touch /etc/network/interfaces ; echo '13.107.4.52 www.msftconnecttest.com' > /etc/pihole/custom.list ; echo '131.107.255.255 dns.msftncsi.com' >> /etc/pihole/custom.list"

:: Setup Variables
%GO% "echo PIHOLE_DNS_1=127.0.0.1#5335 >  /etc/pihole/setupVars.conf"
%GO% "echo BLOCKING_ENABLED=true       >> /etc/pihole/setupVars.conf"
%GO% "echo QUERY_LOGGING=true          >> /etc/pihole/setupVars.conf"
%GO% "echo DNSMASQ_LISTENING=all       >> /etc/pihole/setupVars.conf"
%GO% "echo WEBPASSWORD=                >> /etc/pihole/setupVars.conf"

:: Install Pi-hole
START /MIN "Gravity Tempfile Monitor" %GO% "while : ; do sed -i '/gravityTEMPfile=/c\gravityTEMPfile=\/run\/shm\/gravity\/gravity-temp' /opt/pihole/gravity.sh ; clear ; sleep .2 ; done"
for /f "tokens=2" %%a in ('nslookup install.pi-hole.net 2^>nul ^| findstr /r "^[ ]*Address:.*[0-9]"') do set "IPN=%%a"
%GO% "rm -f /etc/resolv.conf ; echo nameserver 9.9.9.9 > /etc/resolv.conf ; mkdir -p /run/shm/gravity ; chmod 777 /run/shm/gravity ; curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended ; update-rc.d pihole-FTL defaults"

:: FixUp: Debug log parsing on WSL1
%GO% "sed -i 's* -f 3* -f 4*g' /opt/pihole/piholeDebug.sh"
%GO% "sed -i 's*-I \"${PIHOLE_INTERFACE}\"* *g' /opt/pihole/piholeDebug.sh"
%GO% "hn=`hostname` ; echo cname=$hn.gravitysync,$hn > /etc/dnsmasq.d/05-pihole-custom-cname.conf"
%GO% "sed -i 's/#UseDNS no/UseDNS no/g' /etc/ssh/sshd_config ; sed -i 's*#Port 22*Port 5322*g' /etc/ssh/sshd_config ; sed -i 's*#PasswordAuthentication yes*PasswordAuthentication no*g' /etc/ssh/sshd_config"
%GO% "echo '<meta http-equiv=refresh content=0;url=/admin>' > /var/www/html/index.html"

:: ===========================================================================
:: GENERATE LAUNCHER SCRIPT
:: ===========================================================================
(
    ECHO @WSLCONFIG /T Pi-hole ^& @ECHO [Pi-Hole Launcher]
    ECHO @%GO% "cp /.ss /bin/ss ; apt clean all"
    ECHO @%GO% "sed -i '/<!-- Interfaces -->/,/<!-- Network -->/{ /<!-- Network -->/!d }' /var/www/html/admin/scripts/lua/sidebar.lp"
    ECHO @%GO% "sed -i '/dns.listeningMode/,/data-configkeys=/d'  /var/www/html/admin/settings-dns.lp"
    ECHO @%GO% "sed -i '/settings\/dhcp/,/<\/li>/d' /var/www/html/admin/scripts/lua/sidebar.lp"
    ECHO @%GO% "sed -i '/gravityTEMPfile=/c\gravityTEMPfile=\/run\/shm/\gravity\/gravity-temp' /opt/pihole/gravity.sh"
    ECHO @%GO% "pihole-FTL --config dns.reply.host.IPv4 $(ip route get 9.9.9.9 | grep -oP 'src \K\S+') > /dev/null"
    ECHO @%GO% "pihole-FTL --config dns.reply.host.force4 true > /dev/null"
    ECHO @%GO% "pihole-FTL --config database.network.parseARPcache false > /dev/null"
    ECHO @%GO% "rm -f /etc/resolv.conf ; echo 'nameserver 127.0.0.1' > /etc/resolv.conf ; mkdir -p /run/shm/gravity ; chown pihole:pihole /run/shm/gravity ; chmod 775 /run/shm/gravity ; for rc_service in /etc/rc2.d/S*; do [[ -e $rc_service ]] && $rc_service start ; done ; sleep 3"
    ECHO @EXIT
) > "%INSTALL_DIR%\Pi-hole Launcher.cmd"

:: ===========================================================================
:: GENERATE MAINTENANCE SCRIPTS
:: ===========================================================================
(
    ECHO @WSLCONFIG /T Pi-hole
    ECHO @START /MIN "Gravity Tempfile Monitor" %GO% "while [ ! -f /tmp/done ] ; do sed -i '/gravityTEMPfile=/c\gravityTEMPfile=\/run\/shm/\gravity/\gravity-temp' /opt/pihole/gravity.sh ; clear ; sleep .2 ; done"
    ECHO @%GO% "mkdir -p /run/shm/gravity ; chown pihole:pihole /run/shm/gravity ; chmod 775 /run/shm/gravity ; echo nameserver 9.9.9.9 > /etc/resolv.conf ; pihole repair ; touch /tmp/done"
    ECHO @%GO% "sed -i 's* -f 3* -f 4*g' /opt/pihole/piholeDebug.sh"
    ECHO @%GO% "sed -i 's*-I \"${PIHOLE_INTERFACE}\"* *g' /opt/pihole/piholeDebug.sh"
    ECHO @START /WAIT /MIN "Pi-hole Init" "%INSTALL_DIR%\Pi-hole Launcher.cmd"
    ECHO @START http://%%COMPUTERNAME%%:%PORT%/admin
) > "%INSTALL_DIR%\Pi-hole Repair.cmd"

ECHO @START http://%%COMPUTERNAME%%:%PORT%/admin > "%INSTALL_DIR%\Pi-hole Web Admin.cmd"

POWERSHELL.EXE -Command "(Get-Content -path '%INSTALL_DIR%\Pi-hole Repair.cmd' -Raw ) -replace 'repair','updatePihole 2>/dev/null'" > "%INSTALL_DIR%\Pi-hole System Update.cmd"

(
    ECHO @%GO% "sed -i '/gravityTEMPfile=/c\gravityTEMPfile=\/run\/shm/\gravity/\gravity-temp' /opt/pihole/gravity.sh ; mkdir -p /run/shm/gravity ; chown pihole:pihole /run/shm/gravity ; chmod 775 /run/shm/gravity ; echo nameserver 9.9.9.9 > /etc/resolv.conf ; pihole updateGravity ; echo ; read -p 'Hit [Enter] to close this window...'"
) > "%INSTALL_DIR%\Pi-hole Gravity Update.cmd"

:: ===========================================================================
:: FINAL CONFIG AND STARTUP
:: ===========================================================================
START /WAIT /MIN "Pi-hole Launcher" "%INSTALL_DIR%\Pi-hole Launcher.cmd"

(
    ECHO.Input Specifications:
    ECHO. 
    ECHO. Location: %INSTALL_DIR%
    ECHO.     Port: %PORT%
    ECHO.     Temp: %TEMP%
    ECHO.
) > "%INSTALL_DIR%\logs\Pi-hole install settings.log"
DIR "%INSTALL_DIR%" >> "%INSTALL_DIR%\logs\Pi-hole install settings.log"

:: Update pihole.toml
%GO% "pihole-FTL --config database.useWAL false >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config webserver.port '60080o,60443os,[::]:60080o,[::]:60443os' >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config ntp.ipv4.active false >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config ntp.ipv6.active false >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config ntp.sync.rtc.utc false >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config ntp.sync.active false >> /tmp/GO.log 2>&1"
%GO% "pihole-FTL --config dns.listeningMode 'NONE' >> /tmp/GO.log 2>&1"

:: Cleanup and Password
RD /S /Q "%INSTALL_DIR%\PH4WSL1"
%GO% "echo ; echo -n 'Pi-hole Web Admin, ' ; pihole setpassword"

:: Task Scheduler
SET "TASK_TRG=%INSTALL_DIR%\Pi-hole Launcher.cmd"
ECHO.
SCHTASKS /CREATE /RU "%WAI%" /RL HIGHEST /SC ONSTART /TN "Pi-hole for Windows" /TR "'%TASK_TRG%'" /F

ECHO.
ECHO   *NOTE* Additional configuration steps are required if you want
ECHO          Pi-hole to run automatically at Windows start-up.
ECHO.      
ECHO        - Open Windows Task Scheduler (taskschd.msc)
ECHO          Right-click the task "Pi-hole for Windows" and click "Edit"
ECHO.          
ECHO        - On the General tab, place a checkmark next to both
ECHO          "Run whether user is logged on or not" and "Hidden"
ECHO.          
ECHO        - On the Conditions tab, un-check the option
ECHO          "Start the task only if the computer is on AC power"
ECHO.
POPD
%GO% "echo Install complete!  Devices on your network reach this Pi-hole via IP $(ip route get 9.9.9.9 | grep -oP 'src \K\S+') ; echo ' '"
PAUSE
START http://%COMPUTERNAME%:%PORT%/admin
:ENDSCRIPT
