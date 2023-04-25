---
layout: post
title:  "Linux Commands"
description:   "systemd, at, cron"
categories: linux
---

The following content was create on Manjaro Linux

### systemd

<!--more-->

- List all service unit files on the systems with `systemctl list-unit-files -at service`
- List all running services with `systemctl list-units -t service --state running`
- `systemctl cat SERVICE_NAME` will cat the service file and give insight on the file structure (dependencies, what happens if service fails)
- To check whether a service is active just use `systemctl is-active SERVICE_NAME`
- It's also possible to prevent services from running by masking them with `sudo systemctl mask SERVICE_NAME` (unmasking is done in the same way)

### at

Install at with `pacman -S at` and enable the daemon with `sudo systemclt start atd` and `sudo systemclt enable atd`

Create the first job by specifying the time when the job should execute and then typing the actual commands
```
$ at now +1min
at> mkdir /home/backup
at> cp -r ~/ /home/backup/
```
Finally type CTRL + D to save

From the `man` page, **at** usage is very simple
- You can inspect at's queue with `atq`
- With `at -c JOB_NUMBER` you can inspect the command environment and other useful information
- To remove a job just use `atrm JOB_NUMBER`
- To job can be create from a file with `at -f FILE_NAME`

It's also possible to create `batch` that are multiple jobs executed the system average drop is below $$0.8$$

### cron

User cron jobs are specific to and can be managed by a user, are stored in `/var/spool/cron/USER/`. While system cron job are sore in `/etc/cron.d`

The form of the file is the same `MINUTE HOUR DAY MONTH DAY_OF_WEEK command_to_run`
The value can be listed `V1,V2,V3`, ranges can be used `V1-V5`, step value are valid `*/10` (ranges and step value can be combine `1-9/2`). Minutes are in the range $$1-59$$, hours in $$0-23$$, days in $$1-31$$, month $$1-12$$ and day of the week in the range $$0-6$$ with $$0$$ being sunday.

The command to manage cron jobs is `crontab`

To create a cronjob that has to be run by root just use `sudo crontab -e` to add a new entry, and before specifying the command, indicate the user that should run it `M H D MONTH DW USER command`.

To run a command on a hourly/daily/weekly/monthly basis it's sufficient to place the command in `etc/cron.FREQUENCE/`

As user administrator it's possible to specifically allow/deny a user to create `cron` and `at` jobs by adding the desired username to `etc/cron.deny` or `atc/cron.allow` (same format for `at`)
