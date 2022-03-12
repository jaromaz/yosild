#!/bin/sh
# ---------------------------------------
# Yosild - Your simple Linux distro
  version="3.2.1.B2"
# (c) Jaromaz https://jm.iq.pl
# Yosild is licensed under
# GNU General Public License v3.0
# ---------------------------------------

# ----- Config --------------------------
device="sda"
distro_name="Yosild"
distro_desc="Your simple Linux distro"
distro_codename="chinchilla"
telnetd_enabled="true"
hyperv_support="true"
kernel="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.16.14.tar.xz"
busybox="https://busybox.net/downloads/busybox-1.34.1.tar.bz2"
# ---------------------------------------

if [ $(id -u) -ne 0 ]; then
  echo "Run as root"; exit 1
fi

clear && printf "\n** $distro_name - creating distribution\n\n"
printf "** Are you sure that you want to delete all data from /dev/$device drive? (y/n): "
read answer
[ $answer != "y" ] && exit 1
if [ $( mountpoint -qd /mnt ) ]; then
  printf "** Can I umount /mnt? (y/n): "
  read answer
  [ $answer != "y" ] && exit 1
  umount /mnt
fi

# installation of the BusyBox
[ -d ./files ] || mkdir files
answer="n"
if [ -f files/busybox/busybox ] ; then
  printf "** Do you want to use a previously compiled BusyBox? (y/n): "
  read answer
fi
if [ $answer != "y" ] ; then
  echo "** BusyBox installation"

  apt update && apt install -y ca-certificates wget build-essential\
      libncurses5 libncurses5-dev bison flex libelf-dev chrpath gawk\
      texinfo libsdl1.2-dev whiptail diffstat cpio libssl-dev bc

  cd files/
  rm -r busybox* > /dev/null 2>&1
  wget $busybox -O busybox.tar.bz2
  tar -xf busybox.tar.bz2
  rm *.tar.bz2
  mv busybox* busybox
  cd busybox
  make defconfig

  # BusyBox configuration ------
  sed 's/^.*CONFIG_STATIC.*$/CONFIG_STATIC=y/' -i .config
  sed 's/^CONFIG_MAN=y/CONFIG_MAN=n/' -i .config
  echo "CONFIG_STATIC_LIBGCC=y" >> .config

  make
  cd ../../
fi


echo "** Partitioning /dev/$device" && sleep 2
part=1
lba=2048
wipefs -af /dev/$device > /dev/null 2>&1
  echo "** Preparation of the system partition"
  printf "n\np\n${part}\n2048\n\nw\n" | \
	 ./files/busybox/busybox fdisk /dev/$device > /dev/null 2>&1

echo y | mkfs.ext4 /dev/${device}${part}
uuid=$(blkid /dev/${device}${part} -sUUID -ovalue)


mount /dev/${device}${part} /mnt
mkdir /mnt/boot
host=$(printf $(printf $distro_name | tr A-Z a-z) | cut -d" " -f 1)

echo "** Compilation of the kernel"
arch=$(uname -m)
[ $arch = 'i686' ] && arch="i386"
answer="n"
if [ -f files/linux/arch/$arch/boot/bzImage ] ; then
  printf "** Do you want to use a previously compiled kernel? (y/n): "
  read answer
fi
if [ $answer != "y" ] ; then
  cd files
  rm -r linux* > /dev/null 2>&1
  wget $kernel 
  tar -xf *.tar.xz
  rm linux-*.tar.xz
  mv linux* linux
  cd linux

# Linux Kernel config --------------------------------------
if [ "$hyperv_support" = "true" ]; then
cat <<EOF >> arch/x86/configs/x86_64_defconfig
CONFIG_HYPERVISOR_GUEST=y
CONFIG_PARAVIRT=y
CONFIG_CONNECTOR=y
CONFIG_HYPERV=y
CONFIG_HYPERV_NET=y
EOF
fi
# ----------------------------------------------------------

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

# creation of necessary directories
mkdir rootfs
cd rootfs
mkdir -p bin dev lib lib64 run mnt/root proc sbin sys usr/bin \
         usr/sbin tmp home var/log usr/share/udhcpc usr/local/bin \
         var/spool/cron/crontabs etc/init.d etc/rc.d var/run \
         var/www/html etc/network/if-down.d etc/network/if-post-down.d \
         etc/network/if-pre-up.d etc/network/if-up.d run \
         etc/cron/daily etc/cron/hourly etc/cron/monthly etc/cron/weekly

# installation of the BusyBox
cp ../files/busybox/busybox bin
install -d -m 0750 root
install -d -m 1777 tmp

# DNS libs
for i in $(find /lib/ | grep 'ld-2\|ld-lin\|libc.so\|libnss_dns\|libresolv'); do
    cp ${i} lib
done

echo "** System configuration"
mknod dev/console c 5 1
mknod dev/tty c 5 0
printf $host > etc/hostname
printf "root:x:0:0:root:/root:/bin/sh\nservice:x:1:1:service:/var/www/html:/usr/sbin/nologin" > etc/passwd
echo "root:mKhhqXFCdhNiA:17743::::::" > etc/shadow
echo "root:x:0:root\nservice:x:1:service" > etc/group
echo "/bin/sh" > etc/shells
echo "127.0.0.1	 localhost $host" > etc/hosts

# Default httpd page
cat << EOF > var/www/html/index.html
<!DOCTYPE html><html lang="en"><head><title>$distro_name httpd default page: It works</title>
<style>body{background-color:#004c75;}h1,p{margin-top:60px;color:#d4d4d4;
text-align:center;font-family:Arial}</style></head><body><h1>It works!</h1><hr>
<p><b>$distro_name httpd</b> default page<br>ver. $version</p></body></html>
EOF

# fstab
echo "UUID=$uuid  /  ext4  defaults,errors=remount-ro  0  1" > etc/fstab

# Path, prompt and aliases
cat << EOF > etc/profile
uname -snrvm
echo
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
export PS1="\\e[0;32m\\u@\\h:\\w\\\$ \\e[m"
[ \$(id -u) -eq 0 ] && export PS1="\\u@\\h:\\w# "
alias vim=vi
alias l.='ls -d .*'
alias ll='ls -Al'
alias su='su -l'
alias logout='clear;exit'
alias exit='clear;exit'
alias locate=which
alias whereis=which
alias useradd=adduser
EOF

# banner
printf "\n\e[96m${*}$distro_name\e[0m${*} Linux \e[97m${*}$version\e[0m${*} - $distro_desc\n\n" | tee -a etc/issue usr/share/infoban >/dev/null
cat << EOF >> etc/issue
 * Default root password:        Yosild
 * Networking:                   ifupdown
 * Init scripts installer:       add-rc.d
 * To disable this message:      disban

EOF
echo "cp /usr/share/infoban /etc/issue" > sbin/disban

# legal
cat << EOF > etc/motd

The programs included with the $distro_name Linux system are free software.
$distro_name Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.

EOF

cat << EOF > etc/os-release
PRETTY_NAME="$distro_name - $distro_desc ($distro_codename)"
NAME="$distro_name"
VERSION_ID="$version"
VERSION="$version"
VERSION_CODENAME="$distro_codename"
ID="$distro_name"
HOME_URL="https://github.com/jaromaz/yosild"
SUPPORT_URL="https://jm.iq.pl/yosild"
BUG_REPORT_URL="https://github.com/jaromaz/yosild/issues"
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
if ! mountpoint -q dev
then
  mount -t tmpfs -o size=64k,mode=0755 tmpfs dev
  mount -t tmpfs -o mode=1777 tmpfs tmp
  mkdir -p dev/pts
  mdev -s
  chown -R service:service /var/www
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

# nologin
printf "#!/bin/sh
echo 'This account is currently not available.'
sleep 3
exit 1" > usr/sbin/nologin

# halt
cat << EOF > sbin/halt
#!/bin/sh
if [ \$1 ] && [ \$1 = '-p' ] ; then
    /bin/busybox poweroff
    return 0
fi
/bin/busybox halt
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

# rcS & rcK
printf "#!/bin/sh
. /etc/init.d/init-functions
rc" > etc/init.d/rcS
ln -s /etc/init.d/rcS etc/init.d/rcK

# default crontabs
cat << EOF > var/spool/cron/crontabs/root
15  * * * *   cd / && run-parts /etc/cron/hourly
23  6 * * *   cd / && run-parts /etc/cron/daily
47  6 * * 0   cd / && run-parts /etc/cron/weekly
33  5 1 * *   cd / && run-parts /etc/cron/monthly
EOF

# logrotate
cat << EOF > usr/sbin/logrotate
#!/bin/sh 
maxsize=512
dir=/var/log
for log in \$(ls -1 \${dir} | grep -Ev '\.gz$'); do
  size=\$(du "\$dir/\$log" | tr -s '\t' ' ' | cut -d' ' -f1)
  if [ "\$size" -gt "\$maxsize" ] ; then
    tsp=\$(date +%s)
    mv "\$dir/\$log" "\$dir/\$log.\$tsp"
    touch "\$dir/\$log"
    gzip "\$dir/\$log.\$tsp"
  fi
done
EOF
ln -s ../../../usr/sbin/logrotate etc/cron/daily/logrotate

# init scripts installer
cat << EOF > usr/bin/add-rc.d
#!/bin/sh
if [ -f /etc/init.d/\$1 ] && [ "\$2" -gt 0 ] ; then 
ln -s /etc/init.d/\$1 /etc/rc.d/\$2\$1
echo "added \$1 to init."
else
echo "
  ** $distro_name add-rc.d ussage:

  add-rc.d [init.d script name] [order number]

  examples:
  add-rc.d httpd 40
  add-rc.d ftpd 40
  add-rc.d telnetd 50

"
fi
EOF

# start-up scripts
initdata="
networking|network|30|/sbin/ifup|-a|/sbin/ifdown
telnetd|telnet daemon|80|/usr/sbin/telnetd|-p 23
cron|cron daemon|20|/usr/sbin/crond
syslogd|syslog|10|/sbin/syslogd
httpd|http server||/usr/sbin/httpd|-vvv -f -u service -h /var/www/html||httpd.log
ftpd|ftp daemon||/usr/bin/tcpsvd|-vE 0.0.0.0 21 ftpd -S -a service -w /var/www/html"

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
chmod 744 etc/init.d/$1
[ $1 = 'telnetd' ] && [ "$telnetd_enabled" = false ] && continue;
[ "$3" ] && ln -s ../init.d/$1 etc/rc.d/$3$1.sh
done

# scripts compressed and base64 encoded due to their large size ------------

# BusyBox DHCP client script
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

# startup scripts functions
cat << EOF | base64 -d | gzip -d > etc/init.d/init-functions
H4sICMdmNFwAA2luaXQtZnVuY3Rpb25zAHVSXW/aMBR99684eBYiSMR0j0UFoZVNaOVjDXtCfcgS
A9aiJLJNhVT63+fYWZIyzU/2/Tj3nHP9qcd/yZzrEyEylwaDAG/ECG0wOoA9zherzRrXK8TFJsck
ibUAZXcUMieANrEygb0AIjkVoFEVkPnRti6iL2EYUpcE5AF7sKfNN7xgAnMSeZ1AM4Vt58/zVYTP
0yl/jRXPiiN3Hf26VGRa/LerP+WpeOX5OcuahoNsqbEeprZ4+fh1+bRw4cnEKSjKjwKKsvxXgKcf
7TbbW/4+WLMgNzT3zsV6qO3s9/FbWoJskMSmSQRd8qRD3DFUwrl8VSIr4tRzpWxMHfXuyxa1XcOu
KLaerxZw+9WJkqXBWcdHcQ82xptHr8Cu9ah3r1kJc1Y57ojQcULqF5uRd0JU4j+Ks2WUgguTcJWE
qde4r4AfHkBdvJobpjb9neKl492hULhYVtaNTGOkWhQeWI/Totl1m2CXVnZa5OIjUWtbBSor0LZn
Nhv+hdujV22EMkk906TI7Xc9e5z6c8v6c1dnGOpT0PAYNDfAqLjECMv1Dj9+LnfYRbttJ62F6azE
nxBMNs8W1e2rHhd0ypm8Ragr3T6cep0JUVrhSSZiRRof7Ib+AOWFyVTYAwAA
EOF

# permissions
touch proc/mounts var/log/wtmp var/log/lastlog
chmod 640  etc/shadow etc/inittab
chmod 664  var/log/lastlog var/log/wtmp
chmod 4755 bin/busybox
chmod 600  var/spool/cron/crontabs/root
chmod 755  usr/sbin/nologin sbin/disban init sbin/man etc/init.d/rcS\
           usr/sbin/logrotate usr/bin/add-rc.d sbin/halt\
           usr/share/udhcpc/default.script 
chmod 644  etc/passwd etc/group etc/hostname etc/shells etc/hosts etc/fstab\
           etc/issue etc/motd etc/network/interfaces etc/profile

echo "** Building initramfs"
find . | cpio -H newc -o 2> /dev/null | gzip > /mnt/boot/$initrd_file
cd ..
chmod 400 /mnt/boot/$initrd_file
rm -r rootfs
umount /mnt
printf "\n** all done **\n\n"


