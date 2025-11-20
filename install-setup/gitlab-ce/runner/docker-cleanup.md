# Script to Automatically Cleanup Leftovers from GitLab Runners Using Docker

This script safely removes unused Docker containers, images, volumes, networks, and build cache left behind by GitLab Runners. It only affects resources older than 24 hours, so it won't interfere with running jobs.

---

#### Create the cleanup script at `/usr/local/bin/gitlab-runner-cleanup.sh`:

```bash
#!/bin/bash

# Clean up unused containers, images, networks, volumes older than 24h
docker system prune -af --volumes --filter "until=24h"

# Remove dangling volumes directly (safety)
docker volume prune -f --filter "until=24h"

# Remove all unused build cache older than 24h
docker builder prune -af --filter "until=24h"

# Remove unused networks older than 24h
docker network prune -f --filter "until=24h"

exit 0
```

#### Then make it executable:
```bash
sudo chmod +x /usr/local/bin/gitlab-runner-cleanup.sh
```

#### Add a cron job

Edit root’s crontab with:
```bash
sudo crontab -e
```

Run cleanup every hour:
```bash
0 * * * * /usr/local/bin/gitlab-runner-cleanup.sh > /var/log/gitlab-runner-cleanup.log 2>&1
```
Without logging:
```bash
0 * * * * /usr/local/bin/gitlab-runner-cleanup.sh >/dev/null 2>&1
```
