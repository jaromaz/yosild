# Yosild - Your simple Linux distro

Yosild is a single shell script that builds a full, minimal Linux distribution,
based on BusyBox. It compiles the **latest stable kernel** (5.16.10) and the
**latest stable version of the BusyBox** (1.34.1). This script can prepare
minimalistic Linux system for devices with little hardware resources. Yosild Linux
needs just **70 MB RAM** and **36 MB storage size**. *yosild.sh* requires
[minimal][1] *Debian* or *Ubuntu* distro to run with the architecture compatible
with the target device.

The script works with VirtualBox or KVM/QEMU (all drive types except VirtIO) - you
can create an additional virtual hard drive and install Yosild Linux on it, and
then connect this virtual disk to a new virtual machine - just like in my
[YouTube video][3]:
<p align="center"><a href="https://www.youtube.com/watch?v=BPXxPZBBeJ0" target="_blank"><img src="https://jm.iq.pl/yosild/yosild_mov2.jpg" width="50%"></a></p>

Yosild creates probably the simplest, complete version of Linux, which makes it
easier to understand, how to build the system from scratch. It is much easier to
build than other, previously available solutions: Aboriginal, mkroot, Buildroot or
Linux From Scratch - just specify the target drive (virtual or flash drive) inside
the *yosild.sh* script and simply run the script. You can also rename the system
to make it your distribution.


**Yosild**:

* downloads and installs all the libraries and packages required to compilation,
* downloads and compiles the BusyBox,
* downloads and compiles the kernel with default options,
* creates a number of minimalist scripts to simplify the management of this mini-distribution.

All of these components are integrated on the disk (or flash drive) indicated by
the user. Just run the script and after the first confirmation messages leave
the computer for several minutes. Note - the whole surface of the disk or flash
drive will be used - all data on the indicated disk will be deleted.

In the script you can easily change the kernel or BusyBox compilation options.

This mini-distribution by default supports ifupdown (also with DHCP script), log
rotation, mini-man pages, own minimalistic version of rc.d, running cron demons,
httpd, ftpd, syslogd and prepared boot script for telnetd. After installation on
a flash drive, the distribution can be run on any computer compatible with the
architecture on which the kernel was compiled.

Yosild is licensed under GNU General Public License v3.0.

For more information please visit my website: [https://jm.iq.pl/yosild][2]

[1]: https://www.debian.org/CD/netinst/
[2]: https://jm.iq.pl/yosild
[3]: https://www.youtube.com/watch?v=BPXxPZBBeJ0
