#!/bin/bash

set -e

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker service is not running."
    exit 1
fi

echo "Creating persistent directories..."

sudo mkdir -p /opt/frappe/mariadb
sudo mkdir -p /opt/frappe/sites

MARIADB_IMAGE=${MARIADB_IMAGE:-mariadb:11.8}

MYSQL_UID=$(docker run --rm ${MARIADB_IMAGE} id -u mysql)
MYSQL_GID=$(docker run --rm ${MARIADB_IMAGE} id -g mysql)

sudo chown -R ${MYSQL_UID}:${MYSQL_GID} /opt/frappe/mariadb
sudo chown -R 1000:1000 /opt/frappe/sites

echo "Storage directories created successfully."