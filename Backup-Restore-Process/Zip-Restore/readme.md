# Backup and Restore

This section explains how to back up the `/opt/frappe` directory, download it to your local Windows machine, and restore it on a new server.

---

# Create Backup

Create a compressed archive of the complete Frappe data.

```bash
cd /

sudo tar --numeric-owner -czpf /home/ubuntu/frappe-backup.tar.gz opt/frappe
```

Verify:

```bash
ls -lh /home/ubuntu/frappe-backup.tar.gz
```

Example:

```text
-rw-r--r-- 1 root root 1.2G Jul 27 10:30 /home/ubuntu/frappe-backup.tar.gz
```

---

# Download Backup to Windows

Open **PowerShell** on your Windows PC.

Run:

```powershell
scp -i "C:\Users\YOUR_USERNAME\.ssh\YOUR_KEY.pem" ubuntu@YOUR_SERVER_IP:/home/ubuntu/frappe-backup.tar.gz "C:\Users\YOUR_USERNAME\Downloads\"
```

Example:

```powershell
scp -i "C:\Users\Kingg\.ssh\aws.pem" ubuntu@15.206.xxx.xxx:/home/ubuntu/frappe-backup.tar.gz "C:\Users\Kingg\Downloads\"
```

The backup will be saved to:

```text
C:\Users\YOUR_USERNAME\Downloads\frappe-backup.tar.gz
```

---

# Upload Backup to a New Server

From your Windows PC, upload the backup:

```powershell
scp -i "C:\Users\YOUR_USERNAME\.ssh\YOUR_KEY.pem" "C:\Users\YOUR_USERNAME\Downloads\frappe-backup.tar.gz" ubuntu@NEW_SERVER_IP:/home/ubuntu/
```

Example:

```powershell
scp -i "C:\Users\Kingg\.ssh\aws.pem" "C:\Users\Kingg\Downloads\frappe-backup.tar.gz" ubuntu@13.233.xxx.xxx:/home/ubuntu/
```

---

# Restore Backup

Extract the backup:

```bash
sudo tar -xzpf /home/ubuntu/frappe-backup.tar.gz -C /
```

Verify:

```bash
ls -l /opt/frappe
```

Expected:

```text
mariadb/
sites/
```

---

# Set Permissions

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

# Start Containers

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
pull

docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
up -d
```

---

# Verify Existing Site

Do **NOT** run `bench new-site`.

Verify the existing site:

```bash
docker compose exec backend bench list-sites
```

Example:

```text
Available sites:
* tic.pkdevops.online
```

Your existing database, users, tickets, attachments, and configuration have now been restored successfully.
