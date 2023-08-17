#!/bin/bash

echo "Choose an option:"
echo "1. Host"
echo "2. Relay" 
echo "3. Change relay's config"
read choice

if [ "$choice" = "1" ] || [ "$choice" = "2" ]; then

  apt update 
  apt install git -y
  git clone https://LPBD1333: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@github.com/LPBD1333/WGI.git

if [ "$choice" = "1" ]; then

  apt install wireguard net-tools -y
  
  sysctl -w net.ipv4.ip_forward=1
  
  int="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"

fi

  if [ "$choice" = "1" ]; then
    echo "Choose an option:"
    echo "1-a. Fresh install"
    echo "1-b. Deploy backup"
    read subchoice

    if [ "$subchoice" = "1-a" ]; then
      sed -i "s/eth0/$int/g" WGI/wg0.conf
      read -p "WireGuard port (default = 51820): " port
      if [ ! -z "$port" ]; then
        sed -i "s/ListenPort = 51820/ListenPort = $port/g" WGI/wg0.conf
      fi  
      read -p "Do you want to change the WG name? (y/n) " changename
      if [ "$changename" = "y" ]; then
        read -p "Enter WG name: " wgname
        mv WGI/wg0.conf /etc/wireguard/"$wgname".conf
        systemctl enable --now "wg-quick@$wgname.service"
      else
        mv WGI/wg0.conf /etc/wireguard/wg0.conf
        systemctl enable --now wg-quick@wg0.service
      fi

    elif [ "$subchoice" = "1-b" ]; then
      read -p "Enter config file location: " cfgfile
      sed -i "s/-o eth0/-o $int/g" "$cfgfile"
      read port < "$cfgfile"
      port=$(echo "$port" | grep -Eo 'ListenPort +=[0-9]+')
      port=${port#*=}
      mv "$cfgfile" /etc/wireguard/
      wgname=${cfgfile##*/}
      wgname=${wgname%.*}
      systemctl enable --now "wg-quick@$wgname.service"
    fi

  elif [ "$choice" = "2" ]; then
    read -p "WireGuard port (default = 51820): " port
    read -p "Enter host IP: " hostip
  fi

  mv WGI/udp2raw-tunnel /usr/local/bin/udp2raw-tunnel
  chmod uo+x /usr/local/bin/udp2raw-tunnel/udp2raw
  setcap cap_net_raw+ep /usr/local/bin/udp2raw-tunnel/udp2raw
  
  read -p "udp2raw port: " udpp
  read -p "udp2raw password: " udpk
  read -p "udp2raw mode (1. faketcp 2. udp 3. icmp): " udpmode

  if [ "$choice" = "1" ]; then
    echo "[Unit]
Description=Tunnel WireGuard with udp2raw  
After=network.target

[Service]  
Type=simple
User=root
ExecStart=/usr/local/bin/udp2raw-tunnel/udp2raw -s -l0.0.0.0:$udpp -r 127.0.0.1:$port -k $udpk --raw-mode $udpmode -a --cipher-mode xor --auth-mode simple
Restart=no

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/udp2raw.service

    systemctl enable --now udp2raw

  elif [ "$choice" = "2" ]; then

    echo "[Unit]  
Description=Tunnel WireGuard with udp2raw
After=network.target

[Service]
Type=simple  
User=root
ExecStart=/usr/local/bin/udp2raw-tunnel/udp2raw -c -l0.0.0.0:$port -r$hostip:$udpp -k $udpk --raw-mode $udpmode -a --cipher-mode xor --auth-mode simple
Restart=no
   
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/udp2raw.service

    systemctl enable --now udp2raw
  fi

  if [ "$choice" = "1" ]; then
    
    mv WGI/wgdashboard wgdashboard
    cd wgdashboard/src
    apt-get -y install python3-pip
    apt install gunicorn -y
    pip install -r requirements.txt
    pip install apscheduler
    chmod u+x wgd.sh
    ./wgd.sh install
    chmod -R 755 /etc/wireguard
    ifconfig
    ./wgd.sh start
    cd
    mv WGI/wg-dashboard.service /etc/systemd/system/wg-dashboard.service
    chmod 664 /etc/systemd/system/wg-dashboard.service
    systemctl daemon-reload
    systemctl enable wg-dashboard.service

    echo "wait for 30 seconds..."
    sleep 33
    systemctl start wg-dashboard.service
    if systemctl status wg-dashboard.service | grep -q 'active (running)'; then
      echo "ALL DONE!"
    else
      echo "wait a couple of minutes for WGD service to start..."
      sleep 120
      systemctl start wg-dashboard.service
    fi

  elif [ "$choice" = "1-b" ]; then
    systemctl disable --now wg-dashboard.service
    wgdashboard/src/wgd.sh stop
    read -p "Enter .ini file location: " inifile
    rm wgdashboard/src/wg-dashboard.ini
    mv "$inifile" wgdashboard/src/wg-dashboard.ini
    read -p "Enter database file location: " dbfile
    mv "$dbfile" wgdashboard/src/db/wgdashboard.db
    wg-quick save "$wgname"
    wgdashboard/src/wgd.sh start
    wg-quick save "$wgname"
    systemctl enable --now wg-dashboard.service
  fi

elif [ "$choice" = "3" ]; then

  read -p "WireGuard port (default = 51820): " port
  read -p "udp2raw port: " udpp
  read -p "udp2raw password: " udpk 
  read -p "udp2raw mode (1. faketcp 2. udp 3. icmp): " udpmode
  read -p "Host IP: " hostip

  echo "[Unit]  
Description=Tunnel WireGuard with udp2raw
After=network.target

[Service]
Type=simple
User=root  
ExecStart=/usr/local/bin/udp2raw-tunnel/udp2raw -c -l0.0.0.0:$port -r$hostip:$udpp -k $udpk --raw-mode $udpmode -a --cipher-mode xor --auth-mode simple
Restart=no
   
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/udp2raw.service

  systemctl daemon-reload
  systemctl restart udp2raw

fi
