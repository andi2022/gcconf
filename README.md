# GC Configuration Tool

This tool is meant to let you easily maintain new ATVs (both 32bits and 64bits) to RDM+GC devices.

It will automatically take care of keeping your devices up to date when a new version of GCand/or PoGo is required in the future.
The script will automatically check those versions on every reboot of an ATV and every day on 11:00 PM. If the versions have changed, it will download the corresponding APKs from your above specified folder and will install them automatically.

Logging and any failure while executing script is logged to /data/local/tmp/gcconf.log

# NGINX Setup

Setup a internal server block with autoindex to be able to download the files for update. By using the internal IP address of the server, it will only be accessible to devices on the same network.
```
server {
    listen 8099;
    server_name 192.168.1.2;

    location / {
        root /var/www/html/gcconf;
        autoindex on;
    }
}
```
***OPTIONAL BUT HIGHLY RECOMMANDED :***
The script allows you to add an `authUser` and `authPass`. Those user and passwords will be used if basic auth has been enabled on your directory. 
Please remember this directory contains important information such as your GC API key or RDM auth.
Refer to this documentation on how to enable basic auth for nginx : https://ubiq.co/tech-blog/how-to-password-protect-directory-in-nginx/


The directory should contain the following files :

- The APK of the latest version of GC
- The APK of the 32bits version of PoGo matching your version of GC
- The APK of the 64bits version of PoGo matching your version of GC
- The GC config file (to be described hereunder)
- A version file (to be described hereunder)

Hers is a typical example of directory content :

```
com.gocheats.launcher_v2.0.296.apk
pokemongo_arm64-v8a_0.275.1.apk
pokemongo_armeabi-v7a_0.275.1.apk
config.json
versions
```
Please note the naming convention for the different files, this is important and shouldn't be changed.

Here is the content of the `config.json` file :

```
{
    "api_key": "<your_gc_api_key>",
    "device_name": "dummy",
    "device_configuration_manager_url": "http://<dcm_url>"
}
```
Please note that `"device_name":"dummy"` should not be changed. The script will automatically replace this dummy value with the one defined below.

Here is the content of the `versions` file:
```
pogo=0.275.1
gocheats=2.0.296
```
The script will automatically check those versions. If the versions have changed, it will download the corresponding APKs from your above specified folder and will install them automatically.
The script run after every reboot or with the cron job at 11:00 PM.
# Installation
 - This setup assumes the device has been imaged and rooted already.
 - Connecting to the device using ADB `adb connect xxx.xxx.xxx.xxx` where the X's are replaced with the device's IP address.
 - Using the following commands to create the gcconf_download and gocheats.sh files
   - Change the `url`, `authUser`, and `authPass` to the values used for NGINX
   - Change `DeviceName` to the name you want on this device
   - Change `TimeZone` to your corresponding  TimeZone like Europe/Zurich (Supported timezone list: https://gist.github.com/mtrung/a3f7caaa7e674ac7e6c4)
```
adb shell 
su -c 'file='/data/local/gcconf_download' && \
mount -o remount,rw /system && \
touch $file && \
echo url=https://mydownloadfolder.com > $file && \
echo authUser='' >> $file && \
echo authPass='' >> $file && \
echo DeviceName > /data/local/initDName && \
/system/bin/curl -L -o /system/bin/gocheats.sh -k -s https://raw.githubusercontent.com/andi2022/gcconf/master/gocheats.sh && \
setprop persist.sys.timezone "TimeZone" && \
chmod +x /system/bin/gocheats.sh && \
/system/bin/gocheats.sh -ig'
```
 - If the script finishes successfuly and the device reboots, you can `adb disconnect` from it.
# Remove gcconf
If you will remove gcconf you need to delete the following files. For some files you need to mount the volume with read / write.
```
/data/local/gcconf_download
/data/local/gcconf_versions
/data/local/tmp/config.json
/data/local/tmp/gcconf.log
/sdcard/Download/gocheats.apk
/sdcard/Download/pogo.apk
/system/bin/gocheats.sh
/system/bin/gocheats_new.sh
/system/bin/ping_test.sh
/system/etc/crontabs/root
/system/etc/init.d/55cron
/system/etc/init.d/55gocheats
```
This will help to remove gcconf from your device.
```
adb shell
su -c 'mount -o remount,rw /system && \
mount -o remount,rw /system/etc/init.d || true && \
mount -o remount,rw /system/etc/crontabs || true && \
rm -f /data/local/gcconf_download && \
rm -f /data/local/gcconf_versions && \
rm -f /data/local/tmp/config.json && \
rm -f /data/local/tmp/gcconf.log && \
rm -f /sdcard/Download/gocheats.apk && \
rm -f /sdcard/Download/pogo.apk && \
rm -f /system/bin/gocheats.sh && \
rm -f /system/bin/gocheats_new.sh && \
rm -f /system/bin/ping_test.sh && \
rm -f /system/etc/crontabs/root && \
rm -f /system/etc/init.d/55cron && \
rm -f /system/etc/init.d/55gocheats && \
mount -o remount,ro /system'
```