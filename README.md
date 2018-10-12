# Orchestration and Automation of Initial Computer Security Incident Response

## Overview
In order to avoid data breach, a quick and proper response against a computer security incident is important.
To this end, we have implemented the system, *autocsirt*, that orchestrates and automates an initial incident response.
The autocsirt has functions such as:
* check and parse a mail from a Security Operation Center (SOC)
* create a ticket for a incident
* isolate a suspicious host
* notify an administrator or user who is in charge of a suspicious host of an incident
* record above all operations in a ticket
Note that SOC functions such that anomaly detection, incident detection themself or others are out of scope the autocsirt and future work.

## Intersting features
* scraping NII-SOCS portal site in order to obtain detailed information that is not included in a notification mail.
* CLIs of AlaxalA, Cisco, NEC IX switches, Paloalto firewall and Aruba mobility controller are supported.
* multiple isolation methods are supported: port shutdown for fixed hosts and confinment and MAC address filtering at a core switch for wired or wireless mobile hosts.

## How to install
### Redmine
You must install and configure Redmine first.
Custom fields listed in `lib/issue.rb` should be created in Redmine.

### Ruby
You have to install ruby version 1.9.x or later using rbenv.
Note that a separated tool called `netutils` should be installed as well.

```
% gem prawn-table install
% gem mongo install
% gem nokogiri install
% cd /home/hogehoge
% git clone https://github.com/ohmori7/netutils.git
% git clone https://github.com/ohmori7/autocsirt.git
```

## Configuration
### main configuration
* config/config.rb
### IP address allocation
* db/csirt.csv: PoC of CSIRT
* db/ipaddress.csv: IP address allocation and CSIRT
* db/ipaddresstype.csv: network media type and IP address such as wired, wireless, and so on.
### Alert mail template
* config/alert-template.rb
### Report mail template
* config/report-template.rb

## How to run

```
% bin/mail-check
```

## Supported SOC mail
* NTTCom WideAngle
* NII-SOCS

## TODO
* gemify
* configuration separation
* make Redmine items configurable
