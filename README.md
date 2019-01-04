# Yosild - Your simple Linux distro

Yosild is a shell script that builds a full, minimal Linux distribution, based on BusyBox. I wrote it with the assumption of compiling any version of kernel on any hardware platform, so that this script can prepare minimalistic Linux for devices with little hardware resources.

It creates probably the simplest, complete version of Linux, which makes it easier to understand, how to build the system from scratch. It is much easier to build than other, previously available solutions: Aboriginal, mkroot, Buildroot or Linux From Scratch.

The script should be run on the latest Debian version with the architecture compatible with the target device - just a network install from a minimal CD ([netinst][1]).

**Yosild**:

* downloads and installs all the libraries and packages required to compile,
* downloads and compiles the kernel with default options,
* downloads and installs the BusyBox,
* creates a number of minimalist scripts to facilitate the management of mini-distribution.

All of these components are integrated on the disk (or flash drive) indicated by the user. Just run the script and after the first confirmation messages leave the computer for several minutes. Note - the whole surface of the disk or flash drive will be used - all data on the indicated disk will be deleted.

You can create a name for the mini-distribution generated in this way, specify the destination disc, the path to the kernel and the correct BusyBox version. By default, the options are populated with the latest versions for the i686 architecture.

Mini-distribution by default supports standard entries in /etc/network/interfaces (also DHCP), includes swap partition support, log rotation, mini-man pages, own minimalistic version of rc.d, running cron demons, httpd, ftpd, syslogd and prepared boot script for telnetd. After installation on a flash drive, the distribution can be run on any computer compatible with the architecture on which the kernel was compiled.

The script cooperates with VirtualBox - you can create an additional hard disk and install Yosild on it, and then connect this virtual disk to a new virtual machine.

Yosild is licensed under GNU General Public License v3.0

More information: [https://jm.iq.pl][2]

[1]: https://www.debian.org/CD/netinst/
[2]: https://jm.iq.pl/yosild-my-your-linux-distribution/
