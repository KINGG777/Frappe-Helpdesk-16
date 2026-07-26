# Frappe Helpdesk v16 Deployment on Ubuntu 24.04

This guide explains how to deploy **Frappe Helpdesk v16** on **Ubuntu 24.04** using Docker, Apache Reverse Proxy, and Let's Encrypt SSL.

---

# Environment

- Ubuntu 24.04 LTS
- Docker Engine
- Docker Compose v2
- Apache2
- MariaDB
- Redis
- Custom Docker Image
- Frappe Helpdesk v16

---

# Prerequisites

Before starting, make sure you have:

- Ubuntu 24.04 Server
- Domain pointing to EC2 Public IP
- Root or sudo access
- Ports opened in Security Group / Firewall

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|

---

# Step 1 : Install Required Packages

Update the server

```bash
sudo apt update
sudo apt upgrade -y
```

Install required packages

```bash
sudo apt install -y \
docker.io \
docker-compose-v2 \
git \
apache2 \
certbot \
python3-certbot-apache
```

Enable Docker

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Add current user to Docker group

```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

# Verify Installation

Check Docker

```bash
docker --version
```

Example

```
Docker version 28.x.x
```

Check Docker Compose

```bash
docker compose version
```

Example

```
Docker Compose version v2.x.x
```

Check Git

```bash
git --version
```

Check Apache

```bash
apache2 -v
```

Check Certbot

```bash
certbot --version
```

Verify Docker Service

```bash
sudo systemctl status docker
```

Expected

```
Active: active (running)
```

---

# Step 2 : Clone Repository

Clone Frappe Docker

```bash
git clone https://github.com/frappe/frappe_docker.git
```

Move inside directory

```bash
cd frappe_docker
```

Verify

```bash
ls
```

Expected

```
compose.yaml
example.env
overrides/
images/
```

---

# Step 3 : Configure Environment

Copy environment file

```bash
cp example.env .env
```

Edit

```bash
nano .env
```

Modify only these values

```env
ERPNEXT_VERSION=v16.29.0

CUSTOM_IMAGE=kingg777/frappe-helpdesk
CUSTOM_TAG=16
PULL_POLICY=always

DB_PASSWORD=123

HTTP_PUBLISH_PORT=8080
```

Save and Exit

```
CTRL + O
ENTER
CTRL + X
```

---

# Verify .env

Run

```bash
cat .env
```

Verify

```
CUSTOM_IMAGE=kingg777/frappe-helpdesk

CUSTOM_TAG=16

HTTP_PUBLISH_PORT=8080
```

---

# Step 4 : Pull Custom Image

```bash
docker pull kingg777/frappe-helpdesk:16
```

Verify

```bash
docker images
```

Expected

```
kingg777/frappe-helpdesk
```

---

# Step 5 : Start Containers

Run

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

---

# Verify Containers

```bash
docker compose ps
```

Expected

```
backend

frontend

db

redis-cache

redis-queue

scheduler

websocket

proxy
```

---

## If Containers Fail

Check logs

```bash
docker compose logs
```

Restart

```bash
docker compose down

docker compose up -d
```

---

## If Port 8080 is Missing

Verify Proxy Container

```bash
docker compose ps
```

If proxy is missing

Run again

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

Without **compose.proxy.yaml**, port **8080** will not be exposed.

---

# Step 6 : Create Site

Create site

```bash
docker compose exec backend \
bench new-site \
--db-root-password 123 \
--admin-password Admin@123 \
--mariadb-user-host-login-scope="%" \
tic.pkdevops.online
```

When prompted

```
Enter mysql super user [root]:
```

Press

```
ENTER
```

When prompted

```
MySQL root password
```

Enter

```
123
```

---

# Verify Site

```bash
docker compose exec backend bench list-sites
```

Expected

```
tic.pkdevops.online
```

---

## Wrong Site Created?

Example

```
ticket.example.com
```

Delete

```bash
docker compose exec backend \
bench drop-site ticket.example.com \
--root-login root \
--root-password 123
```

When prompted

```
Type the site name to confirm
```

Enter

```
ticket.example.com
```

Verify

```bash
docker compose exec backend bench list-sites
```

Then recreate

```bash
docker compose exec backend \
bench new-site tic.pkdevops.online \
--db-root-password 123 \
--admin-password Admin@123
```

---

# Step 7 : Install Helpdesk

```bash
docker compose exec backend \
bench --site tic.pkdevops.online install-app helpdesk
```

Verify

```bash
docker compose exec backend \
bench --site tic.pkdevops.online list-apps
```

Expected

```
frappe

telephony

helpdesk
```

---

# Step 8 : Configure Default Site

```bash
docker compose exec backend \
bench set-config -g default_site tic.pkdevops.online
```

Restart

```bash
docker compose restart
```

Verify

```bash
docker compose exec backend \
cat sites/common_site_config.json
```

Expected

```json
{
 "default_site":"tic.pkdevops.online"
}
```

---

# Step 9 : Test Application Locally

After configuring the default site, verify that the application is accessible.

```bash
curl -H "Host: tic.pkdevops.online" http://127.0.0.1:8080
```

Expected

- HTML page returned
- Login page source code displayed

---

## Problem : "127.0.0.1 does not exist"

### Cause

Default site is not configured.

### Verify

```bash
docker compose exec backend \
cat sites/common_site_config.json
```

Expected

```json
{
 "default_site":"tic.pkdevops.online"
}
```

### Fix

```bash
docker compose exec backend \
bench set-config -g default_site tic.pkdevops.online

docker compose restart
```

Test again

```bash
curl -H "Host: tic.pkdevops.online" http://127.0.0.1:8080
```

---

## Problem : "404 Site Does Not Exist"

Check available sites

```bash
docker compose exec backend bench list-sites
```

Expected

```
tic.pkdevops.online
```

If the site name is incorrect, create the correct site or update the Apache configuration accordingly.

---

## Problem : "500 Internal Server Error"

Check backend logs

```bash
docker compose logs backend --tail=100
```

If you see

```
MySQLdb.OperationalError

Access denied for user
```

Continue below.

---

# Verify MariaDB User

Login

```bash
docker compose exec db mariadb -uroot -p123
```

Check database users

```sql
SELECT User,Host
FROM mysql.user;
```

Normally you should see

```
db_user      %
```

If you see

```
db_user      172.xx.xx.xx
```

continue below.

---

# Verify Site Database Credentials

```bash
docker compose exec backend \
cat sites/tic.pkdevops.online/site_config.json
```

Example

```json
{
 "db_name":"_36a698c3bd9f3229",
 "db_user":"_36a698c3bd9f3229",
 "db_password":"xxxxxxxx"
}
```

---

# Fix MariaDB User

Inside MariaDB

```sql
CREATE USER '_36a698c3bd9f3229'@'%'
IDENTIFIED BY 'your_password';

GRANT ALL PRIVILEGES
ON _36a698c3bd9f3229.*
TO '_36a698c3bd9f3229'@'%';

FLUSH PRIVILEGES;
```

Restart

```bash
docker compose restart backend frontend
```

Test again

```bash
curl -H "Host: tic.pkdevops.online" http://127.0.0.1:8080
```

---

# Important Note

During testing, this issue occurred only once.

A possible reason is:

- A previous site was created.
- The site was deleted.
- The MariaDB user remained.
- A new site reused the existing database user.

A fresh deployment on a new server did **not** reproduce this issue.

If the issue occurs again, verify whether an old MariaDB user already exists before applying the SQL fix.

---

# Step 10 : Configure Apache

Create Virtual Host

```bash
sudo nano /etc/apache2/sites-available/tic.pkdevops.online.conf
```

Paste

```apache
<VirtualHost *:80>

ServerName tic.pkdevops.online

ProxyPreserveHost On

ProxyPass / http://127.0.0.1:8080/
ProxyPassReverse / http://127.0.0.1:8080/

ErrorLog ${APACHE_LOG_DIR}/tic_error.log
CustomLog ${APACHE_LOG_DIR}/tic_access.log combined

</VirtualHost>
```

Save

```
CTRL + O
ENTER
CTRL + X
```

---

Enable Modules

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod rewrite
sudo a2enmod headers
```

Enable Site

```bash
sudo a2ensite tic.pkdevops.online.conf
```

Disable Default Site

```bash
sudo a2dissite 000-default.conf
```

Restart Apache

```bash
sudo systemctl restart apache2
```

---

# Verify Apache

```bash
apache2ctl -S
```

Expected

```
ServerName tic.pkdevops.online
```

---

## Problem : Wrong Virtual Host

Check enabled sites

```bash
ls /etc/apache2/sites-enabled
```

Remove wrong site

```bash
sudo a2dissite wrong-site.conf
```

Enable correct one

```bash
sudo a2ensite tic.pkdevops.online.conf
```

Restart

```bash
sudo systemctl restart apache2
```

---

# Step 11 : Configure HTTPS

Run

```bash
sudo certbot --apache
```

Choose

```
tic.pkdevops.online
```

Redirect HTTP to HTTPS

```
Yes
```

---

# Verify SSL

Open

```
https://tic.pkdevops.online
```

or

```bash
curl -I https://tic.pkdevops.online
```

Expected

```
HTTP/2 200
```

---

## Problem : NXDOMAIN

Example

```
DNS problem: NXDOMAIN looking up A
```

Check DNS

```bash
nslookup tic.pkdevops.online
```

or

```bash
dig tic.pkdevops.online
```

Expected

```
Public IP of EC2
```

If no IP is returned

Create an A Record

```
Host : tic

Type : A

Value : EC2 Public IP
```

Wait for DNS propagation.

Run Certbot again

```bash
sudo certbot --apache
```

---

# Final Verification

Verify Docker

```bash
docker compose ps
```

Verify Site

```bash
docker compose exec backend bench list-sites
```

Verify Apps

```bash
docker compose exec backend \
bench --site tic.pkdevops.online list-apps
```

Verify Apache

```bash
systemctl status apache2
```

Verify Docker

```bash
systemctl status docker
```

Verify SSL

```bash
curl -I https://tic.pkdevops.online
```

Open Browser

```
https://tic.pkdevops.online
```

---

# Login

Username

```
Administrator
```

Password

```
Admin@123
```

---

# Useful Commands

Restart Docker

```bash
docker compose restart
```

Stop Containers

```bash
docker compose down
```

Start Containers

```bash
docker compose up -d
```

View Logs

```bash
docker compose logs
```

Backend Logs

```bash
docker compose logs backend
```

MariaDB Login

```bash
docker compose exec db mariadb -uroot -p123
```

List Sites

```bash
docker compose exec backend bench list-sites
```

List Installed Apps

```bash
docker compose exec backend \
bench --site tic.pkdevops.online list-apps
```

Drop Site

```bash
docker compose exec backend \
bench drop-site tic.pkdevops.online \
--root-login root \
--root-password 123
```

Restart Apache

```bash
sudo systemctl restart apache2
```

Restart Docker Service

```bash
sudo systemctl restart docker
```

---

# Deployment Completed Successfully

Your Frappe Helpdesk v16 installation is now running with:

- Ubuntu 24.04
- Docker
- MariaDB
- Redis
- Apache Reverse Proxy
- HTTPS (Let's Encrypt)
- Custom Docker Image
- Frappe Helpdesk v16
