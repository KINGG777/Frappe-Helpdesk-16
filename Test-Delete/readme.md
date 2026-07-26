# Frappe Helpdesk v16 - Production Deployment

This repository contains the Docker Compose configuration for deploying **Frappe Helpdesk v16**.

The application code is stored in Docker images, while all persistent data is stored on the server.

---

# Production Architecture

```
GitHub Repository
│
├── compose.yaml
├── .env.example
├── overrides/
│   ├── compose.local-storage.yaml
│   ├── compose.sites-storage.yaml
│   ├── compose.proxy.yaml
│   ├── compose.redis.yaml
│   └── compose.mariadb.yaml
│
└── README.md

---------------------------------------------------

Server

/opt/frappe
├── mariadb
└── sites

---------------------------------------------------

Docker

Backend
Frontend
Scheduler
Queue
Websocket
MariaDB
Redis
```

---

# Persistent Data

Only two directories contain application data.

```
/opt/frappe/mariadb
```

Contains:

- Database
- Users
- Passwords
- Tickets
- Roles
- Settings
- Workflows
- Custom Fields

---

```
/opt/frappe/sites
```

Contains:

- site_config.json
- common_site_config.json
- Uploaded Files
- Images
- Attachments
- Public Files
- Private Files
- Assets

---

# Why Store Data Outside Docker?

Docker containers are disposable.

If a container is deleted, recreated or updated, everything inside the container filesystem is lost.

Using bind mounts keeps all business data on the server.

Example:

```
Server

/opt/frappe/mariadb
        │
        ▼
Docker
/var/lib/mysql
```

```
Server

/opt/frappe/sites
        │
        ▼
Docker
/home/frappe/frappe-bench/sites
```

---

# MariaDB Migration

## Stop Containers

```bash
docker compose down
```

---

## Create Directory

```bash
sudo mkdir -p /opt/frappe/mariadb
```

---

## Copy Existing Data

```bash
sudo cp -a /var/lib/docker/volumes/frappe_docker_db-data/_data/. /opt/frappe/mariadb/
```

---

## Set Ownership

Find MariaDB UID

```bash
docker run --rm mariadb:10.11 id mysql
```

Example

```
uid=999(mysql)
gid=999(mysql)
```

Apply ownership

```bash
sudo chown -R 999:999 /opt/frappe/mariadb
```

---

## Create Override

Create

```
overrides/compose.local-storage.yaml
```

```yaml
services:
  db:
    volumes:
      - /opt/frappe/mariadb:/var/lib/mysql
```

---

## Start

```bash
docker compose up -d
```

---

# Sites Migration

## Stop Containers

```bash
docker compose down
```

---

## Create Directory

```bash
sudo mkdir -p /opt/frappe/sites
```

---

## Copy Existing Data

```bash
sudo cp -a /var/lib/docker/volumes/frappe_docker_sites/_data/. /opt/frappe/sites/
```

---

## Find Frappe User

```bash
docker exec -it frappe_docker-backend-1 id
```

Example

```
uid=1000(frappe)
gid=1000(frappe)
```

---

## Set Ownership

```bash
sudo chown -R 1000:1000 /opt/frappe/sites
```

---

## Create Override

Create

```
overrides/compose.sites-storage.yaml
```

```yaml
services:
  backend:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites

  frontend:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites

  scheduler:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites

  websocket:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites

  queue-short:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites

  queue-long:
    volumes:
      - /opt/frappe/sites:/home/frappe/frappe-bench/sites
```

---

## Start Containers

```bash
docker compose up -d
```

---

# Verify

Verify MariaDB

```bash
docker inspect frappe_docker-db-1
```

Expected

```
Source:
/opt/frappe/mariadb

Destination:
/var/lib/mysql
```

---

Verify Sites

```bash
docker inspect frappe_docker-backend-1
```

Expected

```
Source:
/opt/frappe/sites

Destination:
/home/frappe/frappe-bench/sites
```

---

# Production Backup

Back up these directories regularly.

```
/opt/frappe/mariadb
```

```
/opt/frappe/sites
```

Also back up:

```
.env
```

Apache configuration

```
/etc/apache2/sites-available/
```

SSL Certificates

```
/etc/letsencrypt/
```

---

# Disaster Recovery

Suppose:

- EC2 instance crashes
- Docker containers are deleted
- Docker image is removed
- Ubuntu is reinstalled

Recovery process:

---

## Step 1

Create a new Ubuntu server.

---

## Step 2

Install

- Docker
- Docker Compose
- Apache

---

## Step 3

Clone repository

```bash
git clone https://github.com/KINGG777/Frappe-Helpdesk-16.git

cd Frappe-Helpdesk-16
```

---

## Step 4

Copy your production `.env` file into the project.

> **Note:** Store only `.env.example` in GitHub. Keep the real `.env` secure and restore it separately.

---

## Step 5

Restore server data

```
/opt/frappe/mariadb
```

```
/opt/frappe/sites
```

These directories should contain the backed-up data from the previous server.

---

## Step 6

Pull the latest Docker image (optional if not already present)

```bash
docker pull kingg777/frappe-helpdesk:16
```

---

## Step 7

Start the application

```bash
docker compose \
-f compose.yaml \
-f overrides/compose.mariadb.yaml \
-f overrides/compose.redis.yaml \
-f overrides/compose.proxy.yaml \
-f overrides/compose.local-storage.yaml \
-f overrides/compose.sites-storage.yaml \
up -d
```

Because the override files use bind mounts, Docker automatically mounts:

```
/opt/frappe/mariadb
```

to

```
/var/lib/mysql
```

and

```
/opt/frappe/sites
```

to

```
/home/frappe/frappe-bench/sites
```

No manual database import or file copy into the containers is required.

---

# Result

After startup, the application automatically restores:

- Users
- Passwords
- Tickets
- Attachments
- Uploaded Files
- Images
- Roles
- Permissions
- Settings
- Workflows
- Custom Fields
- Site Configuration

because all persistent data is read directly from the server directories under `/opt/frappe`.

---

# Notes

- Never run `docker compose down -v` in production unless you intentionally want to remove Docker-managed volumes.
- Keep `/opt/frappe` outside your Git repository.
- Commit only configuration files to GitHub.
- Use regular backups for `/opt/frappe`, `.env`, Apache configuration, and SSL certificates.
