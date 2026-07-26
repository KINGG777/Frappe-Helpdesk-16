# Restore Existing Deployment on a New Server

This guide restores an existing Frappe Helpdesk deployment from a backup without creating a new site.

## 1. Install Required Packages

```bash
sudo apt update

sudo apt install -y \
docker.io \
docker-compose-v2 \
git \
apache2 \
certbot \
python3-certbot-apache
```

Enable Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Verify:

```bash
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"
echo "Apache: $(apache2 -v | head -1)"
echo "Certbot: $(certbot --version)"
```

---

## 2. Clone Repository

```bash
git clone https://github.com/KINGG777/Frappe-Helpdesk-16.git

cd Frappe-Helpdesk-16
```

---

## 3. Restore Backup

Restore your backup to:

```text
/opt/frappe/
├── mariadb
└── sites
```

Example:

```bash
sudo cp -r backup/mariadb /opt/frappe/
sudo cp -r backup/sites /opt/frappe/
```

Verify:

```bash
ls -l /opt/frappe
```

Expected:

```text
mariadb
sites
```

---

## 4. Set Permissions

MariaDB:

```bash
MYSQL_UID=$(docker run --rm mariadb:11.8 id -u mysql)
MYSQL_GID=$(docker run --rm mariadb:11.8 id -g mysql)

sudo chown -R ${MYSQL_UID}:${MYSQL_GID} /opt/frappe/mariadb
```

Sites:

```bash
sudo chown -R 1000:1000 /opt/frappe/sites
```

Verify:

```bash
ls -ln /opt/frappe
```

---

## 5. Pull Images

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
pull
```

---

## 6. Start Containers

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

Wait 1–2 minutes.

---

## 7. Verify Site

Do **NOT** create a new site.

```bash
docker compose exec backend bench list-sites
```

Example:

```text
Available sites:
* tic.pkdevops.online
```

---

# Apache Reverse Proxy

## 8. Create Apache Virtual Host

```bash
sudo nano /etc/apache2/sites-available/tic.pkdevops.online.conf
```

Paste:

```apache
<VirtualHost *:80>

    ServerName tic.pkdevops.online

    ProxyPreserveHost On
    ProxyRequests Off

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    ErrorLog ${APACHE_LOG_DIR}/tic_error.log
    CustomLog ${APACHE_LOG_DIR}/tic_access.log combined

</VirtualHost>
```

Save and exit.

---

## 9. Enable Required Modules

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers
```

---

## 10. Enable Site

```bash
sudo a2ensite tic.pkdevops.online.conf
```

Disable default site:

```bash
sudo a2dissite 000-default.conf
```

Restart Apache:

```bash
sudo systemctl restart apache2
```

Check:

```bash
sudo systemctl status apache2
```

---

## 11. Configure DNS

Create an **A Record**:

```
Host: tic
Type: A
Value: YOUR_SERVER_PUBLIC_IP
```

Wait until:

```bash
ping tic.pkdevops.online
```

returns your server IP.

---

# Enable HTTPS

## 12. Generate SSL Certificate

```bash
sudo certbot --apache
```

Choose:

```
tic.pkdevops.online
```

Select:

```
Redirect HTTP to HTTPS
```

---

## 13. Verify SSL

```bash
sudo certbot certificates
```

Renewal test:

```bash
sudo certbot renew --dry-run
```

---

# Verify Deployment

Check containers:

```bash
docker ps
```

Check available sites:

```bash
docker compose exec backend bench list-sites
```

Verify MariaDB mount:

```bash
docker inspect frappe-helpdesk-16-db-1 \
--format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Expected:

```text
/opt/frappe/mariadb -> /var/lib/mysql
```

Verify Sites mount:

```bash
docker inspect frappe-helpdesk-16-backend-1 \
--format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Expected:

```text
/opt/frappe/sites -> /home/frappe/frappe-bench/sites
```

---

# Access Helpdesk

```
https://tic.pkdevops.online
```

Your existing Helpdesk site, users, tickets, attachments, and database will be restored.

> **Important**
>
> - Fresh Installation → Run `bench new-site`
> - Restoring from Backup → Do **NOT** run `bench new-site`
> - Keep the `/opt/frappe` directory to preserve all data.
