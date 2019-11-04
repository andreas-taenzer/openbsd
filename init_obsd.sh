#!/bin/sh
# Auteur :      prx <prx@ybad.name>
# licence :     MIT

# modified for personal use

VERSION="04112019"

# check if root
if [ $(id -u) -ne 0 ]; then
	echo "You must run this script with root privileges"
	exit 1
fi

sortru() {
    # remove duplicate lines in a file
	# in case of successive isotop install
	# or user previous configuration
	sort -ru "${1}" -o "${1}"
}

# my github 
#OBSDURL="https://framagit.org/3hg/isotop/raw/master/"

dldir=$(pwd)
echo "* Get files"
#ftp "${OBSDURL}/OBSD-${VERSION}.tgz"
cd /
tar xzf "${dldir}"/OBSD-${VERSION}.tgz
#chmod +x /etc/X11/xenodm/Xsetup_0
#chmod +x /etc/X11/xenodm/*Console
chmod +x /usr/local/share/isotop/bin/*
PATH=$PATH:/usr/local/share/isotop/bin

echo "* Runnign syspatch for security reasons"
syspatch

echo "* Configuring install PATH"
echo "https://cdn.openbsd.org/pub/OpenBSD" >> /etc/installurl
sortru /etc/installurl

# doas
echo "* Configure doas"
echo "permit persist :wheel " >> /etc/doas.conf
echo "permit nopass :wheel cmd /sbin/shutdown" >> /etc/doas.conf
echo "permit nopass :wheel cmd /sbin/reboot" >> /etc/doas.conf

# in case a previous isotop install has been made
sortru /etc/doas.conf

# softdep
echo "* Enable softdeps"
sed -i 's/ffs rw,/ffs rw,softdep,/g' /etc/fstab   # only on ffs
sed -i 's/softdep,softdep,/softdep,/g' /etc/fstab # only one softdep
mount -a

echo "* Configure unwind DNS resolver"
rcctl enable unwind

echo "* Configure dhclient"
echo "prepend domain-name-servers 127.0.0.1;" >> /etc/dhclient.conf
sortru /etc/dhclient.conf

echo "* Enable apmd"
rcctl enable apmd
rcctl set apmd status on
rcctl set apmd flags -A

echo "* Enable xenodm"
rcctl enable xenodm

echo "* Installing packages"
PACKAGES=/usr/local/share/isotop/data/packages

pkg_add -vmzl $PACKAGES | tee -a -

if [ $? -eq 0 ]; then
	echo '* Package installation finished :)'
else
	echo '* Package installation did not work :('
	exit 1
fi

echo ""
echo "* Enable hotplugd"
/usr/local/libexec/hotplug-diskmount init
chmod +x /etc/hotplug/{attach,detach}
rcctl enable hotplugd
rcctl start hotplugd

echo ""
echo "* Set up ntpd"
sed -i 's/www\.google\.com/www.openbsd.org/' /etc/ntpd.conf
rcctl enable ntpd

echo ""
echo "* Enable cups"
rcctl enable cupsd cups_browsed
rcctl start cupsd cups_browsed

echo ""
echo "* Build manpage database"
makewhatis
echo ""

userdirs=$(grep '/home' /etc/passwd | cut -d':' -f1,6)
	echo "${SKEL}"
	echo ""
	res=""
	for ud in $userdirs; do
		u=$(echo $ud | cut -d':' -f1)
		d=$(echo $ud | cut -d':' -f2)

		if [ "$res" != "a" ]; then
			echo "$u ?"
			echo "[Y]es / [No] / [A]ll / [S]top"
			read res
			res=$(echo $res | tr '[:upper:]' '[:lower:]')
		fi

		case $res in
			y|a ) 
				cp -vR /etc/skel/.* "$d/"
				# not yet
				# cp -vR /etc/skel/* "$d/" 
				chown -R ${u}:${u} "$d"
				usermod -G wheel ${u}
				;;
			n )
				echo ""
				;;
			s )
				break
				;;
			* )
				echo "Wrong answer, not copying anything"
				;;
		esac
	done

# Reboot

exit 0

