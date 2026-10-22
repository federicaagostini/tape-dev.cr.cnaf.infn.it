# Installation guide

Create a directory which hosts the StoRM configuration and clone this repo, e.g.

```bash
mkdir /etc/storm
cd /etc/storm
git clone https://github.com/federicaagostini/tape-dev.cr.cnaf.infn.it.git
```

Set the proper permission to the user with ID 1000 (requires sudo mode)

```bash
chown -R 1000:1000 /etc/storm
```

## Certificate

Ask for an IGTF certificate and place it into the working directory, with the proper permissions

```bash
cp <certificate.pem> /etc/storm/hostcert.pem
chmod 600 /etc/storm/hostcert.pem
cp <key.pem> /etc/storm/hostkey.pem
chmod 400 /etc/storm/hostkey.pem
```

## Trusted CAs

Create the EGI repofile `/etc/yum.repos.d/EGI-trustanchors.repo` with the following content (requires sudo mode)

```
# EGI Software Repository - REPO META (releaseId,repositoryId,repofileId) - (10824,-,2000)


[EGI-trustanchors]
name=EGI-trustanchors
baseurl=http://repository.egi.eu/sw/production/cas/1/current/
enabled=1
gpgcheck=1
gpgkey=http://repository.egi.eu/sw/production/cas/1/GPG-KEY-EUGridPMA-RPM-4
```

Install also the `epel-release` and update the dnf metadata with the new repos

```bash
dnf install epel-release
ndf update
```

Install the required packages

```bash
dnf install rsync ca-policy-egi-core fetch-crl
```

### Update trust anchors

This repo contains a script to populate the `/etc/grid-security/certificates` folder with IGTF certificates
and Certificate Revocation List. The script also builds a bundle understood by the operating system (e.g. _curl_)
in order to apply TLS handshake with also the IGTF certificates.

This script must be run periodically.

Make sure it has execution permissions

```bash
cd /etc/storm
chmod +x tape-dev.cr.cnaf.infn.it/trustanchor/update-trust-anchors.sh
```

and run it (requires sudo mode)

```bash
./tape-dev.cr.cnaf.infn.it/trustanchor/update-trust-anchors.sh
```

## Setup SA

Create a physical volume expected by the docker compose where we will add the `dteam` and `test.vo` folder
both for disk and tape (requires sudo mode):

```bash
mkdir -p /storage/disk
mkdir -p /storage/tape
mkdir /storage/disk/dteam
mkdir /storage/disk/test.vo
mkdir /storage/tape/dteam
mkdir /storage/tape/test.vo
```

The content of the `/storage` folder must be owned by the user with id 1000

```bash
chown -R 1000:1000 /storage/*
```

## Setup secrets

### StoRM WebDAV

In order so support login to StoRM WebDAV via browser through INDIGO IAM, you need to create a Client with authorization
code flow (*) and at least `openid` and `profile` scopes into the following IAMs:
- https://iam-dev.cloud.cnaf.infn.it
- https://dteam-auth.cern.ch

After registration, the IAMs will return a Client ID and Secret that you must save.
Create the secret file from the working directory

```bash
cd /etc/storm
touch tape-dev.cr.cnaf.infn.it/storm-webdav/webdav-secrets
```

and add the following content

```
DTEAM_CLIENT_ID=<client-id-from-dteam-auth>
DTEAM_CLIENT_SECRET=<client-secret-from-dteam-auth>
TESTVO_CLIENT_ID=<client-id-from-iam-dev>
TESTVO_CLIENT_SECRET=<client-secret-from-iam-dev>
```

(*) Both clients should have the following redirect URIs: `https://tape-dev.cr.cnaf.infn.it:8444/login/oauth2/code/dteam` and `https://tape-dev.cr.cnaf.infn.it:8444/login/oauth2/code/testvo`

### GEMSS

StoRM Tape exposes a `/recalltable` endpoint for GEMSS, which requires a GEMSS user and password. The same user/pwd
is allowed by NGINX through the _htpasswd_ file.

Install the necessary package to create a crypted file for NGINX

```bash
sudo dnf install httpd-tools
```

From the working directory, create the _htpasswd_ file

```bash
cd /etc/storm
htpasswd -bc tape-dev.cr.cnaf.infn.it/nginx/htpasswd <gemss-username> <gemss-password>
```

Now, save the same `<gemss-username>` and `<gemss-password>` in a secret file needed by GEMSS (at `tape-dev.cr.cnaf.infn.it/gemss/gemss-secrets.sh`)

```bash
GEMSS_USER=<gemss-username>
GEMSS_PWD=<gemss-password>
```

## Cron jobs

Two cron jobs are required to
- simulate GEMSS behavior, i.e. checking files to be migrated to tape, and also asking to StoRM Tape the list of files to recall
- simulate the garbage collector, which stubbifies the migrated files which are also still on disk.

Create the log folder for the Cron jobs with proper permission

```bash
mkdir /var/log/gemss
chown -R 1000:1000 /var/log/gemss
```

Make sure all GEMSS scripts have executive permissions

```bash
cd /etc/storm
chmod +x tape-dev.cr.cnaf.infn.it/gemss/gemss.sh
chmod +x tape-dev.cr.cnaf.infn.it/gemss/migrate_file.sh
chmod +x tape-dev.cr.cnaf.infn.it/gemss/recall_file.sh
chmod +x tape-dev.cr.cnaf.infn.it/gemss/stubbify.sh
```

and cross-check you do manage to run it (as user with ID 1000)

```bash
./tape-dev.cr.cnaf.infn.it/gemss/gemss.sh
./tape-dev.cr.cnaf.infn.it/gemss/stubbify.sh
```

You should see no output, but the `/var/log/gemss` folder filled with some new file.

Now you can add the two cron job (as user with ID 1000) with

```bash
crontab -e
```

and add the following configuration

```bash
PATH=/etc/storm/tape-dev.cr.cnaf.infn.it/gemss:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SHELL=/bin/bash

# Run gemss.sh every 15 minutes
*/15 * * * * /etc/storm/tape-dev.cr.cnaf.infn.it/gemss/gemss.sh >> /var/log/gemss/gemss_cron.log 2>&1

# Run stubbify.sh every 5 hours
0 */5 * * * /etc/storm/tape-dev.cr.cnaf.infn.it/gemss/stubbify.sh >> /var/log/gemss/stubbify_cron.log 2>&1
```

## Start Service

To start the service, enter in the `git` folder and issue the docker compose command

```bash
cd /etc/storm/tape-dev.cr.cnaf.infn.it
docker compose up -d
```

Unfortunately, at any machine restart this command must be run again.