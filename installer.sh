#!/bin/sh

# Launch BSD Installer with fake "installer root"
# Copyright 2004 BSD Installer Project and the FreeSBIE project
# This file is placed under the BSD license.

echo
echo "Launching pfSense Installer..."
echo

/usr/bin/killall syslogd 2>/dev/null 2>&1

sysctl kern.geom.debugflags=16

ln -s /FreeSBIE/tftpdroot /tmp/tftpdroot
echo "Mounting /FreeSBIE/dev..."
mount_devfs devfs /FreeSBIE/dev

echo "Mounting /FreeSBIE/usr..."
MD_LOCAL=`mdconfig -a -t vnode -f /FreeSBIE/uzip/usr.uzip`
mount -r /dev/$MD_LOCAL.uzip /FreeSBIE/usr

echo "Mounting /FreeSBIE/var..."
MD_LOCAL=`mdconfig -a -f /FreeSBIE/uzip/var.uzip`
mount -r /dev/$MD_LOCAL.uzip /FreeSBIE/var

mount -t unionfs /.var /FreeSBIE/var

# Let's access this now to prevent the "RockRidge" message
# during the actual install
ls /FreeSBIE/usr >/dev/null 2>&1
ls /FreeSBIE/var >/dev/null 2>&1

echo Starting backend...
/usr/local/sbin/dfuibe_installer -o /FreeSBIE/ \
	>/tmp/installerconsole.log 2>&1 &

sleep 1

echo Starting NCURSES frontend...
/usr/local/sbin/dfuife_curses

echo
echo
echo
echo
echo
echo
echo
echo
echo "Once the system reboots you will be asked to associate your network"
echo "interfaces as either WAN, LAN or OPT."
echo
echo After assigning network interfaces and rebooting you should be able to
echo browse http://192.168.1.1 on your LAN interface for further configuration.
echo
echo Rebooting in 3 seconds.  CTRL-C to abort.
sleep 1
echo Rebooting in 2 seconds.  CTRL-C to abort.
sleep 1
echo Rebooting in 1 second..  CTRL-C to abort.
sleep 1
echo
echo pfSense is now rebooting.
shutdown -r now