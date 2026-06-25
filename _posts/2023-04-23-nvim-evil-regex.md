---
layout: post
title:  How I Made Neovim 300x Faster
description: Tracking down an evil regex in Vim and Neovim
tags: vim nvim regex
categories: debugging
---

## Intro

For a while, I have been working on a side [project](https://github.com/fedemengo/d2bist) that generates files with long sequences of `0`s and `1`s. Nvim is my primary editor, so I often need to inspect or modify those files. To my great annoyance, whenever a file contained more than a few tens of thousands of bits, nvim would hang for several seconds, minutes, or until I finally SIGKILLed it.

This kept happening, so I tried opening the same file with plain Vim. To my surprise, it opened instantly. Something had to be wrong with my config. After all, adding more and more plugins to nvim undoubtedly makes the editor heavier and slower. It was time to find out what was going on.

## How

I had never debugged performance issues in nvim before, so I did not have much to start with. My first suspicion was that the slowdown was caused by a plugin. I tried to binary-search the offending plugin, but even without plugins, opening that file was still slow.

I did not have many other ideas. Looking through the help, I discovered the `--startuptime` flag. Since I did not want to mess up my local configuration, I launched a Docker container, cloned and compiled nvim, verified that the problem was still present on `master`, and created an empty `init.lua`.

Then I ran:

```sh
root@ff1d74dcbc84:~# time nvim /test/data/data/pi_30_000 --startuptime vim-startup.log +qall

real    0m6.142s
user    0m6.123s
sys     0m0.010s
```

which generated:

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

Looking at the logs, it was clear that something bad happened between `029.058` and `6048.212`. In particular, `require('vim.filetype.detect')` took $$\approx 6$$ seconds.

Armed with `rg` and `fd`, after some code diving, I understood what that line did. As the name suggests, it is used to infer the file type. Nvim has a couple of ways to do that. If the type is not obvious from the extension, it first checks for [shebangs](https://en.wikipedia.org/wiki/Shebang_(Unix)) and, if necessary, tries to guess the file type from the file contents.

That was where my problem was. The file contents are fed to a set of regexes that assign a known file type when they match. For most of them, it is enough to test only the first few lines. In my case, the file was a single long line of characters, 30k to be exact. My first idea was to limit the amount of each line that every regex had to test to some "reasonable" upper bound. I think I used 1000 characters.

I changed that, recompiled nvim, and opened the file again.

Yep, the fix worked!

I pushed the fix and opened a PR. After some time, an nvim core maintainer looked at it and mentioned that nvim's logic matches Vim's. To avoid unnecessary divergence between the two projects, they suggested that I push the fix to Vim first. If it was accepted there, they would port it to nvim. Fair enough.

But could I really push that fix to Vim? Vim did not have the same performance problem, so it seemed unreasonable to cap the file content there just to solve an nvim-specific slowdown. I wanted to fix the issue where the fix actually made sense.

After some rubber ducking with ChatGPT and some searching, I read that Vim's regex engine is particularly efficient. Nvim, on the other hand, uses Lua's built-in pattern matching for this code path. Could the two really have this much of a performance difference? Only one way to find out: write some code and test it.

I started from [the relevant nvim filetype detection code](https://github.com/neovim/neovim/blob/53f36806f1b5107c0570ffbf57180a8e08f45b2e/runtime/lua/vim/filetype/detect.lua#L1660).

<details markdown="1">
<summary>So I basically rewrote this into a script and ran it against the file that was causing problems:</summary>

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

</details>

```sh
lua test.lua pi_30_000
```

Soon enough, I found the problematic regex:

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

The regex `[0-9:%.]* *execve%(`, equivalent to `[0-9:.]* *execve(` without the regex escape characters, took $$\approx 4.4$$ seconds to evaluate. That is wild, considering all the other regexes evaluated instantly. I am no regex expert, but I think the issue was a backtracking explosion. Remember [naive string searching](https://en.wikipedia.org/wiki/String-searching_algorithm#Naive_string_search)?

Anyway, the trend was close to quadratic. Fitting the measured startup times gives:

$$t(N) \approx 0.007754 \cdot N^{2.001}$$

where $$N$$ is the file-size label in thousands of characters and $$t(N)$$ is the startup time in seconds. The fitted exponent is effectively $$2$$, so the measured behavior is quadratic, or $$O(N^2)$$.

{% comment %}
{% include figure.html path="assets/img/blog/2023-04-23/nvim-plot.png" class="img-fluid rounded" %}
{% endcomment %}

```sh
                                   nvim startup: evil regex timing
      ┌──────────────────────────────────────────────────────────────────────────────────────┐
7801.9┤ .. N^2                                                                              x│
      │ xx data                                                                            . │
      │                                                                                   .  │
      │                                                                                 ..   │
      │                                                                                .     │
6501.7┤                                                                              ..      │
      │                                                                             .        │
      │                                                                           ..         │
      │                                                                          .           │
      │                                                                        x.            │
      │                                                                       .              │
5201.5┤                                                                     ..               │
      │                                                                    .                 │
      │                                                                  ..                  │
      │                                                                x.                    │
      │                                                              ..                      │
3901.3┤                                                           ...                        │
      │                                                         ..                           │
      │                                                       ..                             │
      │                                                     ..                               │
      │                                                   ..                                 │
2601.2┤                                                 ..                                   │
      │                                              ...                                     │
      │                                            ..                                        │
      │                                          x.                                          │
      │                                       ...                                            │
      │                                    ...                                               │
1301.0┤                                 ...                                                  │
      │                             ....                                                     │
      │                         ....                                                         │
      │                     x...                                                             │
      │            .........                                                                 │
   0.8┤x.x.....x...                                                                          │
      └┬────────────────────┬─────────────────────┬────────────────────┬────────────────────┬┘
      1.0                 25.8                  50.5                 75.2               100.0
seconds                         normalized file size (1 ~= 10k chars)

```

I spent some time trying to understand why it was written that way. After all, `[0-9:.]* *execve(` is equivalent to `execve(`, because both `[0-9:.]` and the space are matched zero or more times. They do not constrain the match unless the regex is anchored.

Finally! Something was actually wrong, in Vim too, and it should be fixed.

I gave it a shot with the simplified regex. Here is the time to open the file before the fix:

```sh
root@ff1d74dcbc84:~# time nvim /test/data/data/pi_30_000 +qall

real    0m6.142s
user    0m6.123s
sys     0m0.010s
```

and after:

```sh
root@ff1d74dcbc84:~# time VIMRUNTIME=/neovim/runtime/ /neovim/build/bin/nvim /test/data/data/pi_30_000 +qall

real    0m0.021s
user    0m0.014s
sys     0m0.000s
```

Much better.

I updated the nvim PR and opened a Vim PR with the simplified regex. I also noticed that the same regex had changed over time and used to be anchored. I think an edit somewhere along the line was not actually equivalent, so I added a test to prevent future regressions. You know, just for good measure.

After some [back and forth](https://github.com/vim/vim/pull/12220) with @brammool on how to tackle this, I ended up with a fix that eventually got [accepted](https://github.com/vim/vim/commit/6e5a9f948221b52caaaf106079cb3430c4dd7c77) into the Vim codebase and [ported](https://github.com/neovim/neovim/commit/6d9f5b6bf0fc324b33ce01f74a6030c9271b1a01) into nvim.

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
Looking at it now, I think `^[0-9:.]* *execve(` would have been enough to guarantee both correctness and good performance, but whatever.

And that, folks, is how I made nvim $$6.142 / 0.021 = 292.48 \approx 300$$ times faster.

## Conclusion

This was an interesting and fun exercise in troubleshooting.

It made me appreciate open source and hate regex even more. After this was done, I started to wonder whether a tool to [simplify](https://en.wikipedia.org/wiki/NFA_minimization) regexes exists, and how [difficult](https://cstheory.blogoverflow.com/2011/08/on-learning-regular-languages/) it would be to make one. Maybe I will give it a shot.

Another interesting way to investigate slowdowns in nvim is [this](https://github.com/stevearc/profile.nvim) excellent profiling plugin. It is useful when `--startuptime` does not give enough actionable information.

For example, this is what it showed for my problem. I added a small [wrapper](https://github.com/fedemengo/nvim/blob/5edbcf57707a5a987275dad8f1e78f3b13efddc4/fnl/mods/dev/profile.fnl) to my config, followed the repository instructions to generate a startup profile, and inspected the result with [Perfetto](https://github.com/google/perfetto).

{% include figure.html path="assets/img/blog/2023-04-23/profiler.png" class="img-fluid rounded" zoomable=true %}
