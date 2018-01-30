#!/bin/bash

IPTABLES="/sbin/iptables"
INTERNAL_PUBLIC="192.168.47.253"
INTERNAL_PRIVATE="192.168.47.254"
INTERNAL_DNS="192.168.47.53"
INTERNAL_PROXY="192.168.47.80"
INTERNAL_ADMIN="192.168.47.99"

#Before any new edit to the rules we need to flush the previous rules to avoid problems by forgetting some chain rules that might have been problematic in the past and do not fit the new policy
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X

#The default policy on each chain should be set to DROP, so that packets that do not fit the policy shold not be allowed
$IPTABLES -P INPUT DROP
$IPTABLES -P OUTPUT DROP
$IPTABLES -P FORWARD DROP

#Allow standard localhost loopbacks
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

#Accept previously established or related connections
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

#Allow DNS lookups from the user network to the internal dns server
$IPTABLES -A FORWARD -i eth1 -o eth0 -p udp -d $INTERNAL_DNS --dport 53 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#Allow the users in the user network to connect with the internal proxy server
$IPTABLES -A FORWARD -i eth1 -p tcp -d $INTERNAL_PROXY --dport 8080 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#This rule is to allow POP3S which is post office protocol that uses SSL which as seen on port assignments its default port is 995
#so I allow tcp connection requests that are destined to the internal admin server on port 995
$IPTABLES -A FORWARD -i eth1 -o eth0 -p tcp -d $INTERNAL_ADMIN --dport 995 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 

#Allow users in the user network to send mails to the internal admin on standard SMTP port 25 using standard tcp protocol
$IPTABLES -A FORWARD -i eth1 -o eth0 -p tcp -d $INTERNAL_ADMIN --dport 25 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#Allow outgoing SSH connection that are using the correct protocol which is tcp and destined to the standard SSH port which is 22
#This rule will allow the requests for SSH connection to a machine go out of the user network, then there is responsibility of also other firewalls along the way to let them go through
$IPTABLES -A FORWARD -i eth1 -p tcp --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#This rule is neccessary due to some packets being bradcasted to all the machines during a request
#I think it has to do with the address resolution protocol as far as I have inspected using tcpdump and consulting online forums on which I came up with this rule
$IPTABLES -A FORWARD -i eth1 -o ! eth0 -j ACCEPT

exit 0
