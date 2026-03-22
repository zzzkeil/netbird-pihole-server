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
# beginn testing .... without whiptail for most parts
#########################################################

# List of URLs to download
urls=(
    "https://raw.githubusercontent.com/zzzkeil/netbird-pihole-server/refs/heads/main/config/dnscrypt-proxy-pihole.toml"
    "https://raw.githubusercontent.com/zzzkeil/netbird-pihole-server/refs/heads/main/config/dnscrypt-proxy-update.sh"
    "https://raw.githubusercontent.com/zzzkeil/netbird-pihole-server/refs/heads/main/config/pihole.toml"
)

download_files() {
    total_files=${#urls[@]}  
    current_file=0  
    for url in "${urls[@]}"; do
        filename=$(basename "$url")
        if [ -f "$filename" ]; then
            echo "File $filename already exists. Overwriting..."
        fi
        curl -s -o "$filename" "$url" & 
    done

    wait
}

download_files

mkdir /etc/dnscrypt-proxy/
mv dnscrypt-proxy-pihole.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml
mv dnscrypt-proxy-update.sh /etc/dnscrypt-proxy/dnscrypt-proxy-update.sh
chmod +x /etc/dnscrypt-proxy/dnscrypt-proxy-update.sh

mkdir /etc/pihole
mv pihole.toml /etc/pihole/pihole.toml

curl -L -o /etc/dnscrypt-proxy/dnscrypt-proxy.tar.gz "https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.15/dnscrypt-proxy-linux_${dnsscrpt_arch}-2.1.15.tar.gz"
if [ $? -eq 0 ]; then
echo ""
else
    whiptail --title "Download Failed" --msgbox "Failed to download DNSCrypt Proxy. Please check your network connection." 15 80
    exit 1
fi

tar -xvzf /etc/dnscrypt-proxy/dnscrypt-proxy.tar.gz -C /etc/dnscrypt-proxy/
mv -f /etc/dnscrypt-proxy/linux-$dnsscrpt_arch/* /etc/dnscrypt-proxy/
cp /etc/dnscrypt-proxy/example-blocked-names.txt /etc/dnscrypt-proxy/blocklist.txt

/etc/dnscrypt-proxy/dnscrypt-proxy -service install
/etc/dnscrypt-proxy/dnscrypt-proxy -service start

whiptail --title "Downloading Pihole" --msgbox "Download source from https://install.pi-hole.net\nand runing pihole-install.sh --unattended  mode" 15 80
curl -L -o pihole-install.sh https://install.pi-hole.net
if [ $? -eq 0 ]; then
echo ""
else
    whiptail --title "Download Failed" --msgbox "Failed to download Pihole. Please check your network connection." 15 80
    exit 1
fi
chmod +x pihole-install.sh
. pihole-install.sh --unattended 

while true; do
    whiptail --title "Pi-hole Password Setup" --infobox --nocancel "Please enter a password for your Pi-hole admin interface." 15 80
    pihole_password=$(whiptail --title "Pi-hole Password" --inputbox --nocancel "Enter your Pi-hole admin password\nmin. 16 characters" 15 80 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
       echo ""
    fi
    if [ ${#pihole_password} -ge 16 ]; then
	    whiptail --title "Password Set" --msgbox "Password has been set successfully!" 15 60
        pihole setpassword $pihole_password
        break 
    else
        whiptail --title "Invalid Password" --msgbox "Password must be at least 16 characters long. Please try again." 15 60
    fi
done

### apt
apt install sqlite3 -y

echo " Add more list to block "
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt', 1, 'MultiPRO-Extended')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt', 1, 'ThreatIntelligenceFeeds')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://easylist.to/easylist/easylist.txt', 1, 'Easylist')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://easylist.to/easylist/easyprivacy.txt', 1, 'Easyprivacy')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://secure.fanboy.co.nz/fanboy-annoyance.txt', 1, 'fanboy-annoyance')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://easylist.to/easylist/fanboy-social.txt', 1, 'fanboy-social')"
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://secure.fanboy.co.nz/fanboy-cookiemonster.txt', 1, 'fanboy-cookiemonster')"
pihole -g

clear
### create crontabs to update dnscrypt and pihole
(crontab -l ; echo "59 23 * * 6 /etc/dnscrypt-proxy/dnscrypt-proxy-update.sh") | sort - | uniq - | crontab -
(crontab -l ; echo "0 23 * * 3 pihole -up") | sort - | uniq - | crontab -




##  docker 
#apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1) - AI said ❌ risky ?? :)
apt remove docker.io docker-compose docker-doc podman-docker -y

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
systemctl enable docker


### netbird
apt install jq -y

#server
curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh | bash

## firewall  not the best idea with a docker setup, but lets try ......

### setup firewalld and sysctl  ipv6 and netbird not going well in 2026 ?
hostipv4=$(hostname -I | awk '{print $1}')
#hostipv6=$(hostname -I | awk '{print $2}')

# https://docs.netbird.io/help/troubleshooting-client#host-based-firewall-issues : firewalld Zone conflicts - NetBird interface may be in wrong zone
firewall-cmd --zone=trusted --add-interface=wt0

#NetBird docs usually expect MASQUERADE, not SNAT.
#firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 100.64.0.0/10 ! -d 100.64.0.0/10 -j SNAT --to "$hostipv4"
firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 100.64.0.0/10 -j MASQUERADE

firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=443/tcp
firewall-cmd --zone=public --add-port=3478/udp
firewall-cmd --zone=public --add-port=51820/udp

#Optional but recommended (TURN TCP fallback) - Some networks block UDP — open these too - These are used by coturn TLS/TCP fallback
#firewall-cmd --zone=public --add-port=3478/tcp
#firewall-cmd --zone=public --add-port=5349/tcp

#if [[ -n "$hostipv6" ]]; then
#firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s 0/64 ! -d 0/64 -j SNAT --to "$hostipv6"
#fi

# maybe wrong....
#firewall-cmd --zone=trusted --add-forward-port=port=53:proto=tcp:toport=53:toaddr=127.0.0.1
#firewall-cmd --zone=trusted --add-forward-port=port=53:proto=udp:toport=53:toaddr=127.0.0.1
# maybe this .... only if needed,  normaly netbird is handle dns servers!?....
#firewall-cmd --zone=trusted --add-port=53/udp
#firewall-cmd --zone=trusted --add-port=53/tcp
#firewall-cmd --direct --add-rule ipv4 nat PREROUTING 0 -i wt0 -p udp --dport 53 -j REDIRECT --to-port 53
#firewall-cmd --direct --add-rule ipv4 nat PREROUTING 0 -i wt0 -p tcp --dport 53 -j REDIRECT --to-port 53
                             
firewall-cmd --runtime-to-permanent
firewall-cmd --reload

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipv4.ip_forward.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
#echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-ipv6.conf.all.forwarding.conf
#echo 1 > /proc/sys/net/ipv6/conf/all/forwarding


#client - for exit node   # use the os repository
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
curl -sSL https://pkgs.netbird.io/debian/public.key | sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | sudo tee /etc/apt/sources.list.d/netbird.list
sudo apt-get update
sudo apt-get install netbird

echo "---------- run with your values  when ready: netbird up --management-url https://your.domain:443 --setup-key <SETUP KEY>"




