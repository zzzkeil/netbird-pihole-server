#!/bin/bash

msghi=" do not run this script\n
its not finish\n
its not tested\n
its ..... ... ..... \n\n
Run script now ?"

if whiptail --title "Hi, lets dont start" --yesno "$msghi" 25 90; then
echo ""
else
whiptail --title "Aborted" --msgbox "Ok, no install right now. Have a nice day." 15 80
exit 1
fi  

### root check
if [[ "$EUID" -ne 0 ]]; then
whiptail --title "Aborted" --msgbox "Sorry, you need to run this as root!" 15 80
exit 1
fi

### OS check
. /etc/os-release
if [[ "$ID" = 'debian' ]]; then
 if [[ "$VERSION_ID" = '13' ]]; then
 systemos=debian
 fi
fi

if [[ "$ID" = 'ubuntu' ]]; then
 if [[ "$VERSION_ID" = '24.04' ]]; then
 systemos=ubuntu
 fi
fi

if [[ "$systemos" = '' ]]; then
whiptail --title "Aborted" --msgbox "This script is only for Debian 13 and Ubuntu 24.04 !" 15 80
exit 1
fi

### Architecture check for dnsscrpt 
ARCH=$(uname -m)
if [[ "$ARCH" == x86_64* ]]; then
  dnsscrpt_arch=x86_64
elif [[ "$ARCH" == aarch64* ]]; then
  dnsscrpt_arch=arm64
else
whiptail --title "Aborted" --msgbox "This script is only for x86_64 or ARM64  Architecture !" 15 80
exit 1
fi

### base_setup check
if [[ -e /root/base_setup.README ]]; then
echo ""
else
wget -O  setup_base.sh https://raw.githubusercontent.com/zzzkeil/base_setups/refs/heads/master/setup_base.sh
chmod +x setup_base.sh
echo  "tempfile" > /root/reminderfile.tmp

msgbase="Some system requirements and packages are missing. \n
No problem, another script from me take care of that. \n
Run the setup_base.sh script and reboot after. \n
After a reboot you will be automatically coming back here to continue. \n
If not, just run this script again !! \n\n
cu later...\n"
OPTION=$(whiptail --title "System requirements" --menu "$msgbase" 15 80 3 \
"1" "Run /root/setup_base.sh" \
"2" "Exit" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus != 0 ]; then
    whiptail --title "Aborted" --msgbox "Ok, cancel. No changes to system was made.\n" 15 80
    exit
fi

case $OPTION in
    1)
        ./setup_base.sh
        ;;
    2)
        whiptail --title "Aborted" --msgbox "Ok, cancel. No changes to system was made.\n" 15 80
        ;;
    *)
        whiptail --title "?" --msgbox "Invalid option.......\n" 15 80
        ;;
esac
exit 1
fi
#########################################################
# beginn testing .... without whiptail
#########################################################

## firewall  not the best idea with a docker setup, but lets try ......

### setup firewalld and sysctl  ipv6 and netbird not going well in 2026 ?
hostipv4=$(hostname -I | awk '{print $1}')
#hostipv6=$(hostname -I | awk '{print $2}')

firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=443/tcp
firewall-cmd --zone=public --add-port=3478/udp

firewall-cmd --zone=trusted --add-source=100.64.0.0/10
firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 100.64.0.0/10 ! -d 100.64.0.0/10 -j SNAT --to "$hostipv4"

#if [[ -n "$hostipv6" ]]; then
#firewall-cmd --zone=trusted --add-source=
#firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s 0/64 ! -d 0/64 -j SNAT --to "$hostipv6"
fi

# maybe wrong....
firewall-cmd --zone=trusted --add-forward-port=port=53:proto=tcp:toport=53:toaddr=127.0.0.1
firewall-cmd --zone=trusted --add-forward-port=port=53:proto=udp:toport=53:toaddr=127.0.0.1
                             
firewall-cmd --runtime-to-permanent

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipv4.ip_forward.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
#echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-ipv6.conf.all.forwarding.conf
#echo 1 > /proc/sys/net/ipv6/conf/all/forwarding



##  docker 
apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)

if [[ "$systemos" = 'debian' ]]; then
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if [[ "$systemos" = 'ubuntu' ]]; then
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi


systemctl start docker


