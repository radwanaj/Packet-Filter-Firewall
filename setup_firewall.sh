#!/bin/bash

# custom firewall setup
# sudo ./setup_firewall.sh

sysctl -w net.ipv4.ip_forward=1

# Clear old rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default DROP policy 
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP



# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Established traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT



# Client -> Gateway ping
iptables -A INPUT -i enp0s3 -p icmp --icmp-type echo-request -s 192.168.0.10 -d 192.168.0.100 -j ACCEPT
iptables -A OUTPUT -o enp0s3 -p icmp --icmp-type echo-reply -s 192.168.0.100 -d 192.168.0.10 -j ACCEPT

# Server -> Gateway ping 
iptables -A INPUT -i enp0s8 -p icmp --icmp-type echo-request -s 10.0.0.10 -d 10.0.0.100 -j ACCEPT
iptables -A OUTPUT -o enp0s8 -p icmp --icmp-type echo-reply -s 10.0.0.100 -d 10.0.0.10 -j ACCEPT

# Server <-> Client ping through gateway
iptables -A FORWARD -i enp0s8 -o enp0s3 -p icmp -s 10.0.0.10 -d 192.168.0.10 -j ACCEPT
iptables -A FORWARD -i enp0s3 -o enp0s8 -p icmp -s 192.168.0.10 -d 10.0.0.10 -j ACCEPT



iptables -A INPUT -i enp0s3 -p tcp --dport 22 -s 192.168.0.10 -d 192.168.0.100 -m conntrack --ctstate NEW -j ACCEPT
iptables -A OUTPUT -o enp0s3 -p tcp --sport 22 -s 192.168.0.100 -d 192.168.0.10 -j ACCEPT



# HTTP (port 80)
iptables -t nat -A PREROUTING -i enp0s3 -p tcp -d 192.168.0.100 --dport 80 -j DNAT --to-destination 10.0.0.10:80
iptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp -d 10.0.0.10 --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# FTP control (port 21)
iptables -t nat -A PREROUTING -i enp0s3 -p tcp -d 192.168.0.100 --dport 21 -j DNAT --to-destination 10.0.0.10:21
iptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp -d 10.0.0.10 --dport 21 -m conntrack --ctstate NEW -j ACCEPT

# FTP passive ports (30000–30099)
iptables -t nat -A PREROUTING -i enp0s3 -p tcp -d 192.168.0.100 --dport 30000:30099 -j DNAT --to-destination 10.0.0.10
iptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp -d 10.0.0.10 --dport 30000:30099 -m conntrack --ctstate NEW -j ACCEPT



# SNAT so client sees replies from gateway IP
iptables -t nat -A POSTROUTING -o enp0s3 -s 10.0.0.10 -j SNAT --to-source 192.168.0.100

# Allow server to access outside (Net3)
iptables -t nat -A POSTROUTING -o enp0s9 -s 10.0.0.10 -j MASQUERADE

iptables -A FORWARD -i enp0s8 -o enp0s9 -s 10.0.0.10 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s8 -d 10.0.0.10 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT