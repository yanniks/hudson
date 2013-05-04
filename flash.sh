su -c mkdir -p /cache/recovery
su -c echo 'boot-recovery' > /cache/recovery/command
su -c echo '--update_package=/sdcard/Download/cm-current.zip' >> /cache/recovery/command
su -c reboot recovery
