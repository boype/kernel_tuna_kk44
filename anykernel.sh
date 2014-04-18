# AnyKernel 2.0 Ramdisk Mod Script 
# osm0sis @ xda-developers

## AnyKernel setup
# EDIFY properties
kernel.string=Fancy Kernel by boype @ xda-developers
do.cleanup=1

# shell variables
block=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;

## end setup


## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;
status=/tmp/anykernel/statusmsg;
statuscode=0;

cd $ramdisk;
chmod -R 755 $bin;
mkdir -p $split_img;

# write status code
write_status() {
  if [ $statuscode -eq 0 ]; then
    statuscode="$1";
    if [ $1 -eq 99 ]; then
      echo "status.text=Kernel installed successfully!" > $status;
    else
      echo "status.text=Kernel could not be installed! Error code: $1" > $status;
    fi;
  fi;
}

# dump boot and extract ramdisk
dump_boot() {
  dd if=$block of=/tmp/anykernel/boot.img;
  if [ $? -ne 0 ]; then
    write_status 1;
  fi;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? -ne 0 ]; then
    write_status 2;
  fi;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
  if [ $? -ne 0 ]; then
    write_status 3;
  fi;
}

# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  cd $ramdisk;
  find . | cpio -o -H newc | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  if [ $? -ne 0 ]; then
    write_status 4;
  fi;
  $bin/mkbootimg --kernel /tmp/anykernel/zImage --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz --cmdline "$cmdline" --base $base --pagesize $pagesize --output /tmp/anykernel/boot-new.img;
  if [ $? -ne 0 ]; then
    write_status 5;
  fi;
  dd if=/tmp/anykernel/boot-new.img of=$block;
  if [ $? -ne 0 ]; then
    write_status 6;
  else
    write_status 99;
  fi;
}

# backup_file <file>
backup_file() { cp $1 $1~; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

# insert_line <file> <if search string> <line before string> <inserted line>
insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    line=$((`grep -n "$3" $1 | cut -d: -f1` + 1));
    sed -i $line"s;^;${4};" $1;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i $line"s;.*;${3};" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -fp $patch/$3 $1;
  chmod $2 $1;
}

## end methods


## AnyKernel permissions
# set permissions for included files
chmod -R 755 $ramdisk


## AnyKernel install
dump_boot;

# begin ramdisk changes

# init.rc
replace_string init.rc "cpuctl cpu,timer_slack" "mount cgroup none /dev/cpuctl cpu" "mount cgroup none /dev/cpuctl cpu,timer_slack";

# init.tuna.rc
append_file init.tuna.rc "fancyinit" init.tuna.rc;

# fstab.tuna
replace_line fstab.tuna "/by-name/system" "/dev/block/platform/omap/omap_hsmmc.0/by-name/system    /system             ext4      ro,noatime,barrier=0                                  wait";
replace_line fstab.tuna "/by-name/cache" "/dev/block/platform/omap/omap_hsmmc.0/by-name/cache     /cache              ext4      noatime,nosuid,nodev,noauto_da_alloc,nomblk_io_submit,errors=panic    wait,check";
replace_line fstab.tuna "/by-name/userdata" "/dev/block/platform/omap/omap_hsmmc.0/by-name/userdata  /data               ext4      noatime,nosuid,nodev,noauto_da_alloc,nomblk_io_submit,errors=panic    wait,check,encryptable=/dev/block/platform/omap/omap_hsmmc.0/by-name/metadata";
append_file fstab.tuna "usbdisk" fstab;

# end ramdisk changes

write_boot;

## end install

