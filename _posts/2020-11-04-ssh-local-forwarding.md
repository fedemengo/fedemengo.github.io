---
layout: post
title:  "SSH Local Forwarding"
description: "Tunneling through SSH"
categories: networking
tag:
  - unix
---

Earlier todays I was configuring [rclone](https://rclone.org/) on my raspberry to backup my document on Google Drive. As I was giving permission to rclone to access Drive apis I was asked this

{% include figure.html path="assets/img/blog/2020-11-04/prompt.png" class="img-fluid centered" zoomable=false %}

I'm ssh-ed in the raspberry, which is running a very light distribution of raspbian without a X11 server, so it doesn't have a GUI. But I needed to access the url in order to login to my google account and allow the app access to my account.

I tried connecting on my laptop to `http://raspberry-address:53682/auth?state=2EL7gU5-kcVEAMC2w6QHPg` but of course it wasn't working, I tried to **curl** and **wget** `http://127.0.0.1:53682/auth?state=2EL7gU5-kcVEAMC2w6QHPg`, a step in the right direction but not quite (I used this to authenticate other app that just required me to access the url).

Then I tried a ssh trick that I used in other occasion `ssh -X blahblah` but of course there was no X11 server to forward. That's when I remembered reading about **ssh forwarding**. I never thought I would use it in the future but here I was.

#### SSH Local Forwarding

The idea is straightforward, you can forward all your local request on a specific port to another port on your remote machine.
For example if I were to `ssh -L 12345:127.0.0.1:54321 user@remote-address` I could make request on my local machine (using browser or cli) to `localhost:12345` and ssh would forward those request to `127.0.0.1:54321` on the remote machine and forward the response back to my machine.

In my case I was able to authenticate my app by using `ssh -L 12345:127.0.0.1:53682 user@raspberry-address` and the accessing `http://127.0.0.1:12345/auth?state=2EL7gU5-kcVEAMC2w6QHPg` with my browser.


Another useful feature that ssh provides on top of the most famous `sftp` and `scp`
