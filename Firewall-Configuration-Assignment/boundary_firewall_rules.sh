#!/bin/bash

#These are some constants for better readability and maintainability of the code

IPTABLES="/sbin/iptables"
BOUNDARY_PUBLIC="192.168.0.2"
BOUNDARY_PRIVATE="10.47.74.254"
EXTERNAL_DNS="10.47.74.53"
EXTERNAL_WEB="10.47.74.80"
EXTERNAL_MAIL="10.47.74.25"
TRUSTED_SERVER_1="192.168.0.1"
CLUSTER_SERVER="10.47.74.252"

EXT_DMZ_IP_RANGE="10.47.74.0/24"
INT_DMZ_IP_RANGE="192.168.4.0/24"
CLUSTER_MACHINES_IP_RANGE="192.168.37.0/24"
USER_MACHINES_IP_RANGE="192.168.74.0/23"

#Before any new edit to the rules we need to flush the previous rules to avoid problems by forgetting in some chains rules that might have been problematic in the past
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

#To prevent IP spoofing we dont expect anthing coming from the internet to interface eth0 of the boundary firewall to have as source one of the IPs of the companys network
#so we have to drop those packets
$IPTABLES -A FORWARD -i eth0 -s $EXT_DMZ_IP_RANGE -j DROP
$IPTABLES -A FORWARD -i eth0 -s $INT_DMZ_IP_RANGE -j DROP
$IPTABLES -A FORWARD -i eth0 -s $CLUSTER_MACHINES_IP_RANGE -j DROP
$IPTABLES -A FORWARD -i eth0 -s $USER_MACHINES_IP_RANGE -j DROP

#If the connection has passed before just accept it
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

#This rules idea to not allow the external DNS to resolve names for internal DMZ systems is seen in forums and adapted as the task required
$IPTABLES -A FORWARD -i eth0 -p udp --dport 53 -m string --algo bm --string "fwcluster" -j ACCEPT
$IPTABLES -A FORWARD -i eth0 -p udp --dport 53 -m string --algo bm --string  ! "ext" -j DROP

#If the packet coming from the internet is destined to the external dns in the correct port that the service is running on the correct protocol I accept it
$IPTABLES -A FORWARD -i eth0 -o eth1 -p udp -d $EXTERNAL_DNS --dport 53 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#This rule is to allow zone transfers from the external systems, in the policies was mentioned that only a set of trusted servers should perform zone transfers to the external dns so for testing purpose
#I have placed the LX machine as a trusted server
$IPTABLES -A FORWARD -i eth0 -o eth1 -p tcp -s $TRUSTED_SERVER_1 --dport 53  -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#this rule is to accept incoming http requests that are destined to the external web server in the correspongin port which is 80 and using the proper protocol which is tcp
$IPTABLES -A FORWARD -i eth0 -o eth1 -p tcp -d $EXTERNAL_WEB --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#this rule is to allow requests from the internal proxy to go out to HTTP servers
$IPTABLES -A FORWARD -i eth1 -o eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#this rule is to accepts incoming mail destined to the external mail server
$IPTABLES -A FORWARD -i eth0 -o eth1 -p tcp -d $EXTERNAL_MAIL --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#this rule is to allow the internal systems to send mail to the users in the internet
$IPTABLES -A FORWARD -i eth1 -p tcp -d 0/0 --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#this rule is to allow external clients to perform SSH login to the cluster machine
$IPTABLES -A FORWARD -i eth0 -p tcp -d $CLUSTER_SERVER --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 

#this rule is neccessary
$IPTABLES -A FORWARD -i eth1 -o ! eth0 -j ACCEPT

exit 0
