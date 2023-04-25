---
layout: post
title:  "Maximum non adjacent subsequence"
description: "Find the non adjacent subsequence with maximum sum"
categories: puzzle
tags:
    - cpp
---

Given an arrays of $$A$$ size $$N$$, find a sequence of non adjacent value with the larger sum, the sequence should be something like $$A_i, A_{i+k}, A_{i+k'}, \cdots, A_{i+k^n}, \forall k > 1$$

It's easy to solve this problem with dynamic programming<!--more-->

{% highlight cpp %}
int dp(std::vector<int> &v, int index) {
    if(index >= v.size())
        return 0;

    if(memo[index] != -1)
        return memo[index];

    // including the current value "v[index]" require to skip the next at "index + 1"
    int incl = v[index] + dp(v, index + 2);
    // excluding the current value allows us to consider the next value at "index + 1"
    int excl = dp(v, index + 1);

    memo[index] = std::max(incl, excl);

    return memo[index];
}
{% endhighlight %}

Using a similar intuition it's possible to come up with a linear solution

{% highlight cpp %}
int linear(std::vector<int> &v) {
    int incl = v[0], excl = 0, tmp;

    for(int i=1; i<N; ++i){
        tmp = incl;
        incl = max(incl, excl + v[i]);
        excl = tmp;
    }
    return std::max(incl, excl);
}
{% endhighlight %}

By analyzing all possible cases we see that
- if `incl > excl + v[i]` we don't care for the current value, hence we can decide both to consider the next element or to skip it. So `incl` is going to be equal to `excl`
- if `incl < excl + v[i]` then `incl` has the current value, while `excl` is set to the previous value of `incl`

Basically at every iteration `incl` and `excl` are swapped (except for the case when using a value doesn't led to a better solution)
