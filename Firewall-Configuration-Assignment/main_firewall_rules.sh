#!/bin/bash

IPTABLES="/sbin/iptables"
MAIN_PUBLIC="10.47,74.253"
MAIN_PRIVATE="192.168.47.254"
EXTERNAL_DNS="10.47.74.53"
EXTERNAL_WEB="10.47.74.80"
EXTERNAL_MAIL="10.47.74.25"

#Before any new edit to the rules we need to flush the previous rules to avoid problems by forgetting in some chains rules that might have been problematic in the past
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X

#The default policy on each chain shoul be DROP, so that packets that do not fit in the policy should not be allowed
$IPTABLES -P INPUT DROP
$IPTABLES -P OUTPUT DROP
$IPTABLES -P FORWARD DROP

#Here are just two standard rules to allow localhost loopbacks
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

#Accept already established or related connections to go through
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

#Allow the SMTP mail server to forward the mails to the admin server in the internal DMZ
$IPTABLES -A FORWARD -i eth0 -o eth1 -p tcp --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#Allow the internal DMZ to send mails to the outer network
$IPTABLES -A FORWARD -i eth1 -o eth0 -p tcp --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#Allow SSH connection destined for the systems in the external DMZ
$IPTABLES -A FORWARD -i eth1 -p tcp --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

$IPTABLES -A FORWARD -p tcp --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

$IPTABLES -A FORWARD -i eth1 -o ! eth0 -j ACCEPT
exit 0
