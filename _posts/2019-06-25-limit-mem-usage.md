---
layout: post
title: "Limit process memory usage on Linux"
description: "How to use cgroups"
categories: linux
---

Control groups allow to limit the resources usage of a collection of processes.<!--more-->

## Configuration

To use control groups on Manjaro, it's necessary to install the aur package `libcgroup` with `yay -S libcgroup`

Now let's create a control groups that limits the memory usage to $$2$$ gb of physical memory and $$2$$ gb of virtual (swap) memory.

```
$ sudo cgcreate -t USERNAME:USERNAME -a USERNAME:USERNAME -g memory:/CGROUP_NAME
$ echo $((2 * 1024 * 1024 * 1024)) > /sys/fs/cgroup/memory/CGROUP_NAME/memory.limit_in_bytes
$ echo $((2 * 1024 * 1024 * 1024)) > /sys/fs/cgroup/memory/CGROUP_NAME/memory.memsw.limit_in_bytes
```

Running a process using the control groups is as easy as

```
$ cgexec -g memory:CGROUP_NAME PROCESS
```

## Example

To demonstrate the effectiveness of using `cgroups` I run the following program first with and without a control group

{% highlight cpp %}
int main() {
    int *x;
    while(true) {
        x = new int[1024 * 1024]
    }
}
{% endhighlight %}

**Without control group**

{% include figure.html path="assets/img/blog/2019-06-25/crash.svg" class="img-fluid centered" zoomable=false %}

Although here the program seems to running just fine, it consumed all the memory on my machine ($$8 GB$$) and I wasn't able to stop it with a `CTRL^C`. I had to wait for the program to crash.

**With control group**

{% include figure.html path="assets/img/blog/2019-06-25/safe.svg" class="img-fluid centered" zoomable=false %}

In this case my machine is still responsive and it's clear how the memory usage is capped. The control group seems to limiting the memory usage somewhere between 4 to 5 gb. The control groups is configured to allow 2 gb of physical memory and up to 10 gb of virtual memory. I guess this is the reason why the actual limit seems so strange.
