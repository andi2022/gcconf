# Atlas Configuration Tool

This tool is meant to let you easily maintain new ATVs (both 32bits and 64bits) to RDM+Atlas devices.

It will automatically take care of keeping your devices up to date when a new version of Atlas and/or PoGo is required in the future.
The script will automatically check those versions on every reboot of an ATV. If the versions have changed, it will download the corresponding APKs from your above specified folder and will install them automatically.

Logging and any failure while executing script is logged to /sdcard/aconf.log

# NGINX Setup

Setup a internal server block with autoindex to be able to download the files for update. By using the internal IP address of the server, it will only be accessible to devices on the same network.
```
server {
    listen 8099;
    server_name 192.168.1.2;

    location / {
        root /var/www/html/atlas;
        autoindex on;
    }
}
```
***OPTIONAL BUT HIGHLY RECOMMANDED :***
The script allows you to add an `authUser` and `authPass`. Those user and passwords will be used if basic auth has been enabled on your directory. 
Please remember this directory contains important information such as your Atlas token or RDM auth.
Refer to this documentation on how to enable basic auth for nginx : https://ubiq.co/tech-blog/how-to-password-protect-directory-in-nginx/


The directory should contain the following files :

- The APK of the latest version of Atlas
- The APK of the 32bits version of PoGo matching your version of Atlas
- The APK of the 64bits version of PoGo matching your version of Atlas
- The Atlas config file (to be described hereunder)

Hers is a typical example of directory content :

```
PokemodAtlas-Public-v22050101.apk
pokemongo_arm64-v8a_0.235.0.apk
pokemongo_armeabi-v7a_0.235.0.apk
atlas_config.json
versions
```
Please note the naming convention for the different files, this is important and shouldn't be changed.

Here is the content of the `atlas_config.json` file :

```
{
        "authBearer":"YOUR_RDM_SECRET",
        "deviceAuthToken":"YOUR_ATLAS_AUTH_TOKEN",
        "deviceName":"dummy",
        "email":"YOUR_ATLAS_REGISTRATION_EMAIL",
        "rdmUrl":"http(s)://YOUR_RDM_URL:9001",
        "runOnBoot":true
}
```
Please note that `"deviceName":"dummy"` should not be changed. The script will automatically replace this dummy value with the one defined below.

Here is the content of the `versions` file:
```
pogo=0.243.0
atlas=v22071801
```
# Installation
 - This setup assumes the device has been imaged and rooted already.
 - Connecting to the device using ADB `adb connect xxx.xxx.xxx.xxx` where the X's are replaced with the device's IP address.
 - Using the following commands to create the aconf_download and atlas.sh files
   - Change the `url`, `authUser`, and `authPass` to the values used for NGINX
   - Change `DeviceName` to the name you want on this device
```
adb shell 
su -c 'file='/data/local/aconf_download' && \
mount -o remount,rw /system && \
touch $file && \
echo url=https://mydownloadfolder.com > $file && \
echo authUser='' >> $file && \
echo authPass='' >> $file && \
echo DeviceName > /data/local/initDName && \
/system/bin/curl -L -o /system/bin/atlas.sh -k -s https://raw.githubusercontent.com/Kneckter/aconf-rdm/master/atlas.sh && \
chmod +x /system/bin/atlas.sh && \
/system/bin/atlas.sh -ia'
```
