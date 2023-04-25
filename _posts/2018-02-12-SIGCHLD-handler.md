---
layout: post
title:  "SIGCHLD Handler"
description: "Intercept SIGCHLD without polling or blocking"
categories: unix
tags:
    - processes
    - c
---

To prevent the accumulation of zombie children, a parent should `wait` to free their resources<!--more-->, it can do it in two ways

* Using `wait()` or `waitpid()` without the `WNOHANG`, to block until a child terminates
* Periodically perform a non blocking check (polling) using `waitpid()` specifing the `WNOHANG` flag.

It's possible to launch a handler whenever a child terminates (without wasting resources on blocking or polling). However it's possible that if `SIGCHLD` are generated in quick succession some of them get lost, since they are not queue anywhere and the handler might be still executing for an already terminated child. A single wait inside the signal handler would not work. There is a smart solution:

{% highlight c %}
while(waitpid(-1, NULL, WNOHANG) > 0) continue;
{% endhighlight %}
In this way the parent wait for any child processes (pid = -1) and while there are zombie process (`waitpid()` return value is `>0`) it keep looping on calling wait.

Example with `SIGCHLD` handler
{% highlight c %}
#include <sys/wait.h>

void sigchldHandler(int sig){
    int status, savedErrno;
    pid_t childPid;

    savedErrno = errno;
    while((childPid = waitpid(-1, &status, WNOHANG)) > 0){
        printf("child %ld terminates\n", childPid);
    }
    errno = savedErrno;
}

int main(int argc, char *argv[]){
    struct sigaction sa;
    int i, childNum = 5;

    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sa.sa_handler = sigchlHandler;		// address of handler function

    if(sigaction(SIGCHLD, &sa, NULL) == -1)
        errExit("sigaction");

    for(i=0; i<childNum; ++i){
        switch(fork()){
            // ...
        }
    }
}
{% endhighlight %}

Usually a `SIGCHLD` is delivered to the parent even when one of its children stops. To prevent that the flag `SA_NOCLDSTOP` must be used in the signal handler flags (`sa.sa_flags = SA_NOCLDSTOP`).

