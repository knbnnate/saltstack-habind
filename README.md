# saltstack-habind
Name resolution configuration
This repository contains saltstack code for configuration of BIND 9.
The intent is to resolve names according to query source, across disparate networks that mirror services for high availability.

e.g.

- You have two datacenters on separate sides of the globe: alpha and beta. 
- Site alpha uses IP space 192.168.1.0/24
- Site beta uses IP space 172.16.1.0/24
- Your IP addressing scheme simply mirrors based on the back octet of the IP, so:
- slt1.alpha.ha is your alpha datacenter salt master on IP 192.168.1.10
- slt1.beta.ha is your beta datacenter salt master on IP 172.16.1.10
- ns1.alpha.ha is your alpha datacenter DNS server on IP 192.168.1.11
- ns1.beta.ha is your alpha datacenter DNS server on IP 172.16.1.11

This code makes it easy to configure bind so that salt.cname.ha is always the CNAME for the salt master at the local datacenter.
- salt.cname.ha is a CNAME to slt1.cname.ha
- slt1.cname.ha is a CNAME to slt1.alpha.ha when a query comes from 192.168.1.0/24
- slt1.cname.ha is a CNAME to slt1.beta.ha when a query comes from 172.16.1.0/24
- ns1.cname.ha is a CNAME to ns1.alpha.ha when a query comes from 192.168.1.0/24
- ns1.cname.ha is a CNAME to ns1.beta.ha when a query comes from 172.16.1.0/24
- PTR records exist for both 192.168.1.10 and 172.16.1.10
- PTR records exist for both 192.168.1.11 and 172.16.1.11
- Queries to any zones not managed as part of the HA BIND configuration forward elsewhere, e.g. 172.17.1.10

The configuration would simply be this pillar file:

habind:
  forwarders:
    - 172.17.1.10
  dcs:
    - alpha
    - beta
  cnames: cname
  nameservers:
    - ns1
  map:
    alpha:
      acl: '192.168.1.0/24'
      forward_octets: '192.168.1'
      reverse_octets: '1.192.168'
    back_octets:
      slt1: 10
      ns1: 11
    services:
      salt: slt1

Resolution would look like:
```
vagrant@foo ~ # ssh 192.168.1.123 nslookup salt.cname.ha 192.168.1.11
vagrant@192.168.1.123's password:
Server:         192.168.1.11
Address:        192.168.1.11#53
salt.cname.ha   canonical name = slt1.cname.ha.
slt1.cname.ha   canonical name = slt1.alpha.ha.
Name:   slt1.alpha.ha
Address: 192.168.1.10
vagrant@foo ~ # ssh 172.16.1.123 nslookup salt.cname.ha 192.168.1.11
vagrant@172.16.1.123's password:
Server:         192.168.1.11
Address:        192.168.1.11#53
salt.cname.ha   canonical name = slt1.cname.ha.
slt1.cname.ha   canonical name = slt1.beta.ha.
Name:   slt1.beta.ha
Address: 172.16.1.10
vagrant@foo ~ # ssh 192.168.1.123 nslookup salt.cname.ha 172.16.1.11
vagrant@192.168.1.123's password:
Server:         172.16.1.11
Address:        172.16.1.11#53
salt.cname.ha   canonical name = slt1.cname.ha.
slt1.cname.ha   canonical name = slt1.alpha.ha.
Name:   slt1.alpha.ha
Address: 192.168.1.10
vagrant@foo ~ # ssh 172.16.1.123 nslookup salt.cname.ha 172.16.1.11
vagrant@172.16.1.123's password:
Server:         172.16.1.11
Address:        172.16.1.11#53
salt.cname.ha   canonical name = slt1.cname.ha.
slt1.cname.ha   canonical name = slt1.beta.ha.
Name:   slt1.beta.ha
Address: 172.16.1.10
```
