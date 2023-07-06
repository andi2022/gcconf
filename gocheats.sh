#!/system/bin/sh
# version 1.5.0

#Version checks
Ver55gocheats="1.0"
Ver55cron="1.1"

export ANDROID_DATA=/data
export ANDROID_ROOT=/system

#Create logfile
if [ ! -e /data/local/tmp/gcconf.log ] ;then
    /system/bin/touch /data/local/tmp/gcconf.log
fi

logfile="/data/local/tmp/gcconf.log"
gcconf="/data/local/tmp/config.json"
gcconf_versions="/data/local/gcconf_versions"
[[ -f /data/local/gcconf_download ]] && gcconf_download=$(/system/bin/grep url /data/local/gcconf_download | awk -F "=" '{ print $NF }')
[[ -f /data/local/gcconf_download ]] && gcconf_user=$(/system/bin/grep authUser /data/local/gcconf_download | awk -F "=" '{ print $NF }')
[[ -f /data/local/gcconf_download ]] && gcconf_pass=$(/system/bin/grep authPass /data/local/gcconf_download | awk -F "=" '{ print $NF }')
if [[ -f /data/local/tmp/config.json ]] ;then
    origin=$(/system/bin/cat $gcconf | /system/bin/tr , '\n' | /system/bin/grep -w 'device_name' | awk -F "\"" '{ print $4 }')
else
    origin=$(/system/bin/cat /data/local/initDName)
fi

# stderr to logfile
exec 2>> $logfile

# add gocheats.sh command to log
echo "" >> $logfile
echo "`date +%Y-%m-%d_%T` ## Executing $(basename $0) $@" >> $logfile


########## Functions

reboot_device(){
    echo "`date +%Y-%m-%d_%T` Reboot device" >> $logfile
    sleep 60
    /system/bin/reboot
}

case "$(uname -m)" in
    aarch64) arch="arm64-v8a";;
    armv8l)  arch="armeabi-v7a";;
esac

install_gocheats(){
    # install 55gocheats
    mount -o remount,rw /system
    mount -o remount,rw /system/etc/init.d || true
	until /system/bin/curl -s -k -L --fail --show-error -o  /system/etc/init.d/55gocheats https://raw.githubusercontent.com/andi2022/gcconf/master/55gocheats || { echo "`date +%Y-%m-%d_%T` Download 55gcconf failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
    done
    chmod +x /system/etc/init.d/55gocheats
    echo "`date +%Y-%m-%d_%T` 55gocheats installed, from master" >> $logfile

    # install 55cron
    until /system/bin/curl -s -k -L --fail --show-error -o  /system/etc/init.d/55cron https://raw.githubusercontent.com/andi2022/gcconf/master/55cron || { echo "`date +%Y-%m-%d_%T` Download 55cron failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
    done
    chmod +x /system/etc/init.d/55cron
    echo "`date +%Y-%m-%d_%T` 55cron installed, from master" >> $logfile

    # install cron job
    until /system/bin/curl -s -k -L --fail --show-error -o  /system/bin/ping_test.sh https://raw.githubusercontent.com/andi2022/gcconf/master/ping_test.sh || { echo "`date +%Y-%m-%d_%T` Download ping_test.sh failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
    done
    chmod +x /system/bin/ping_test.sh
    mkdir /system/etc/crontabs || true
    touch /system/etc/crontabs/root
    echo "15 * * * * /system/bin/ping_test.sh" > /system/etc/crontabs/root
    echo "0 23 * * * /system/bin/gocheats.sh -ua" >> /system/etc/crontabs/root
	crond -b

    mount -o remount,ro /system

    # Remove any old MAD files
    /system/bin/rm -f 01madbootstrap 42mad 16mad

    # get version
    gcversions=$(/system/bin/grep 'gocheats' $gcconf_versions | /system/bin/grep -v '_' | awk -F "=" '{ print $NF }')

    # download gocheats
    /system/bin/rm -f /sdcard/Download/gocheats.apk
    until $download /sdcard/Download/gocheats.apk $gcconf_download/com.gocheats.launcher_v$gcversions.apk || { echo "`date +%Y-%m-%d_%T` $download /sdcard/Download/gocheats.apk $gcconf_download/com.gocheats.launcher_v$gcversions.apk" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download gocheats failed, exit script" >> $logfile ; exit 1; } ;do
      sleep 2
    done

    # let us kill pogo as well and clear data
    /system/bin/am force-stop com.nianticlabs.pokemongo
    /system/bin/pm clear com.nianticlabs.pokemongo

    # Install gocheats
    /system/bin/pm install -r /sdcard/Download/gocheats.apk
    /system/bin/rm -f /sdcard/Download/gocheats.apk
    echo "`date +%Y-%m-%d_%T` gocheats installed" >> $logfile

    # Grant su access + settings
    guid="$(dumpsys package com.gocheats.launcher | /system/bin/grep userId | awk -F'=' '{print $2}')"
    magisk --sqlite "DELETE from policies WHERE package_name='com.gocheats.launcher'"
    magisk --sqlite "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES($guid,'com.gocheats.launcher',2,0,1,0)"
    /system/bin/pm grant com.gocheats.launcher android.permission.READ_EXTERNAL_STORAGE
    /system/bin/pm grant com.gocheats.launcher android.permission.WRITE_EXTERNAL_STORAGE
    echo "`date +%Y-%m-%d_%T` gocheats granted su and settings set" >> $logfile

    # download gocheats config file and adjust orgin to rgc setting
    install_config

    # check pogo version else remove+install
    downgrade_pogo

    # start gocheats
    /system/bin/monkey -p com.gocheats.launcher 1
    sleep 15

    # Set for reboot device
    reboot=1
}

install_config(){
    until $download /data/local/tmp/config.json $gcconf_download/config.json || { echo "`date +%Y-%m-%d_%T` $download /data/local/tmp/config.json $gcconf_download/config.json" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download gocheats config file failed, exit script" >> $logfile ; exit 1; } ;do
      sleep 2
    done
    /system/bin/sed -i 's,dummy,'$origin',g' $gcconf
    echo "`date +%Y-%m-%d_%T` gocheats config installed, device_name $origin"  >> $logfile
}

update_all(){
    pinstalled=$(dumpsys package com.nianticlabs.pokemongo | /system/bin/grep versionName | head -n1 | /system/bin/sed 's/ *versionName=//')
    pversions=$(/system/bin/grep 'pogo' $gcconf_versions | /system/bin/grep -v '_' | awk -F "=" '{ print $NF }')
    gcinstalled=$(dumpsys package com.gocheats.launcher | /system/bin/grep versionName | head -n1 | /system/bin/sed 's/ *versionName=//')
    gcversions=$(/system/bin/grep 'gocheats' $gcconf_versions | /system/bin/grep -v '_' | awk -F "=" '{ print $NF }')

    if [[ $pinstalled != $pversions ]] ;then
      echo "`date +%Y-%m-%d_%T` New pogo version detected, $pinstalled=>$pversions" >> $logfile
      /system/bin/rm -f /sdcard/Download/pogo.apk
      until $download /sdcard/Download/pogo.apk $gcconf_download/pokemongo_$arch\_$pversions.apk || { echo "`date +%Y-%m-%d_%T` $download /sdcard/Download/pogo.apk $gcconf_download/pokemongo_$arch\_$pversions.apk" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download pogo failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
      done
      # set pogo to be installed
      pogo_install="install"
    else
     pogo_install="skip"
     echo "`date +%Y-%m-%d_%T` PoGo already on correct version" >> $logfile
    fi

    if [ $gcinstalled != $gcversions ] ;then
      echo "`date +%Y-%m-%d_%T` New gocheats version detected, $gcinstalled=>$gcversions" >> $logfile
      /system/bin/rm -f /sdcard/Download/gocheats.apk
      until $download /sdcard/Download/gocheats.apk $gcconf_download/com.gocheats.launcher_v$gcversions.apk || { echo "`date +%Y-%m-%d_%T` $download /sdcard/Download/gocheats.apk $gcconf_download/com.gocheats.launcher_v$gcversions.apk" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download gocheats failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
      done
      # set gocheats to be installed
      gocheats_install="install"
    else
     gocheats_install="skip"
     echo "`date +%Y-%m-%d_%T` gocheats already on correct version" >> $logfile
    fi

    if [ ! -z "$gocheats_install" ] && [ ! -z "$pogo_install" ] ;then
      echo "`date +%Y-%m-%d_%T` All updates checked and downloaded if needed" >> $logfile
      if [ "$gocheats_install" = "install" ] ;then
        echo "`date +%Y-%m-%d_%T` Updating gocheats" >> $logfile
        # install gocheats
		echo "`date +%Y-%m-%d_%T` Stopped gocheats" >> $logfile
        am force-stop com.gocheats.launcher
        /system/bin/pm install -r /sdcard/Download/gocheats.apk || { echo "`date +%Y-%m-%d_%T` Install gocheats failed, downgrade perhaps? Exit script" >> $logfile ; exit 1; }
        /system/bin/rm -f /sdcard/Download/gocheats.apk
        /system/bin/monkey -p com.gocheats.launcher 1
        echo "`date +%Y-%m-%d_%T` Started gocheats" >> $logfile
        reboot=1
      fi
      if [ "$pogo_install" = "install" ] ;then
        echo "`date +%Y-%m-%d_%T` Updating pogo" >> $logfile
        # install pogo
		echo "`date +%Y-%m-%d_%T` Stopped gocheats + pogo" >> $logfile
        am force-stop com.gocheats.launcher
		am force-stop com.nianticlabs.pokemongo
        /system/bin/pm install -r /sdcard/Download/pogo.apk || { echo "`date +%Y-%m-%d_%T` Install pogo failed, downgrade perhaps? Exit script" >> $logfile ; exit 1; }
        /system/bin/rm -f /sdcard/Download/pogo.apk
        /system/bin/monkey -p com.gocheats.launcher 1
        echo "`date +%Y-%m-%d_%T` Started gocheats" >> $logfile
        reboot=1
      fi
      if [ "$gocheats_install" != "install" ] && [ "$pogo_install" != "install" ] ; then
        echo "`date +%Y-%m-%d_%T` Updates checked, nothing to install" >> $logfile

      fi
    fi
}

downgrade_pogo(){
    pinstalled=$(dumpsys package com.nianticlabs.pokemongo | /system/bin/grep versionName | head -n1 | /system/bin/sed 's/ *versionName=//')
    pversions=$(/system/bin/grep 'pogo' $gcconf_versions | /system/bin/grep -v '_' | awk -F "=" '{ print $NF }')
    if [[ $pinstalled != $pversions ]] ;then
      until $download /sdcard/Download/pogo.apk $gcconf_download/pokemongo_$arch\_$pversions.apk || { echo "`date +%Y-%m-%d_%T` $download /sdcard/Download/pogo.apk $gcconf_download/pokemongo_$arch\_$pversions.apk" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download pogo failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
      done
      /system/bin/pm uninstall com.nianticlabs.pokemongo
      /system/bin/pm install -r /sdcard/Download/pogo.apk
      /system/bin/rm -f /sdcard/Download/pogo.apk
      echo "`date +%Y-%m-%d_%T` PoGo removed and installed, now $pversions" >> $logfile
    else
      echo "`date +%Y-%m-%d_%T` pogo version correct, proceed" >> $logfile
    fi
}

send_logs(){
if [[ -z $webhook ]] ;then
  echo "`date +%Y-%m-%d_%T` No webhook set in job" >> $logfile
else
  # gcconf log
  curl -S -k -L --fail --show-error -F "payload_json={\"username\": \"aconf log sender\", \"content\": \"gcconf.log for $origin\"}" -F "file1=@$logfile" $webhook &>/dev/null
  # monitor log
  [[ -f /sdcard/atlas_monitor.log ]] && curl -S -k -L --fail --show-error -F "payload_json={\"username\": \"aconf log sender\", \"content\": \"atlas_monitor.log for $origin\"}" -F "file1=@/sdcard/atlas_monitor.log" $webhook &>/dev/null
  # gocheats log
  cp /data/local/tmp/gocheats.log /sdcard/gocheats.log
  curl -S -k -L --fail --show-error -F "payload_json={\"username\": \"aconf log sender\", \"content\": \"gocheats.log for $origin\"}" -F "file1=@/sdcard/gocheats.log" $webhook &>/dev/null
  /system/bin/rm /sdcard/gocheats.log
  #logcat
  logcat -d > /sdcard/logcat.txt
  curl -S -k -L --fail --show-error -F "payload_json={\"username\": \"aconf log sender\", \"content\": \"logcat.txt for $origin\"}" -F "file1=@/sdcard/logcat.txt" $webhook &>/dev/null
  /system/bin/rm -f /sdcard/logcat.txt
  echo "`date +%Y-%m-%d_%T` Sending logs to discord" >> $logfile
fi
}

########## Execution

#wait on internet
until ping -c1 8.8.8.8 >/dev/null 2>/dev/null || ping -c1 1.1.1.1 >/dev/null 2>/dev/null; do
    sleep 10
done
echo "`date +%Y-%m-%d_%T` Internet connection available" >> $logfile


#download latest gocheats.sh
if [[ $(basename $0) != "gocheats_new.sh" ]] ;then
    mount -o remount,rw /system
    oldsh=$(head -2 /system/bin/gocheats.sh | /system/bin/grep '# version' | awk '{ print $NF }')
    until /system/bin/curl -s -k -L --fail --show-error -o /system/bin/gocheats_new.sh https://raw.githubusercontent.com/andi2022/gcconf/master/gocheats.sh || { echo "`date +%Y-%m-%d_%T` Download gocheats.sh failed, exit script" >> $logfile ; exit 1; } ;do
        sleep 2
    done
    chmod +x /system/bin/gocheats_new.sh
    newsh=$(head -2 /system/bin/gocheats_new.sh | /system/bin/grep '# version' | awk '{ print $NF }')
    if [[ $oldsh != $newsh ]] ;then
        echo "`date +%Y-%m-%d_%T` gocheats.sh $oldsh=>$newsh, restarting script" >> $logfile
        cp /system/bin/gocheats_new.sh /system/bin/gocheats.sh
        mount -o remount,ro /system
        /system/bin/gocheats_new.sh $@
        exit 1
    fi
fi

# verify download credential file and set download
if [[ ! -f /data/local/gcconf_download ]] ;then
    echo "`date +%Y-%m-%d_%T` File /data/local/gcconf_download not found, exit script" >> $logfile && exit 1
else
    if [[ $gcconf_user == "" ]] ;then
        download="/system/bin/curl -s -k -L --fail --show-error -o"
    else
        download="/system/bin/curl -s -k -L --fail --show-error --user $gcconf_user:$gcconf_pass -o"
    fi
fi

# download latest version file
until $download $gcconf_versions $gcconf_download/versions || { echo "`date +%Y-%m-%d_%T` $download $gcconf_versions $gcconf_download/versions" >> $logfile ; echo "`date +%Y-%m-%d_%T` Download gocheats versions file failed, exit script" >> $logfile ; exit 1; } ;do
    sleep 2
done
dos2unix $gcconf_versions
echo "`date +%Y-%m-%d_%T` Downloaded latest versions file"  >> $logfile

#update 55gocheats if needed
if [[ $(basename $0) = "gocheats_new.sh" ]] ;then
    old55=$(head -2 /system/etc/init.d/55gocheats | /system/bin/grep '# version' | awk '{ print $NF }')
    if [ $Ver55gocheats != $old55 ] ;then
        mount -o remount,rw /system
		mount -o remount,rw /system/etc/init.d || true
        until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/55gocheats https://raw.githubusercontent.com/andi2022/gcconf/master/55gocheats || { echo "`date +%Y-%m-%d_%T` Download 55gocheats failed, exit script" >> $logfile ; exit 1; } ;do
            sleep 2
        done
        chmod +x /system/etc/init.d/55gocheats
        mount -o remount,ro /system
		mount -o remount,ro /system/etc/init.d || true
        new55=$(head -2 /system/etc/init.d/55gocheats | /system/bin/grep '# version' | awk '{ print $NF }')
        echo "`date +%Y-%m-%d_%T` 55gocheats $old55=>$new55" >> $logfile
    fi
fi

#update 55cron if needed
if [[ $(basename $0) = "gocheats_new.sh" ]] ;then
    old55=$(head -2 /system/etc/init.d/55cron || echo "# version 0.0" | /system/bin/grep '# version' | awk '{ print $NF }')
    if [ "$Ver55cron" != "$old55" ] ;then
        mount -o remount,rw /system
		mount -o remount,rw /system/etc/init.d || true
		mount -o remount,rw /system/etc/crontabs || true
        # install 55cron
        until /system/bin/curl -s -k -L --fail --show-error -o  /system/etc/init.d/55cron https://raw.githubusercontent.com/andi2022/gcconf/master/55cron || { echo "`date +%Y-%m-%d_%T` Download 55cron failed, exit script" >> $logfile ; exit 1; } ;do
            sleep 2
        done
        chmod +x /system/etc/init.d/55cron
        echo "`date +%Y-%m-%d_%T` 55cron installed, from master" >> $logfile

        # install cron job
        until /system/bin/curl -s -k -L --fail --show-error -o  /system/bin/ping_test.sh https://raw.githubusercontent.com/andi2022/gcconf/master/ping_test.sh || { echo "`date +%Y-%m-%d_%T` Download ping_test.sh failed, exit script" >> $logfile ; exit 1; } ;do
            sleep 2
        done
        chmod +x /system/bin/ping_test.sh
        mkdir /system/etc/crontabs || true
        touch /system/etc/crontabs/root
        echo "15 * * * * /system/bin/ping_test.sh" > /system/etc/crontabs/root
        echo "0 23 * * * /system/bin/gocheats.sh -ua" >> /system/etc/crontabs/root
		crond -b
        mount -o remount,ro /system
		mount -o remount,ro /system/etc/init.d || true
		mount -o remount,ro /system/etc/crontabs || true
        new55=$(head -2 /system/etc/init.d/55cron | /system/bin/grep '# version' | awk '{ print $NF }')
        echo "`date +%Y-%m-%d_%T` 55cron $old55=>$new55" >> $logfile
    fi
fi

# prevent gcconf causing reboot loop. Add bypass ??
if [ $(/system/bin/cat /data/local/tmp/gcconf.log | /system/bin/grep `date +%Y-%m-%d` | /system/bin/grep rebooted | wc -l) -gt 20 ] ;then
    echo "`date +%Y-%m-%d_%T` Device rebooted over 20 times today, gocheats.sh signing out, see you tomorrow"  >> $logfile
    exit 1
fi

# set hostname = origin, wait till next reboot for it to take effect
if [[ $origin != "" ]] ;then
    if [ $(/system/bin/cat /system/build.prop | /system/bin/grep net.hostname | wc -l) = 0 ]; then
        mount -o remount,rw /system
        echo "`date +%Y-%m-%d_%T` No hostname set, setting it to $origin" >> $logfile
        echo "net.hostname=$origin" >> /system/build.prop
        mount -o remount,ro /system
    else
        hostname=$(/system/bin/grep net.hostname /system/build.prop | awk 'BEGIN { FS = "=" } ; { print $2 }')
        if [[ $hostname != $origin ]] ;then
            mount -o remount,rw /system
            echo "`date +%Y-%m-%d_%T` Changing hostname, from $hostname to $origin" >> $logfile
            /system/bin/sed -i -e "s/^net.hostname=.*/net.hostname=$origin/g" /system/build.prop
            mount -o remount,ro /system
        fi
    fi
fi

# check gocheats config file exists
if [[ -d /data/data/com.gocheats.launcher ]] && [[ ! -s $gcconf ]] ;then
    install_config
    am force-stop com.gocheats.launcher
    /system/bin/monkey -p com.gocheats.launcher 1
fi

for i in "$@" ;do
    case "$i" in
        -ig) install_gocheats ;;
        -ic) install_config ;;
        -ua) update_all ;;
        -dp) downgrade_pogo;;
        -sl) send_logs;;
    esac
done


(( $reboot )) && reboot_device
exit