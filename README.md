# Frappe Helpdesk v16 on Ubuntu 24.04

Deploy **Frappe Framework v16** with **Helpdesk** and **Telephony** using Docker, Apache Reverse Proxy and Let's Encrypt SSL.

---

## Prerequisites

- Ubuntu 24.04 LTS
- 4 GB RAM (8 GB Recommended)
- Domain/Subdomain pointing to your EC2 instance
- Sudo privileges

---

# 1. Install Required Packages

Update the server, install Apache, Certbot, Git and Docker from the official Docker repository.

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

Verify installation.

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

# 2. Configure Docker

Enable Docker at boot and allow the current user to run Docker commands without sudo.

```bash
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER
newgrp docker
```

---

# 3. Clone the Repository

Clone the project and create the required Docker volumes.

```bash
git clone https://github.com/KINGG777/Frappe-Helpdesk-16.git

cd Frappe-Helpdesk-16

sh storage.sh
```

---

# 4. Configure Applications

Edit the `apps.json` file to include the Helpdesk and Telephony applications that will be bundled into the custom Docker image.

```bash
vi apps.json
```

Replace the contents with:

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

# 5. Build the Custom Image

Build a custom Frappe v16 image with the required applications.

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

# 6. Configure Environment

Open the `.env` file and replace the default image with:

```
CUSTOM_IMAGE=custom:16
```

---

# 7. Start the Containers

Launch MariaDB, Redis, Proxy and Frappe services.

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

# 8. Create a New Site

Create a Frappe site and configure the Administrator account.

```bash
docker compose exec backend \
bench new-site \
--db-root-password 123456 \
--admin-password Admin@123 \
--mariadb-user-host-login-scope="%" \
helpdesk.pkdevops.online

docker compose exec backend bench list-sites
```

---

# 9. Install Helpdesk

Install the Helpdesk application on the newly created site and verify the installed apps.

```bash
docker compose exec backend \
bench --site helpdesk.pkdevops.online install-app helpdesk

docker compose exec backend \
bench --site helpdesk.pkdevops.online list-apps
```

---

# 10. Set the Default Site

Configure the default site and restart the stack.

```bash
docker compose exec backend \
bench set-config -g default_site helpdesk.pkdevops.online

docker compose restart

docker compose exec backend \
cat sites/common_site_config.json
```

Verify the backend.

```bash
curl -H "Host: helpdesk.pkdevops.online" http://127.0.0.1:8080
```

---

# 11. Configure Apache Reverse Proxy

Create a new virtual host.

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

Enable Apache modules and the virtual host.

```bash
sudo a2enmod proxy proxy_http rewrite headers

sudo a2ensite helpdesk.pkdevops.online.conf

sudo a2dissite 000-default.conf

sudo systemctl restart apache2

apache2ctl -S
```

---

# 12. Enable HTTPS

Generate a free SSL certificate from Let's Encrypt.

```bash
sudo certbot --apache
```

Choose your domain and allow automatic HTTP to HTTPS redirection.

---

# Access Helpdesk

```
https://helpdesk.pkdevops.online
```

**Login**

```
Username : Administrator
Password : Admin@123
```

---

# Useful Commands

```bash
docker compose ps
docker compose logs -f backend
docker compose restart
docker compose down
docker compose up -d
docker compose exec backend bench list-sites
docker compose exec backend bench --site helpdesk.pkdevops.online list-apps
```
