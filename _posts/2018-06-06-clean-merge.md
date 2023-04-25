---
layout: post
title:  "A clean merge for branches"
description:   "Merge branches with just one commit"
teaser: "Keep master branch without intermediate commits"
categories: development
tags:
    - git
---

Once the work on a side branch is completed, usually all updates need to be merge to the `master` branch. To do that it's possible to<!--more--> use the classic approach:

Assuming the branch `feature-x` should be merge to `master`just type

```
git checkout master
git merge feature-x
```

With that a **merge commit** will be created and the `master` branch will display all commits made previously on the side branch. One way to avoid this is to rebase and squash all commits into one and then merge that single commit to `master`

```
git rebase -i HEAD~n
```

Where `n` are the number of commit you want to squash. Or just rebase from the first commit of the new branch

```
git rebase -i hash_commit
```

In the example below I want to merge all commit related to the script into the `master` branch. So I can use

```
git rebase -i HEAD~3        // or
git rebase -i 2a62715
```

![Complete rebasing]({{ site.urlimg }}rebase-squash/choose.png){: .center }

Then it's possible to choose which commits to pick and which to squash (or reword, edit and so on)

![Complete rebasing]({{ site.urlimg }}rebase-squash/squash.png){: .center }

Once the commits to be squashed are being selected, close and save. Then it will be possible to change/add the message for this big one commit

![Complete rebasing]({{ site.urlimg }}rebase-squash/message.png){: .center }

Finally it's time to merge the commit. With `git log` it's possible to check the result

![Complete rebasing]({{ site.urlimg }}rebase-squash/done.png){: .center }
