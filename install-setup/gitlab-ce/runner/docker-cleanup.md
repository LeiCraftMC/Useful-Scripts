# Script to automaticly Cleanup all leftovers from GitLab Runners using Docker

#### Create a cleanup script at `/usr/local/bin/gitlab-runner-cleanup.sh`:
```bash
#!/bin/bash

# Clean up unused containers, images, networks, volumes
docker system prune -af --volumes --filter "until=24h"

# In case something survived: remove dangling volumes directly
docker volume prune -f --filter "until=24h"

# Optional: remove all unused build cache
docker builder prune -af --filter "until=24h"

# Optional: just in case older networks linger
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
0 * * * * /usr/local/bin/gitlab-runner-cleanup.sh > /var/log/gitlab-runner-cleanup.log
```
Without logging:
```bash
0 * * * * /usr/local/bin/gitlab-runner-cleanup.sh >/dev/null 2>&1
```
