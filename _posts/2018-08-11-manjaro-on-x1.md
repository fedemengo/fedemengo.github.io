---
layout: post
title:  "Manjaro-i3 on x1 Carbon"
description: "Step-by-step guide to get started"
categories: linux
---

Below the configuration of Manjaro-i3 that I use on my Lenovo x1 Carbon. Shell configuration and other info at [manjaro-dotfiles](https://github.com/fedemengo/manjaro-dotfiles).<!--more-->

### Grub

Edit the following line to automatically boot Manjaro without timeout

```
GRUB_DEFAULT=0          // set OS number 1 as the default
GRUB_TIMEOUT=0          // no timeout
```
{: title="/etc/default/grub"}

Finally run `sudo update-grub`

### Touchpad

Configure the driver for the touchpad in the following files. Install **libinput** (xf86-input-libinput) and edit its configuration file.
```
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "NaturalScrolling" "true"
        Option "AccelSpeed" "0.7"
        Option "AccelProfile" "adaptive"
        Option "Tapping" "true"
        Option "TappingButtonMap" "lrm"
EndSection
```
{: title="/usr/share/X11/xorg.conf.d/40-libinput.conf"}

**libinput** should be preferred over **synaptics** (xf86-input-synaptics). If the configuration files `/usr/share/X11/xorg.conf.d/` are being used, the directory `/etc/X11/xorg.conf.d/` should not contains either libinput or synaptics (because they override the files in `/usr/share/...`). In addition, the file with the higher number has higher precedence over the others.

See `man 5 xorg.conf`

### Touchscreen

Install **touchegg** and its dependency or just use an AUR packages manager. I personally use [yay](https://github.com/Jguer/yay)

- `git clone https://aur.archlinux.org/touchegg.git` (requires `geis`)
- `git clone https://aur.archlinux.org/geis.git` (requires `grail`)
- `git clone https://aur.archlinux.org/grail.git` (requires `frame`)
- `git clone https://aur.archlinux.org/frame.git`

Create the touchegg configuration file

```
<touchégg>
  <settings>
    <property name="composed_gestures_time">111</property>
  </settings>
  <application name="All">
    <gesture type="DRAG" fingers="1" direction="ALL">
      <action type="DRAG_AND_DROP">BUTTON=1</action>
    </gesture>
    <gesture type="DRAG" fingers="3" direction="UP">
      <action type="MAXIMIZE_RESTORE_WINDOW"></action>
    </gesture>
    <gesture type="DRAG" fingers="3" direction="DOWN">
      <action type="MINIMIZE_WINDOW"></action>
    </gesture>
    <gesture type="DRAG" fingers="2" direction="ALL">
      <action type="SCROLL">SPEED=7:INVERTED=true</action>
    </gesture>
    <gesture type="PINCH" fingers="2" direction="IN">
      <action type="SEND_KEYS">Control+minus</action>
    </gesture>
    <gesture type="PINCH" fingers="2" direction="OUT">
      <action type="SEND_KEYS">Control+plus</action>
    </gesture>
    <gesture type="TAP" fingers="3" direction="">
      <action type="MOUSE_CLICK">BUTTON=2</action>
    </gesture>
    <gesture type="TAP" fingers="2" direction="">
      <action type="MOUSE_CLICK">BUTTON=3</action>
    </gesture>
    <gesture type="TAP" fingers="1" direction="">
      <action type="MOUSE_CLICK">BUTTON=1</action>
    </gesture>
  </application>
</touchégg>
```
{: title="~/.config/touchegg/touchegg.conf"}

Load touchegg with

```
touchegg &
```
{: title="~/.xprofile"}

```
[ -f ~/.xprofile ] && . ~/.xprofile
```
{: title="~/.xinitrc"}

### Audio

Here is the list of steps I came up with for making the audio works

- `sudo usermod -aG audio $(whoami)`
- `sudo install_pulse` just an alias for `sudo pacman -Sy manjaro-pulse pa-applet pavucontrol`
- `sudo pacman -S pavucontrol`
- `sudo echo "options snd_hda_intel index=1" >> /etc/modprobe.d/alsa-base.conf`

Other information or tips for trouble shooting can be found on my [repo]((https://github.com/fedemengo/manjaro-dotfiles))
