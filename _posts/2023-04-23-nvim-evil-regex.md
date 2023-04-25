---
layout: post
title:  How I made nvim 300x faster
description: Tracking down an evil regex in vim and neovim
tags: vim nvim regex
categories: debugging
---

## Intro

For a while, I've been working on a side [project](https://github.com/fedemengo/d2bist) that generates files with many 0s and 1s. As nvim is my primary editor, I frequently need to check or modify the contents of these files. However, to my great annoyance, whenever the files contained more than, let's say, tens of thousands of bit characters, nvim would hang for several seconds, minutes, or until I would SIGKILL it.

This kept happening, so I tried opening the same file with plain vim and to my surprise, the file would open up instantly. There had to be something wrong with my config, I thought. After all, adding more and more plugins to nvim undoubtedly makes the editor heavier and slower. It was time to find out where the problem was.

## How

I never had to debug performance issues in nvim before, so I didn't really have much to start with. My first suspicion was that the slow down was cause by some plugins. I tried to binary-search the plugin causing problems but even without plugins opening up that file was still slow.

I didn't havy many other ideas, looking at the helper I discovered the `--startuptime` flag. Since I didn't want to mess up my configuration I launched a docker container, clone and compile nvim. I made sure the problem was still present in the version from master and created an empty `init.lua`.

Finally I launched

```sh
root@ff1d74dcbc84:~# time nvim /test/data/data/pi_30_000 --startuptime vim-startup.log +qall

real    0m6.142s
user    0m6.123s
sys     0m0.010s
```

which generated

```
times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.013  000.013: --- NVIM STARTING ---
001.096  001.084: event init
001.994  000.897: early init
002.122  000.129: locale set
002.560  000.438: init first window
003.937  001.377: inits 1
003.996  000.058: window checked
....
018.257  000.129  000.129: sourcing /usr/share/nvim/runtime/plugin/man.lua
018.271  002.238: loading rtp plugins
018.389  000.118: loading packages
018.676  000.287: loading after plugins
018.687  000.011: inits 3
019.861  001.174: reading ShaDa
027.129  001.244  001.244: require('vim.filetype')
029.058  001.187  001.187: require('vim.filetype.detect')
6048.212  000.048  000.048: sourcing /usr/share/nvim/runtime/scripts.vim
6048.316  6025.976: opening buffers
6048.352  000.036: BufEnter autocommands
6048.355  000.003: editing files in windows
```

Looking at the logs, it's clear that something bad happened between `029.058` and `6048.212`. In particular, `require('vim.filetype.detect')` took $$\approx 6$$ seconds.

Armed with `rg` and `fd`, after some code diving, I understood what that line did. As the name suggests, it's used to infer the file type. There are a couple of ways nvim infers the file type. In case it's not obvious from the extension, it first checks for [shebangs](https://en.wikipedia.org/wiki/Shebang_(Unix)) and, if necessary, it attempts to guess the filetype from the file content.

And that's where my problem was. The file contents are fed to a set of regex that, in case of a successful match, assigns a known filetype. For most of the regex, it's enough to test the first few lines of the file content. In my case, the file was a single long line of characters (30k to be exact). So my first idea was to limit the line each regex has to test to some "reasonable" upper bound, I think I set 1000.

So I changed that, recompiled nvim, and opened up the file again.

Yep, the fix worked!

I pushed the fix and opened a PR. After some time, a nvim core maintainer had a chance to look at the fix and mentioned that nvim logic matches vim's one. So to prevent any major divergence between the two, they suggested I push the fix to vim first, and in case it was accepted, they would port it to nvim. I think that's only fair.

But could I really push that fix to vim? After all, vim didn't suffer from this, so it seemed unreasonable to cap the file content to solve performance problems that were not there. I wanted to fix the issue where it made more sense.

After some rubber ducking with ChatGPT and some looking around the internet, I read that vim regex engine is particularly efficient. Nvim, on the other hand, uses Lua's builtin regex. Could it be that the two had this magnitude of performance difference? Only one way to find out. Let's write some code to test it.

So I basically rewrote [this](https://github.com/neovim/neovim/blob/53f36806f1b5107c0570ffbf57180a8e08f45b2e/runtime/lua/vim/filetype/detect.lua#L1660) into a script
```lua
local patterns_text = {
    "^#compdef\\>",
    "^#autoload\\>",
    "^From [a-zA-Z][a-zA-Z_0-9%.=%-]*(@[^ ]*)? .* 19%d%d$",
    "^From [a-zA-Z][a-zA-Z_0-9%.=%-]*(@[^ ]*)? .* 20%d%d$",
    "^From %- .* 19%d%d$",
    "^From %- .* 20%d%d$",
    "^<[%%&].*>",
    '^" *[vV]im$[',
    "%-%*%-.*[cC]%+%+.*%-%*%-",
    "^\\*\\* LambdaMOO Database, Format Version \\%([1-3]\\>\\)\\@!\\d\\+ \\*\\*$",
    "^\\(diff\\>\\|Only in \\|\\d\\+\\(,\\d\\+\\)\\=[cda]\\d\\+\\>\\|# It was generated by makepatch \\|Index:\\s\\+\\f\\+\\r\\=$\\|===== \\f\\+ \\d\\+\\.\\d\\+ vs edited\\|==== //\\f\\+#\\d\\+\\|# HG changeset patch\\)",
    "^%%![ \t]*PS",
    "^ *proc[nd] *$",
    "^%*%*%*%*  Purify",
    "<%?%s*xml.*%?>",
    "\\<DTD\\s\\+XHTML\\s",
    "\\c<!DOCTYPE\\s\\+html\\>",
    "^%%PDF%-",
    "^%x%x%x%x%x%x%x: %x%x ?%x%x ?%x%x ?%x%x ",
    "^RCS file:",
    "^CVS:",
    "^CVS: ",
    "^!R!",
    "^SEND%-PR:",
    "^SNNS network definition file",
    "^SNNS pattern definition file",
    "^SNNS result file",
    "^%%.-[Vv]irata",
    "[0-9:%.]* *execve%(",
    "^__libc_start_main",
    "^\\* $$ JOB\\>",
    "^// *JOB\\>",
    "K & K  Associates",
    "TAK 2000",
    "S Y S T E M S   I M P R O V E D ",
    "Run Date: ",
    "Node    File  1",
    "^==%d+== valgrind",
    "^==%d+== Using valgrind",
    "PACKAGE DOCUMENTATION$",
    "^##RenderMan",
    "exec%s%+%S*scheme",
    "^\\(commit\\|tree\\|object\\) \\x\\{40,\\}\\>\\|^tag \\S\\+$",
    "%-%*%-.*erlang.*%-%*%-",
    "^%%YAML",
    "^#.*by RouterOS",
    "^#n%s",
    "^#n$",
}

local function match_from_text(contents)
    for i = 1, #patterns_text do
        curr = patterns_text[i]
        next = ""
        if i < #patterns_text then
            next = patterns_text[i+1]
        end
        local start_time = os.clock()
        contents[1]:find(curr)
    local elapsed_time = (os.clock() - start_time)
        print(string.format("curr: '%s', Time: %.3fs. next: '%s'", curr, elapsed_time, next))
	end
end

local file = io.open(arg[1], "r")
if file == nil then
    print("file not found")
else
    local content = file:read("*all")
    file:close()
    match_from_text({content})
end
```

and run it against the file that was causing me problems `lua test.lua pi_30_000`

Soon enough I had found the problematic regex

```
curr: '^RCS file:', Time: 0.000s. next: '^CVS:'
curr: '^CVS:', Time: 0.000s. next: '^CVS: '
curr: '^CVS: ', Time: 0.000s. next: '^!R!'
curr: '^!R!', Time: 0.000s. next: '^SEND%-PR:'
curr: '^SEND%-PR:', Time: 0.000s. next: '^SNNS network definition file'
curr: '^SNNS network definition file', Time: 0.000s. next: '^SNNS pattern definition file'
curr: '^SNNS pattern definition file', Time: 0.000s. next: '^SNNS result file'
curr: '^SNNS result file', Time: 0.000s. next: '^%%.-[Vv]irata'
curr: '^%%.-[Vv]irata', Time: 0.000s. next: '[0-9:%.]* *execve%('

curr: '[0-9:%.]* *execve%(', Time: 4.408s. next: '^__libc_start_main'

curr: '^__libc_start_main', Time: 0.000s. next: '^\* $$ JOB\>'
curr: '^\* $$ JOB\>', Time: 0.000s. next: '^// *JOB\>'
curr: '^// *JOB\>', Time: 0.000s. next: 'K & K  Associates'
curr: 'K & K  Associates', Time: 0.000s. next: 'TAK 2000'
curr: 'TAK 2000', Time: 0.000s. next: 'S Y S T E M S   I M P R O V E D '
curr: 'S Y S T E M S   I M P R O V E D ', Time: 0.000s. next: 'Run Date: '
```

The regex `[0-9:%.]* *execve%(` equivalent to `[0-9:.]* *execve(` without regex escape chars took $$\approx 4.4$$ seconds to evaluate, which is crazy considering all the other regexes evaluated instantly. I'm no expert in regexes but I think the issues is with a backtracking explosion. Remember the [naive string matching](https://en.wikipedia.org/wiki/String-searching_algorithm#Naive_string_search)?

Anyway, the trend was close to quadratic, on paper the regex had to perform $$\sum_{i=1}^N i = \frac{N(N+1)}{2} = O(N^2)$$ matches.

{% include figure.html path="assets/img/blog/2023-04-23/nvim-plot.png" class="img-fluid rounded z-depth-1" zoomable=true %}

I spent some time trying to understand why it was written that way, after all `[0-9:.]* *execve(` is equivalent to `execve(` given that both `[0-9:.]` and `\s` are matched zero or more times, so they don't really matter. This would not have been the case if the regex had been anchored.

Finally! Something is actually wrong (in vim too) and should be fixed.

I gave it a shot with the simplified regex. Comparing the time to open up the file before the fix

```sh
root@ff1d74dcbc84:~# time nvim /test/data/data/pi_30_000 +qall

real    0m6.142s
user    0m6.123s
sys     0m0.010s
```

and after the fix

```sh
root@ff1d74dcbc84:~# time VIMRUNTIME=/neovim/runtime/ /neovim/build/bin/nvim /test/data/data/pi_30_000 +qall

real    0m0.021s
user    0m0.014s
sys     0m0.000s
```
just awesome.

I updated the PR in nvim and opened a PR in vim with the simplified version of the regex. I also noticed that the very same regex had undergone some changes and it also used to be anchored. I think somewhere along the line an edit wasn't really equivalent, so I added a test to prevent future regressions. You know, just for good measure.

After some [back and forth](https://github.com/vim/vim/pull/12220) with @brammool on how to tackle this, I ended up with a fix that eventually got [accepted](https://github.com/vim/vim/commit/6e5a9f948221b52caaaf106079cb3430c4dd7c77) into vim codebase and [ported](https://github.com/neovim/neovim/commit/6d9f5b6bf0fc324b33ce01f74a6030c9271b1a01) into nvim.

```diff
	 || line4 =~ '^%.\{-}[Vv]irata'
	 || line5 =~ '^%.\{-}[Vv]irata'
    set ft=virata

    # Strace
-  elseif line1 =~ '[0-9:.]* *execve(' || line1 =~ '^__libc_start_main'
+    # inaccurate fast match first, then use accurate slow match
+  elseif (line1 =~ 'execve(' && line1 =~ '^[0-9:.]* *execve(')
+	   || line1 =~ '^__libc_start_main'
    set ft=strace

    # VSE JCL
    elseif line1 =~ '^\* $$ JOB\>' || line1 =~ '^// *JOB\>'
```
Now that I look at it I think `^[0-9:.]* *execve(` was enough to guarantee optimal performances and correctness, but whatever.

And that folks, is how I made nvim $$6.142 / 0.021 = 292.48 \approx 300$$ times faster ;)

## Conclusion

This was an interesting and fun exercise in troubleshooting.

It made me appreciate open source and hate regex even more! After this was done I started to wonder if a tool to [simplify](https://en.wikipedia.org/wiki/NFA_minimization) regexes exists and how [difficult](https://cstheory.blogoverflow.com/2011/08/on-learning-regular-languages/) it would be to make one. Maybe I'll give it a shot.

Another interesting way to investigate slow downs in nvim that I found is [this](https://github.com/stevearc/profile.nvim) amazing profiling plugin. In case `--startuptime` doesn't give enough or any actionable information.

