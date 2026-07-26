# TravianZ Docker deployment

This branch provides a working Docker proof of concept for TravianZ.

## Current status

Validated with:

- PHP 8.3 and Apache
- MariaDB 11.4
- the existing TravianZ web installer
- database and world creation
- 74 TravianZ database tables
- player registration and login
- administrator access
- persistent database and runtime data after full container recreation
- automatic blocking of `/install` after setup
- HTTPS access behind Nginx Proxy Manager

This is still a proof of concept. Docker cron automation, reverse-proxy-aware public URL handling and a web healthcheck are now integrated. SMTP configuration, image publishing and controlled updates are still planned.

## Requirements

- Docker Engine
- Docker Compose v2
- Git

## Quick start

```bash
git clone https://github.com/WikiDroneFr/TravianZ.git
cd TravianZ
git switch feature/docker-poc
cp .env.example .env
```

Edit `.env` and replace all `CHANGE_ME` values with strong unique passwords.

Start TravianZ:

```bash
docker compose up -d --build
```

Default address:

```text
http://localhost:8810
```

## Installer database settings

Use:

```text
Host: db
Port: 3306
Database: travian
User: travianz
Password: value of MARIADB_PASSWORD
Type: MYSQLi
Prefix: s1_ or the prefix required by your installation
```

The installer creates the database structure and world data. After successful installation, Apache blocks `/install`.

## Persistent data

Data is stored under `TRAVIANZ_DATA_DIR`:

```text
../data/
├── mariadb/
└── runtime/
```

Containers can be removed and recreated without deleting these files:

```bash
docker compose down
docker compose up -d
```

Do not delete the persistent directories unless a verified backup exists.

## Optional phpMyAdmin

phpMyAdmin is disabled by default:

```bash
docker compose --profile tools up -d
```

Default address:

```text
http://localhost:8811
```

Do not expose phpMyAdmin publicly without additional protection.

## Container healthcheck

The `web` service includes an HTTP healthcheck executed inside the container.

It checks that Apache accepts connections and returns an HTTP status in the 2xx or 3xx range:

```bash
docker compose ps
docker inspect --format="{{.State.Health.Status}}" travianz-docker-poc-web-1
```

The healthcheck uses PHP directly and does not require `curl` or another external HTTP client.

## Docker automation service

The Compose stack includes a dedicated `cron` service.

It runs the TravianZ automation process independently from player page requests:

```bash
docker compose ps cron
docker compose logs -f cron
```

The service:

- waits for the final `var/installed` marker before starting automation
- runs `cron.php` in CLI mode
- executes the PHP process as `www-data`
- shares the same persistent runtime directory as the web container
- relies on TravianZ internal locking to prevent overlapping executions
- updates `GameEngine/Prevention/cron_active.txt` on every tick

No host-level cron entry is required for the Docker deployment.

## Public URL configuration

Set `TRAVIANZ_PUBLIC_URL` when the application is exposed through a reverse proxy:

```env
TRAVIANZ_PUBLIC_URL=https://travianz.example.org
```

During installation, TravianZ uses this value to prefill the Server, Domain and Homepage fields.

If the variable is empty, the installer falls back to:

1. `X-Forwarded-Proto` and `X-Forwarded-Host`
2. the current HTTPS state and `HTTP_HOST`
3. `http://localhost/`

The generated URLs are restricted to valid HTTP or HTTPS URLs and are normalized with a trailing slash.

## Reverse proxy

TravianZ has been tested behind Nginx Proxy Manager.

Example upstream:

```text
Scheme: http
Host: Docker host address
Port: 8810
```

Forward at least:

```text
Host
X-Forwarded-For
X-Forwarded-Proto
X-Real-IP
```

A future version should support:

```env
TRAVIANZ_PUBLIC_URL=https://travianz.example.org
```

This value should define `DOMAIN`, `HOMEPAGE` and `SERVER` so public links never expose an internal address or port.

## Security

The image:

- excludes `.git` and `.env`
- blocks Docker-related files
- disables directory listing
- blocks `/install` after setup
- uses dedicated writable runtime paths

Never use `chmod -R 777`. Real secrets must never be committed.

## Backup

A complete backup includes:

- `TRAVIANZ_DATA_DIR/runtime`
- an SQL dump of the database
- `.env`, stored securely

Database backup:

```bash
docker compose exec -T db mariadb-dump \
  -u root -p \
  --single-transaction --routines --triggers \
  travian > travianz-backup.sql
```

Runtime backup:

```bash
tar -czf travianz-runtime-backup.tar.gz -C ../data runtime
```

## Updating

Current manual source update:

```bash
git pull
docker compose build web
docker compose up -d
```

Unattended updates should not be enabled by default. A safe automated workflow should back up data, pull the new image, recreate containers, run health checks and roll back on failure.

## Migrating an existing installation

Always test the migration on a copy first.

### 1. Freeze and back up the old installation

Stop writes to the old instance, archive its files and export the database:

```bash
mysqldump \
  --single-transaction \
  --routines \
  --triggers \
  --default-character-set=utf8mb4 \
  -u CURRENT_USER -p CURRENT_DATABASE \
  > travianz-database.sql
```

Record the existing table prefix, URLs, timezone, server settings, cron configuration and mail configuration.

### 2. Start the Docker services

```bash
cp .env.example .env
docker compose up -d db web
docker compose ps
```

Do not create a new world when importing an existing database.

### 3. Import the SQL dump

```bash
docker compose exec -T db mariadb \
  -u travianz -p travian \
  < travianz-database.sql
```

Verify the tables:

```bash
docker compose exec -T db mariadb \
  -u travianz -p -D travian \
  -e "SHOW TABLES;"
```

### 4. Copy only generated runtime files

Do not overwrite the Docker image with the complete old application tree.

Review and migrate only required mutable files, including:

```text
GameEngine/config.php
GameEngine/Admin/Mods/constant_format.tpl
GameEngine/Prevention/
GameEngine/Notes/
Templates/text.tpl
var/
automation.lck
```

Copy them into `TRAVIANZ_DATA_DIR/runtime` while preserving the table prefix.

Update the database host to `db`, port to `3306`, and credentials to the values from `.env`.

When using a reverse proxy, update `DOMAIN`, `HOMEPAGE` and `SERVER` to the public HTTPS URL.

### 5. Mark the installation complete and apply permissions

```bash
sudo mkdir -p ../data/runtime/var
sudo touch ../data/runtime/var/installed
sudo chown -R www-data:www-data ../data/runtime
sudo find ../data/runtime -type d -exec chmod 750 {} \;
sudo find ../data/runtime -type f -exec chmod 640 {} \;
docker compose restart web
```

### 6. Validate before cutover

Check:

- homepage, registration and login
- administrator access
- users, villages and resources
- building queues and troop movements
- reports, messages and alliances
- automation and scheduled tasks
- mail delivery
- reverse-proxy HTTPS links

Keep the old instance and backups until validation is complete.

## Planned improvements

- optional SMTP environment variables
- GitHub Actions image builds
- GHCR image publication
- controlled update automation with backup and rollback
- installer database fields prefilled from Docker variables
- progress indicators during database and world creation
- removal of obsolete `chmod 777` instructions
- `Europe/Paris` and improved timezone selection
- player language selection during registration
- fixes for long administration menu entries

## Demonstration

A temporary public test instance may be provided to maintainers. Test credentials must be shared privately and never committed or posted in a public issue.
