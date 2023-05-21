#!/system/bin/sh
if ping -c1 8.8.8.8 >/dev/null 2>/dev/null || ping -c1 1.1.1.1 >/dev/null 2>/dev/null
then
    echo "`date +%Y-%m-%d_%T` Pinging router was successful." >> /sdcard/aconf.log
else
    echo "`date +%Y-%m-%d_%T` Pinging router failed. Rebooting." >> /sdcard/aconf.log
    reboot
fi
