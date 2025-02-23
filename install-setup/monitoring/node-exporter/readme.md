
Install:
```bash
bash <(curl -s https://host.leicraftmc.de/assets/node-exporter-scripts/install-ne.sh)
```

Setup:

with `apache2-utils` pre-installed
```bash
bash <(curl -s https://host.leicraftmc.de/assets/node-exporter-scripts/setpw-ne.sh)
```

without `apache2-utils` pre-installed
```bash
apt install apache2-utils && bash <(curl -s https://host.leicraftmc.de/assets/node-exporter-scripts/setpw-ne.sh) && apt remove --purge apache2-utils
```
