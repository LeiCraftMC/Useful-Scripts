# Best Practises for Configuring Mail-SPAM Filters with Virtualmin Setup

## Postfix Configuration
In the file `/etc/postfix/main.cf` replace:
```
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination
```
With:
```
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_rbl_client zen.spamhaus.org,
    reject_rbl_client bl.spamcop.net,
    reject_rbl_client b.barracudacentral.org
```
Reload Postfix:
```bash
sudo systemctl reload postfix
```

## SpamAssassin Configuration
Add this to `/etc/spamassassin/local.cf`
```
required_score 4.0
use_bayes 1
use_bayes_rules 1
use_auto_whitelist 1
bayes_auto_learn 1
# ensures RBL checks are not skipped
skip_rbl_checks 0
```
Reload Postfix:
```bash
sudo systemctl reload spamassassin
# depending on your system the service could live under spamd
sudo systemctl restart spamd
```

### Data Training:
Move Emails Manually to your SPAM folder in your E-MAIL Client and then run
```bash
# chnage the command below depending on where your spam folder is
sudo sa-learn --spam /home/*/Maildir/.spam/{cur,new}
```

## ClamAV Configuration

Backup your existing ClamAV DB under `/var/lib/clamav`:
```bash
tar -czpf "/root/clamav-db-backup-$(date +%Y%m%d_%H%M%S).tar.gz" -C /var/lib clamav
```

Run the command below regually to get the newest Sanesecurity DB
```bash
sudo rsync -av --delete rsync://rsync.sanesecurity.net/sanesecurity /var/lib/clamav
sudo chown -R clamav:clamav /var/lib/clamav/
```
or add it to cron:
```
0 */6 * * * root rsync -av --delete rsync://rsync.sanesecurity.net/sanesecurity /var/lib/clamav && && chown -R clamav:clamav /var/lib/clamav/ && systemctl restart clamav-daemon
```

Reload ClamAV:
```bash
sudo systemctl restart clamav-daemon
```
