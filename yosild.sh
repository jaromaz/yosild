#!/bin/sh

# -----------------------------------
# Yosild - Your simple Linux distro
# -----------------------------------


# ----- Configuration ---------------

distro_name="Yosild"
distro_desc="Your simple Linux distro"
distro_version="1.0"
device="sdb"
swap_size=20 # MB
telnetd="false"
kernel="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.20.tar.xz"
# Minimum required BusyBox version is 1.28
busybox="https://busybox.net/downloads/binaries/1.28.1-defconfig-multiarch/busybox-i686"

# -----------------------------------



clear
if [ $(id -u) -ne 0 ]; then
  echo "Run as root"; exit 1
fi

printf "\n** $distro_name - creating distribution\n\n"
printf "** Are you sure that you want to delete all data from your /dev/$device drive? (y/n): "
read ans
[ $ans != 'n' ] || exit 1


if [ $( mountpoint -qd /mnt ) ]; then
  printf "** Can I umount /mnt? (y/n): "
  read ans
  [ $ans != 'n' ] || exit 1
  umount /mnt
fi


# installation of the BusyBox
[ -d ./files ] || mkdir files
busans=n
if [ -f files/busybox ] ; then
  printf "** Do you want to use a BusyBox downloaded earlier? (y/n): "
  read busans
fi
if [ $busans != 'y' ] ; then
  echo "** Busybox installation"
  rm files/busybox > /dev/null 2>&1
  wget $busybox -O files/busybox
  chmod +x files/busybox
fi


echo "** Partitioning /dev/$device"
sleep 5
dir=$(pwd)
part=1
swap_uuid=0
wipefs -af /dev/$device > /dev/null 2>&1
if [ $swap_size -gt 0 ] ; then
  echo "** Preparation of the swap partition"
  part=2
  printf "n\np\n1\n\n+${swap_size}M\nt\n82\nw\n" | ./files/busybox fdisk /dev/$device > /dev/null 2>&1
  mkswap /dev/${device}1
  swap_uuid=$(blkid /dev/${device}1 -sUUID -ovalue)
  sleep 1  
fi
echo "** Preparation of the system partition"
printf "n\np\n${part}\n\n\nw\n" | ./files/busybox fdisk /dev/$device > /dev/null 2>&1
printf "Y\n" | mkfs.ext4 /dev/${device}${part}

uuid=$(blkid /dev/${device}${part} -sUUID -ovalue)
mount /dev/${device}${part} /mnt
mkdir /mnt/boot
host=$(printf $(printf $distro_name | tr A-Z a-z) | cut -d" " -f 1)



echo "** Compilation of the kernel"
arch=$(uname -m)
[ $arch != 'i686' ] || arch="i386"
kerans=n
if [ -f files/linux/arch/$arch/boot/bzImage ] ; then
  printf "** Do You want to use a kernel compiled earlier? (y/n): "
  read kerans
fi

if [ $kerans != 'y' ] ; then
  apt update && apt install -y build-essential libncurses5 libncurses5-dev \
	bison flex libelf-dev chrpath gawk texinfo libsdl1.2-dev whiptail \
	diffstat cpio libssl-dev bc
  cd files
  rm -r linux* > /dev/null 2>&1
  wget $kernel 
  tar -xf *.tar.xz
  rm linux-*.tar.xz
  mv linux* linux
  cd linux
  make defconfig
  make
  cd ../../
fi

kernel_release=$(cat files/linux/include/config/kernel.release)
kernel_file=vmlinuz-$kernel_release-$arch
initrd_file=initrd.img-$kernel_release-$arch

cp files/linux/arch/$arch/boot/bzImage /mnt/boot/$kernel_file

echo "** Installation of GRUB"
grub-install --root-directory=/mnt /dev/$device
printf "timeout=3
menuentry '$distro_name - $distro_desc' {
linux /boot/$kernel_file quiet rootdelay=130
initrd /boot/$initrd_file
root=PARTUUID=$uuid
boot
echo Loading Linux
}" > /mnt/boot/grub/grub.cfg

# creation of necessary catalogues
mkdir rootfs
cd rootfs
mkdir -p bin dev lib lib64 run mnt/root proc sbin sys usr/bin \
	 usr/sbin tmp home var/log usr/share/udhcpc usr/local/bin \
	 var/spool/cron/crontabs etc/init.d etc/rc.d var/run \
	 var/www/html etc/network/if-down.d etc/network/if-post-down.d \
	 etc/network/if-pre-up.d etc/network/if-up.d run \
	 etc/cron/daily etc/cron/hourly etc/cron/monthly etc/cron/weekly


# installation of the BusyBox
cp ../files/busybox bin
chmod 4755 bin/busybox
install -d -m 0750 root
install -d -m 1777 tmp


echo "** Initial configuration"
mknod dev/console c 5 1
mknod dev/tty c 5 0
printf $host > etc/hostname
printf "root:x:0:0:root:/root:/bin/sh\nservice:x:1:1:service:/var/www/html:/usr/sbin/nologin" > etc/passwd
echo "root:mKhhqXFCdhNiA:17743::::::" > etc/shadow
echo "root:x:0:root\nservice:x:1:service" > etc/group
echo "/bin/sh" > etc/shells
echo "127.0.0.1	 localhost $host" > etc/hosts
echo "<html><h1>It Works!!</h1></html>" > var/www/html/index.html
echo "UUID=$uuid  /  ext4  defaults,errors=remount-ro  0  1" > etc/fstab
[ $swap_size -gt 0 ] && echo "UUID=$swap_uuid  none  swap  sw  0  0" >> etc/fstab
chmod 640 etc/shadow
touch var/log/lastlog
touch proc/mounts
touch var/log/wtmp

# path and aliases
cat << EOF > etc/profile
uname -snrvm
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
PS1="\\u@\\h:\\w\\$ "
[ \$(id -u) -eq 0 ] && PS1="\\u@\\h:\\w# "
alias vim=vi
alias su="su -l"
alias locate=which
alias whereis=which
alias logout=exit
EOF


# banner
printf "\n$distro_name Linux $distro_version - $distro_desc\n\n" | tee -a etc/issue usr/share/infoban >/dev/null

cat << EOF >> etc/issue
 * Default root password:	 Yosild
 * Networking:			 /etc/network/interfaces
 * Init script links installer:	 add-rc.d
 * To disable this message: 	 disban

EOF
echo "cp /usr/share/infoban /etc/issue" > sbin/disban
chmod +x sbin/disban


# legal
cat << EOF > etc/motd
The programs included with the $distro_name Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

$distro_name Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
EOF


# inittab
cat << EOF > etc/inittab
tty1::respawn:/sbin/getty 38400 tty1
tty2::askfirst:/sbin/getty 38400 tty2
tty3::askfirst:/sbin/getty 38400 tty3
tty4::askfirst:/sbin/getty 38400 tty4
::sysinit:/sbin/swapon -a
::sysinit:/bin/hostname -F /etc/hostname
::sysinit:/etc/init.d/rcS
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/echo SHUTTING DOWN
::shutdown:/sbin/swapoff -a
::shutdown:/etc/init.d/rcK
::shutdown:/bin/umount -a -r
EOF


# networking
cat << EOF > etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF



# init
cat << EOF > init
#!/bin/busybox sh
/bin/busybox --install -s
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
mountpoint -q proc || mount -t proc proc proc
mountpoint -q sys || mount -t sysfs sys sys
mknod /dev/null c 1 3
echo /sbin/mdev > /proc/sys/kernel/hotplug
if ! mountpoint -q dev
then
  mount -t tmpfs -o size=64k,mode=0755 tmpfs dev
  mount -t tmpfs -o mode=1777 tmpfs tmp
  mkdir -p dev/pts
  mdev -s
fi
echo 0 > /proc/sys/kernel/printk
sleep 1
mount -t ext4 UUID=$uuid /mnt/root/
mount -t tmpfs run /run -o mode=0755,nosuid,nodev
if [ ! -d /mnt/root/bin ] ; then
for i in bin etc lib root sbin usr home var; do
  cp -r -p /\$i /mnt/root
done
mkdir /mnt/root/mnt
fi
for i in run tmp dev proc sys; do
  [ -d /mnt/root/\$i ] || mkdir /mnt/root/\$i
  mount -o bind /\$i /mnt/root/\$i
done
mount -t devpts none /mnt/root/dev/pts
rm -r /bin /etc /sbin /usr
exec /mnt/root/bin/busybox chroot /mnt/root /sbin/init
EOF
chmod +x init



# nologin
printf "#!/bin/sh
echo This account is currently not available.
sleep 3
exit 1" > usr/sbin/nologin
chmod +x usr/sbin/nologin



# halt
printf "#!/bin/sh
if [ \$1 ] && [ \$1=='-p' ] ; then 
    /bin/busybox poweroff
    return 0
fi
/bin/busybox halt -f" > sbin/halt
chmod +x sbin/halt


# DHCP client script
cat << EOF | base64 -d | gzip -d > usr/share/udhcpc/default.script
H4sICOcUYlsAA2RoY3Auc2gAzVZNT9tAED17f8VgLEhAxEmP0ESilF7aggSol4ZGm/U4XmHvml07
gZb+944/kloxH6HtoRvFSXZn3sy8N2Nne8ufSuXbiG1DHkQiFWCFkWkGGMgMA5jew5VM4ELeoIG3
xVeeVb9sT5vZiH2Fg+/gegMXrmFnB1BEGtxTY7Q5BBvpPCYMBMHjmNBCo5M6jlta38kMBuzi9PL8
05fJyfnZh6HrYyZ8g1bH857QKnSLEIpCTI3mgeA2q0O9uzg/fn9yfHk1dFdH0LBa+tl8qnDpdHZ6
9fn48uPQpa2E2xtYHhMBBrPcKOiDDMFonYG0kOhcFTxoBRzIbqHNDYQyRntvM0xYYTeRdqJC2+nC
D+bMDKZwcIuw+80PcO4XBr29cYcMxg82mRYfSqTjB6EDPu5Cb28X/NRo4ZehLPvJIj7HCckykemw
zygZKuQOSqFkCtdHkEWoGEDTbsBCyahsrLSQijkBFvTJWZc5DoFsQSNXWIE8vsqgXiMAHOAtDBrB
n1/kwIPAQBjnNgLiATxJPJqQC9zEOZbqBixma66Qp096Y2xfhvZtyWJYMdNE7vfK15MIRK/jlJej
I8YcgwoXD1OSLOi2fP6UvSVrdFkvPNY0QrSR+l7Vtqvub6E9S8TTBBB2AxW8elJaSMRB1VD1eBmd
E0QxXnV1zuvb7W+JW1+LiCa0oLNMjriM6R3yPM7gzagcS5XHMWUV6I0xl+twY49Aq5c7cqO2Xa6q
rnZRs8Wyf9f75n8rt5ygao6cBDMjBd3iih1tQNJtC+p+2izZf9Uvq06pJq8idS45MQlVluB1OtW3
/f1ue+LX16tUbYcmPSnympSPJdLUd0PuS5lqCcqnNU3xCLzGM5gO6tkOdMKlaj7aLXIjIqhPYNTy
/C1koGylolMHogqlmkGx78nVruIJWjRz0pxqbgPW+dJdFy0XrPzL0Ge/AHxZ2lW5CAAA
EOF
chmod +x usr/share/udhcpc/default.script



# startup scripts functions
cat << EOF | base64 -d | gzip -d > etc/init.d/init-functions
H4sICLhJlFsAA2luaXQtZnVuY3Rpb25zAJVTXW/aMBR99684eBYiSCR0j0MFoZVNaOVjC3tCfcgS
A9aiJLJNhVT63+fYVpIyTeruk30/zzm+/tCLfokiUidCRCE0BgFeCNFcaYwOYA/zxWqzxvUKfjHR
MSFpojgou6MQBQGUTqQOzAHg6akEjWuHKI6mdhF/DsOQ2iAgDtiDPW6+4gkT6BMvfADNGLad/5iv
YnycTqPnREZ5eYxsRd+n8lzxf1b1p1HGn6PinOdNwUG00FgPU5O8fPiyfFxY92RiGZTVWwJlVf1N
wMGPd5vtLX7n9CjIDcy9ldEPNZX9Pn4LA5AN0kQ3gaALnnSAW4SSW5WvkudlkjmslI2phd69maS2
atglxdbz1QL2hVUqRaVxVsmRfwIb48V1r5td/ahXx1lyfZYF7ghXSUqIv7IZIa/EXFO/LVaaUYaI
6zSSaZg5nvu6+f09qPXXs8PMhL9RPDn98E5zgpQSF8PAKJcrjGQ7LQrMe2Tle5rU1taxi1Xwf1Bk
ZcHfSmMeqoYmamht69lsaEGRegN69Q5QJqjTJS0L80HOro//TsJ/p9qGoToFDdwBaSFomVQYYbne
4fvP5Q67eLfthBXXnSVwFoKJ5tp2tRvixwWddCZuO/hMuwGWvco5rwzxNOeJJI0OZiP+APXWo0BM
BAAA
EOF



# mini man pages
cat << EOF > sbin/man
#!/bin/sh
if [ -z "\$(busybox \$1 --help 2>&1 | head -1 | grep 'applet not found')" ]
then
  clear
  head="\$(echo \$1 | tr 'a-z' 'A-Z')(1)\\t\\t\\tManual page\\n"
  body="\$(busybox \$1 --help 2>&1 | tail -n +2)\\n\\n"
  printf "\$head\$body" | more
  exit 0
fi
echo "No manual entry for \$1"
EOF
chmod +x sbin/man


# rcS & rcK
cat << EOF > etc/init.d/rcS
#!/bin/sh
. /etc/init.d/init-functions
rc
EOF
chmod +x etc/init.d/rcS
ln -s /etc/init.d/rcS etc/init.d/rcK



# default crontabs
cat << EOF > var/spool/cron/crontabs/root
15  * * * *   cd / && run-parts /etc/cron/hourly
23  6 * * *   cd / && run-parts /etc/cron/daily
47  6 * * 0   cd / && run-parts /etc/cron/weekly
33  5 1 * *   cd / && run-parts /etc/cron/monthly
EOF
chmod 600 var/spool/cron/crontabs/root



# logrotate
cat << EOF > etc/cron/daily/logrotate
#!/bin/sh 
maxsize=512
dir=/var/log
for log in messages lastlog; do
  size=\$(du "\$dir/\$log" | tr -s '\t' ' ' | cut -d' ' -f1)
  if [ "\$size" -gt "\$maxsize" ] ; then
    tsp=\$(date +%s)
    mv "\$dir/\$log" "\$dir/\$log.\$tsp"
    touch "\$dir/\$log"
    gzip "\$dir/\$log.\$tsp"
  fi
done
EOF
chmod +x etc/cron/daily/logrotate


# init script links installer
cat << EOF > usr/bin/add-rc.d
#!/bin/sh
if [ -f /etc/init.d/\$1 ] && [ "\$2" -gt 0 ] ; then 
ln -s /etc/init.d/\$1 /etc/rc.d/\$2\$1
echo "added \$1 to init."
else
clear
printf "\\n\\n * $distro_name add-rc.d ussage:

  add-rc.d [init.d script name] [order number]

  examples:

  add-rc.d httpd 40
  add-rc.d ftpd 40
  add-rc.d telnetd 50

"
fi
EOF
chmod +x usr/bin/add-rc.d


# start-up scripts
initdata="
networking|network|30|/sbin/ifup|-a|/sbin/ifdown
telnetd|telnet daemon|80|/usr/sbin/telnetd|-p 23
cron|cron daemon|20|/usr/sbin/crond
syslogd|syslog|10|/sbin/syslogd
httpd|http server||/usr/sbin/httpd|-vvv -f -u service -h /var/www/html||httpd.log
ftpd|ftp daemon||/usr/bin/tcpsvd|-u service -vE 0.0.0.0 21 ftpd -S /var/www/html/
"

OIFS=$IFS
IFS='
'
for i in $initdata; do
IFS='|'
set -- $i
cat << EOF > etc/init.d/$1
#!/bin/sh

NAME="$1"
DESC="$2"
DAEMON="$4"
PARAMS="$5"
STOP="$6"
LOG="$7"
PIDFILE=/var/run/$1.pid

. /etc/init.d/init-functions
init \$@
EOF
chmod +x etc/init.d/$1

[ $1 = 'telnetd' ] && [ "$telnetd" = false ] && continue;
[ "$3" ] && ln -s ../init.d/$1 etc/rc.d/$3$1.sh
done


echo "** Building initramfs"
find . | cpio -H newc -o 2> /dev/null | gzip > /mnt/boot/$initrd_file
cd ..
chmod 400 /mnt/boot/$initrd_file
rm -r rootfs
umount /mnt 

printf "\n\n** done **\n\n"

