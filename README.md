# Frappe Helpdesk v16 on Ubuntu 24.04

Deploy **Frappe Framework v16** with **Helpdesk** and **Telephony** using Docker, Apache Reverse Proxy and Let's Encrypt SSL.

---

# Prerequisites

- Ubuntu 24.04 LTS
- Minimum 4 GB RAM (8 GB Recommended)
- Minimum 25 GB Storage
- Domain/Subdomain pointing to your EC2 instance
- Sudo privileges

---

# 1. Install Required Packages

Update the server and install Apache, Certbot, Git and Docker from the official Docker repository.

```bash
sudo apt update

sudo apt install -y \
git \
apache2 \
certbot \
python3-certbot-apache

sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)

sudo apt install ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
-o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin
```

---

# 2. Verify Installation

```bash
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"
echo "Git: $(git --version)"
echo "Apache: $(apache2 -v | head -1)"
echo "Certbot: $(certbot --version)"
echo "Docker Service: $(systemctl is-active docker)"
echo "Docker Buildx: $(docker buildx version)"
```

---

# 3. Configure Docker

Enable Docker and allow the current user to run Docker commands.

```bash
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER
newgrp docker
```

---

# 4. Clone Repository

```bash
git clone https://github.com/KINGG777/Frappe-Helpdesk-16.git

cd Frappe-Helpdesk-16

sh storage.sh
```

---

# 5. Configure Applications

Edit the applications that will be bundled into the custom Docker image.

```bash
vi apps.json
```

Replace with:

```json
[
  {
    "url": "https://github.com/frappe/telephony",
    "branch": "develop"
  },
  {
    "url": "https://github.com/frappe/helpdesk",
    "branch": "main"
  }
]
```

---

# 6. Create Environment File

```bash
cp example.env .env
```

---

# 7. Build Custom Docker Image

```bash
docker build --no-cache \
  --build-arg CACHE_BUST=$(date +%s) \
  --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg FRAPPE_BRANCH=version-16 \
  --secret id=apps_json,src=apps.json \
  -t custom:16 \
  -f images/layered/Containerfile .
```

---

# 8. Configure Environment

Open the `.env` file.

```bash
vi .env
```

Replace:

```text
CUSTOM_IMAGE=frappe/helpdesk:latest
```

with

```text
CUSTOM_IMAGE=custom:16
```

Save the file.

---

# 9. Start Containers

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d

docker compose ps
```

---

# 10. Create Site

Replace **helpdesk.pkdevops.online** with your own domain.

```bash
docker compose exec backend \
bench new-site \
--db-root-password 123456 \
--admin-password Admin@123 \
--mariadb-user-host-login-scope="%" \
helpdesk.pkdevops.online
```

Verify:

```bash
docker compose exec backend bench list-sites
```

---

# 11. Install Helpdesk

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online install-app helpdesk
```

Verify installed applications.

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online list-apps
```

---

# 12. Run Migration (Important)

Run migration after installing Helpdesk.

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online migrate
```

This initializes Helpdesk correctly and rebuilds the Knowledge Base search index.

**This step helps resolve the following error after a fresh installation:**

```
500 Internal Server Error

/api/method/helpdesk.api.article.search
```

# Enable Server Scripts (Optional)

```bash
docker compose exec backend \
bench set-config -g server_script_enabled 1
```
# 13. Set Default Site

```bash
docker compose exec backend \
bench set-config -g default_site helpdesk.pkdevops.online
```

Restart containers.

```bash
docker compose restart
```

Verify configuration.

```bash
docker compose exec backend \
cat sites/common_site_config.json
```

Test backend.

```bash
curl -H "Host: helpdesk.pkdevops.online" http://127.0.0.1:8080
```

---

# 14. Configure Apache Reverse Proxy

Create a Virtual Host.

```bash
sudo nano /etc/apache2/sites-available/helpdesk.pkdevops.online.conf
```

Paste:

```apache
<VirtualHost *:80>

    ServerName helpdesk.pkdevops.online

    ProxyPreserveHost On

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    ErrorLog ${APACHE_LOG_DIR}/helpdesk_error.log
    CustomLog ${APACHE_LOG_DIR}/helpdesk_access.log combined

</VirtualHost>
```

Enable Apache modules.

```bash
sudo a2enmod proxy proxy_http rewrite headers

sudo a2ensite helpdesk.pkdevops.online.conf

sudo a2dissite 000-default.conf

sudo systemctl restart apache2

apache2ctl -S
```

---

# 15. Enable HTTPS

Generate a free SSL certificate.

```bash
sudo certbot --apache
```

Choose your domain and allow automatic HTTP → HTTPS redirection.

---

# Access Helpdesk

```
https://helpdesk.pkdevops.online
```

Replace the URL with your own domain.

---

# Default Login

```
Username : Administrator
Password : Admin@123
```

---

# Useful Commands

## View running containers

```bash
docker compose ps
```

## View backend logs

```bash
docker compose logs -f backend
```

## Restart containers

```bash
docker compose restart
```

## Stop containers

```bash
docker compose down
```

## Start containers

```bash
docker compose up -d
```

## List available sites

```bash
docker compose exec backend bench list-sites
```

## List installed apps

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online list-apps
```

## Run migrations

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online migrate
```

## Check backend

```bash
curl -H "Host: helpdesk.pkdevops.online" http://127.0.0.1:8080
```

---

# Included Applications

- Frappe Framework v16
- Helpdesk
- Telephony
- MariaDB
- Redis
- Traefik Proxy
- Apache Reverse Proxy
- Let's Encrypt SSL
