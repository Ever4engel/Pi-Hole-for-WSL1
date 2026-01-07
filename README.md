# PH4WSL1.cmd &nbsp;· &nbsp;Pi-hole for Windows
<img alt="image" src="https://github.com/user-attachments/assets/641ac411-8f1c-4315-92dc-5e22987192ac" width="60%" height="60%" />
<p>&nbsp;</p>

`PH4WSL1.cmd` is an install script to help [Pi-hole](https://github.com/pi-hole) run semi-natively under Windows 10/11 and Server 2019/2022 by leveraging the Windows Subsystem for Linux, renamed later to WSL1.  Because WSL1 does not require a hypervisor and full Linux kernel it's the most lightweight way to run Pi-hole on Windows.  Pi-hole and associated Linux binaries are visible in Task Manager right alongside your Windows apps.

Pi-hole for Windows can be used to block ads and encrypt DNS queries for your local Windows PC or entire network.  If you use it to serve DNS for your entire network, it's **highly** recommended you install a second Pi-hole instance in case your Windows PCs need to reboot for any reason. 

 - Brief [walk-through video](https://youtu.be/keDtJwK65Dw) of the install process on YouTube

## Latest Updates for 2026-01-06

 - Rebased on Debian 13 (Trixie)
 - Refactored script for improved readability/maintainability
 - Minor bugfixes

## Latest Updates for 2025-02-19

 - Updated for Pi-hole v6
 - Integrated [**Unbound DNS Resolver**](https://www.nlnetlabs.nl/projects/unbound/about) and set the default Pi-hole configuration to use encrypted DNS.
 - Updated to Debian 12
 - Fixes for Windows 11 compatibility 
 - Added links in the install folder for ``Pi-hole System Update.cmd``, ``Pi-hole Gravity Update.cmd``, and ``Pi-hole Web Admin.cmd`` 
 - Debian updates regularly with [unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades) 

# Installation Instructions

<h4>Option 1: Download and run the installer</h4>
<ol>
  <li>Download the installer: <a href="https://github.com/DesktopECHO/Pi-Hole-for-WSL1/raw/master/PH4WSL1.cmd"><strong>PH4WSL1.cmd</strong></a></li>
  <li>Right-click the file and select <strong>"Run as Administrator."</strong></li>
</ol>

<h4>Option 2: One-Liner (Run from an elevated PowerShell console)</h4>
<pre><code>PowerShell -C "irm https://github.com/DesktopECHO/Pi-Hole-for-WSL1/raw/master/PH4WSL1.cmd -OutFile $env:TEMP\PH4WSL1.cmd; & $env:TEMP\PH4WSL1.cmd"</code></pre>

Download and configuration steps complete in 2-15 minutes, depending on your hardware and antivirus solution.  If Windows Defender is active the installation will take longer.  Some users have reported issues with [other antivirus products](https://github.com/DesktopECHO/Pi-Hole-for-WSL1/issues/14) during installation.

## This script performs the following steps:

1. Enable WSL1 and install a Debian-supplied image from [**salsa.debian.org**](https://salsa.debian.org/debian/WSL/-/raw/master/x64/install.tar.gz) 
2. Download the [**LxRunOffline**](https://github.com/DDoSolitary/LxRunOffline) distro manager and install Debian 13 (Trixie) in WSL1
3. Run the [official installer](https://github.com/pi-hole/pi-hole/#one-step-automated-install) from Pi-hole©
4. Create shim so Pi-hole gets the expected output from ``/bin/ss`` along with other fix-ups for WSL1 compatibility.
5. Add exceptions to Windows Firewall for DNS and the Pi-hole admin page

## Note for auto-starting Pi-hole on Windows 
  After the install completes, the Scheduled Task **needs to be configured** for auto-start at boot (before logon).  
   1. Open Windows Task Scheduler (taskschd.msc) and right-click the **Pi-hole for Windows** task, click edit.  
   2. On the *General* tab, place a checkmark next to both **Run whether user is logged on or not** and **Hidden**  
   3. On the *Conditions* tab, un-check the option **Start the task only if the computer is on AC power**

# Differences/limitations compared with upstream:

  - DHCP Server is not supported and is disabled in the Pi-hole Web UI.
  - Clients do not auto-disover in the `Clients` tab, but the clients/groups functionality _does_ work.  If you decide to leverage clients/groups you'll need to enter your clients manually.
  - By default, `PH4WSL1.cmd` is set to listen on _*all*_ interfaces.  The `interfaces` tab and related options have been removed as a result.  If you want to limit Pi-hole's visability, use Windows Firewall rules instead. 
  
# Additional Info

  * IPv6 DNS now works in addition to IPv4.

  * Default location for Pi-hole install is `C:\Program Files\Pi-hole`.  This folder contains utilities to update or modify your Pi-hole:
     - `Pi-hole System Update`    🠞  [_pihole -up_](https://docs.pi-hole.net/core/pihole-command/#update)
     - `Pi-hole Configuration`    🠞  [_pihole -r_](https://docs.pi-hole.net/core/pihole-command/#reconfigure)
     - `Pi-hole Gravity Update`  🠞  [_pihole updateGravity_](https://docs.pi-hole.net/core/pihole-command/#gravity)

* To completely uninstall Pi-Hole, open the Pi-hole install folder in Windows Explorer.  Right-click ``Pi-hole Uninstall.cmd`` and click **Run As Administrator.**  If you are uninstalling or reinstalling and need to retain your Pi-hole's configuration, export it first via the Pi-hole [Teleport](https://docs.pi-hole.net/core/pihole-command/?h=teleport#teleport) feature located in the web interface. 

# Screenshots

## Installer run
![image](https://user-images.githubusercontent.com/33142753/193498416-41fea4c2-ef62-4286-8b20-aaba77e03720.png)


## Install Complete

![Install Complete](https://user-images.githubusercontent.com/33142753/101309494-f4151d00-3822-11eb-8521-66a96279add0.PNG)


## Install Folder Contents

![Install Folder](https://user-images.githubusercontent.com/33142753/222502018-d4b57881-3a37-4d5b-b7d5-5d3d1cf576b9.png)

## Note
There is no endorsement or partnership between this page and [**Pi-hole© LLC**](https://pi-hole.net).  They deserve [your support](https://pi-hole.net/donate/) if you find this useful.
