# Script to Automatically Cleanup Leftovers from GitLab Runners Using Docker

This script safely removes unused Docker containers, images, volumes, networks, and build cache left behind by GitLab Runners. It only affects unused resources, so it won't interfere with running jobs.

---

#### Create the cleanup script at `/usr/local/bin/gitlab-runner-cleanup`:

```bash
#!/bin/bash

# Clean up unused containers, images, networks, volumes
docker system prune -af --volumes
echo "Pruned System"

# Remove unused containers directly
docker container prune -f
echo "Pruned Networks"

# Remove unused images directly
docker image prune -af
echo "Pruned Networks"

# Remove dangling volumes directly
docker volume prune -af
echo "Pruned Volumes"

# Remove all unused build cache directly
docker builder prune -af
echo "Pruned Build Cache"

# Remove unused networks directly
docker network prune -f
echo "Pruned Networks"

exit 0
```

#### Then make it executable:
```bash
sudo chmod +x /usr/local/bin/gitlab-runner-cleanup
```

#### Add a cron job

Edit root’s crontab with:
```bash
sudo crontab -e
```

Run cleanup daily at 3:00:
```bash
0 3 * * * /usr/local/bin/gitlab-runner-cleanup > /var/log/gitlab-runner-cleanup.log 2>&1
```
Without logging:
```bash
0 3 * * * /usr/local/bin/gitlab-runner-cleanup >/dev/null 2>&1
```
