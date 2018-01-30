#!/bin/bash

#These are some constants for better readability and maintainability of the code
IPTABLES="/sbin/iptables"
CLUSTER_PUBLIC="10.47.74.252"
CLUSTER_PRIVATE="192.168.37.254"
EXTERNAL_DNS="10.47.74.53"
EXTERNAL_WEB="10.47.74.80"
EXTERNAL_MAIL="10.47.74.25"
CLUSTER_MACHINES="192.168.37.0/24"

#Before any new edit to the rules we need to flush the previous rules to avoid problems by forgeting in some chains rules that might have been problematic in the past
#These are standard flushing rules and are always suggested to be performed first
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X

#The default policy on each chain should be set to DROP, so that packets that do not fit in the policy should not be allowed
$IPTABLES -P INPUT DROP
$IPTABLES -P OUTPUT DROP
$IPTABLES -P FORWARD DROP

#Allow standard localhost loopbacks
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

##If the connection has passed before just accept it
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

#This rule alows cluster machines to perfrom dns request to the external dns server
$IPTABLES -A FORWARD -i eth1 -o eth0 -p udp -d $EXTERNAL_DNS --dport 53 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#This rule allows users from basically anywehre to connect via ssh to the cluster frontend machine, this rule goes to the INPUT chain since the firewall machine itself provides the ssh service
$IPTABLES -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
#This rule allows content generated from the ssh service to go out of the machine and it should be performed on the OUTPUT chain
$IPTABLES -A OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED,RELATED -j ACCEPT

#This rules allow the cluster frontend to perform ssh to the cluster machine, test their integrity by using ping requests
$IPTABLES -A OUTPUT -p tcp -d $CLUSTER_MACHINES --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p icmp -d $CLUSTER_MACHINES --icmp-type echo-request -j ACCEPT
$IPTABLES -A INPUT -p icmp -s $CLUSTER_MACHINES --icmp-type echo-reply -j ACCEPT

#This rule just allows the cluster machines to send mail to the mailservers they want to, as expressed in the policy, so just need to check if the those requests are from the cluster machines and are going
#to an address on port 25 which is standard for SMTP
$IPTABLES -A FORWARD -i eth1 -p tcp -s $CLUSTER_MACHINES --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

exit 0
