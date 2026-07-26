# Frappe Helpdesk v16 Deployment on Ubuntu 24.04

Deploy **Frappe Helpdesk v16** on **Ubuntu 24.04** using **Docker**, **Apache Reverse Proxy**, and **Let's Encrypt SSL**.

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

- Ubuntu 24.04 Server
- Domain pointing to your EC2 Public IP
- Root or sudo access

## Required Ports

| Port | Purpose |
|------|----------|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |

---

# Step 1 - Install Required Packages

Update the server.

```bash
sudo apt update && sudo apt upgrade -y
```

Install required packages.

```bash
sudo apt install -y \
docker.io \
docker-compose-v2 \
git \
apache2 \
certbot \
python3-certbot-apache
```

Enable Docker.

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Add your user to the Docker group.

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Verify Installation

```bash
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"
echo "Git: $(git --version)"
echo "Apache: $(apache2 -v | head -1)"
echo "Certbot: $(certbot --version)"
echo "Docker Service: $(systemctl is-active docker)"
```

Expected:

```
Docker: Docker version ...
Compose: Docker Compose version ...
Git: git version ...
Apache: Server version: Apache...
Certbot: certbot ...
Docker Service: active
```

---

# Step 2 - Clone Repository

Clone the repository.

```bash
git clone https://github.com/frappe/frappe_docker.git
```

Move into the project.

```bash
cd frappe_docker
```

Verify.

```bash
ls
```

Expected:

```
compose.yaml
example.env
images/
overrides/
```

---

# Step 3 - Configure Environment

Copy the example environment file.

```bash
cp example.env .env
```

Edit the configuration.

```bash
nano .env
```

Update only these values.

```env
ERPNEXT_VERSION=v16.29.0

CUSTOM_IMAGE=kingg777/frappe-helpdesk
CUSTOM_TAG=16
PULL_POLICY=always

DB_PASSWORD=123

HTTP_PUBLISH_PORT=8080
```

Save and exit.

```
CTRL + O
ENTER
CTRL + X
```

Verify.

```bash
cat .env
```

Expected:

```env
CUSTOM_IMAGE=kingg777/frappe-helpdesk
CUSTOM_TAG=16
HTTP_PUBLISH_PORT=8080
```

---

# Step 4 - Pull Custom Image

```bash
docker pull kingg777/frappe-helpdesk:16
```

Verify.

```bash
docker images
```

Expected:

```
kingg777/frappe-helpdesk
```

---

# Step 5 - Start Containers

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

Verify.

```bash
docker compose ps
```

Expected:

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

# Step 6 - Create Site

```bash
docker compose exec backend \
bench new-site \
--db-root-password 123 \
--admin-password Admin@123 \
--mariadb-user-host-login-scope="%" \
tic.pkdevops.online
```

When prompted:

```
Enter mysql super user [root]:
```

Press **ENTER**.

When prompted:

```
MySQL root password:
```

Enter:

```
123
```

Verify.

```bash
docker compose exec backend bench list-sites
```

Expected:

```
tic.pkdevops.online
```

---

# Step 7 - Install Helpdesk

```bash
docker compose exec backend \
bench --site tic.pkdevops.online install-app helpdesk
```

Verify.

```bash
docker compose exec backend \
bench --site tic.pkdevops.online list-apps
```

Expected:

```
frappe
telephony
helpdesk
```

---

# Step 8 - Configure Default Site

```bash
docker compose exec backend \
bench set-config -g default_site tic.pkdevops.online
```

Restart containers.

```bash
docker compose restart
```

Verify.

```bash
docker compose exec backend \
cat sites/common_site_config.json
```

Expected:

```json
{
  "default_site": "tic.pkdevops.online"
}
```

---

# Step 9 - Test Local Access

```bash
curl -H "Host: tic.pkdevops.online" http://127.0.0.1:8080
```

Expected:

- HTML response
- Login page source

---

# Step 10 - Configure Apache

Create the Virtual Host.

```bash
sudo nano /etc/apache2/sites-available/tic.pkdevops.online.conf
```

Paste:

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

Enable modules.

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod rewrite
sudo a2enmod headers
```

Enable the site.

```bash
sudo a2ensite tic.pkdevops.online.conf
```

Disable the default site.

```bash
sudo a2dissite 000-default.conf
```

Restart Apache.

```bash
sudo systemctl restart apache2
```

Verify.

```bash
apache2ctl -S
```

Expected:

```
ServerName tic.pkdevops.online
```

---

# Step 11 - Configure HTTPS

Run Certbot.

```bash
sudo certbot --apache
```

Select:

```
tic.pkdevops.online
```

Choose:

```
Redirect HTTP to HTTPS: Yes
```
# Final Verification

Verify the deployment.

```bash
docker compose ps

docker compose exec backend bench list-sites

docker compose exec backend \
bench --site tic.pkdevops.online list-apps

systemctl is-active apache2

systemctl is-active docker

curl -I https://tic.pkdevops.online
```

Expected:

```
All containers running
tic.pkdevops.online
frappe
telephony
helpdesk
active
active
HTTP/2 200
```

---

# Fixes

## Containers Not Starting

Check logs.

```bash
docker compose logs
```

Restart containers.

```bash
docker compose down
docker compose up -d
```

---

## Port 8080 Not Exposed

Verify containers.

```bash
docker compose ps
```

If the **proxy** container is missing, start the stack again.

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

---

## Default Site Not Configured

Error:

```
127.0.0.1 does not exist
```

Verify.

```bash
docker compose exec backend \
cat sites/common_site_config.json
```

Expected.

```json
{
  "default_site":"tic.pkdevops.online"
}
```

Fix.

```bash
docker compose exec backend \
bench set-config -g default_site tic.pkdevops.online

docker compose restart
```

Test again.

```bash
curl -H "Host: tic.pkdevops.online" http://127.0.0.1:8080
```

---

## 404 Site Does Not Exist

List available sites.

```bash
docker compose exec backend bench list-sites
```

If the site is missing, create it again.

---

## Wrong Site Created

Drop the site.

```bash
docker compose exec backend \
bench drop-site ticket.example.com \
--root-login root \
--root-password 123
```

Recreate it.

```bash
docker compose exec backend \
bench new-site \
--db-root-password 123 \
--admin-password Admin@123 \
--mariadb-user-host-login-scope="%" \
tic.pkdevops.online
```

---

## 500 Internal Server Error

Check backend logs.

```bash
docker compose logs backend --tail=100
```

If you see:

```
MySQLdb.OperationalError
Access denied for user
```

Verify the MariaDB user.

```bash
docker compose exec db mariadb -uroot -p123
```

```sql
SELECT User, Host
FROM mysql.user;
```

Expected:

```
db_user    %
```

If the user is created with an IP address instead of `%`, verify the site credentials.

```bash
docker compose exec backend \
cat sites/tic.pkdevops.online/site_config.json
```

Create the MariaDB user again.

```sql
CREATE USER '_36a698c3bd9f3229'@'%'
IDENTIFIED BY 'your_password';

GRANT ALL PRIVILEGES
ON `_36a698c3bd9f3229`.*
TO '_36a698c3bd9f3229'@'%';

FLUSH PRIVILEGES;
```

Restart services.

```bash
docker compose restart backend frontend
```

---

## Wrong Apache Virtual Host

List enabled sites.

```bash
ls /etc/apache2/sites-enabled
```

Disable the incorrect site.

```bash
sudo a2dissite wrong-site.conf
```

Enable the correct site.

```bash
sudo a2ensite tic.pkdevops.online.conf
```

Restart Apache.

```bash
sudo systemctl restart apache2
```

---

## SSL Certificate Failed (NXDOMAIN)

Check DNS.

```bash
nslookup tic.pkdevops.online
```

or

```bash
dig tic.pkdevops.online
```

Expected:

```
EC2 Public IP
```

If no IP is returned, create an **A Record**.

| Record | Value |
|--------|-------|
| Host | tic |
| Type | A |
| Value | EC2 Public IP |

Wait for DNS propagation and run Certbot again.

```bash
sudo certbot --apache
```

---

# Useful Commands

Restart containers.

```bash
docker compose restart
```

Stop containers.

```bash
docker compose down
```

Start containers.

```bash
docker compose up -d
```

View logs.

```bash
docker compose logs
```

Backend logs.

```bash
docker compose logs backend
```

Login to MariaDB.

```bash
docker compose exec db mariadb -uroot -p123
```

List sites.

```bash
docker compose exec backend bench list-sites
```

List installed apps.

```bash
docker compose exec backend \
bench --site tic.pkdevops.online list-apps
```

Restart Apache.

```bash
sudo systemctl restart apache2
```

Restart Docker.

```bash
sudo systemctl restart docker
```

---

# Login

**URL**

```
https://tic.pkdevops.online
```

**Username**

```
Administrator
```

**Password**

```
Admin@123
```

---

# Deployment Completed

Your deployment is now running with:

- Ubuntu 24.04
- Docker Engine
- Docker Compose v2
- MariaDB
- Redis
- Apache Reverse Proxy
- Let's Encrypt SSL
- Frappe Helpdesk v16
- Custom Docker Image
