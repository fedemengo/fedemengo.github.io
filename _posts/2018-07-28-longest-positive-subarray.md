---
layout: post
title:  "Longest positive subarray"
description: "Find the largest interval with positive sum"
categories: puzzle
tags:
    - cpp
---

Given an array of $$n$$ non-all positive integer $$a$$, find the pair of indeces $$(l, r) \in P$$, where $$P = \\{(i, j) \mid 0 \leq i \leq j \le n, \sum\limits_{k = i}^{j} a[k] \geq 0 \\}$$ such that $$r-l \geq i-j\ \forall (i, j) \in P$$.<!--more-->posi

With a naive approach it's possible to solve the problem with a complexity of $$O(n^3)$$. The following code is an example.

{% highlight cpp %}
for(int i=0; i<a.size(); ++i){
    for(int j=i; j<a.size(); ++j){
        int sum = 0;
        for(int k=i; k<=j; ++k)
            sum += a[k];
        if(sum >= 0){
            if(j-i > maxLen){
                maxLen = j-i;
                res = {i, j};
            }
        }
    }
}
{% endhighlight %}

Using the same algorithm, but optimizing it with prefix sum, decreases the time complexity to $$O(n^2)$$.

However, there is a linear solution to the problem. To code this solution some auxiliary arrays would come in handy. The same $$prefix\\_sum$$ array of before is used to compute the sum of a whole interval in constant time and the $$best$$ array is used to keep track of the biggest of those prefix sum from the end to the beginning (it's actually the array of prefix maximums). Basically you want to know whether it's worth to keep expanding the interval on the right or if you should discard some elements by trimming the interval on the left.

{% highlight cpp %}
prefix_sum[0] = a[0];
for (int i = 1; i < a.size(); i++)
    prefix_sum[i] = prefix_sum[i - 1] + a[i];

best[N - 1] = prefix_sum[N - 1];
for (int i = a.size() - 2; i > -1; i--)
    best[i] = max(best[i + 1], prefix_sum[i]);
{% endhighlight %}

The following example should clarify the reasoning

Given the array $$a = [3, -5, 8, 6, -9, 5, -3, -4, 2, -7]$$, $$best$$ became $$[12, 12, 12, 12, 8, 8, 5, 3, 3, -4]$$. Since the problem ask to maximize the length of the interval, it's easy to understand that we would never consider the solution $$(0, 2)$$ since we can increase the interval to $$(0, 3)$$ and obtain a valid solution.

This last part of the code  should be clear now. We compute the sum of the subarray $$a[l, r]$$ and if it's positive try to expand the interval on the right, if it's not just trim the interval from the left.

{% highlight cpp %}
while (r < a.size()) {
    curr = l > 0 ? best[r] - prefix_sum[l-1] : best[r];
    if (curr >= 0) {
        if(r - l > maxLen){
            maxLen =  r - l;
            res = {l, r};
        }
        r++;
    } else {
        l++;
    }
}
{% endhighlight %}

A small optimization that doesn't change the asymptotic complexity but that can make the program run faster is the following: from the first example it's possible to see that there are lot of duplicate elements in the array $$best$$ and for everyone of them the sum is computed with the same result. It's enough to memorize only the unique values and make the index $$r$$ jump to those value.

{% highlight cpp %}
int main(int argc, char *argv[]){

    int N, l = 0, r = 0, maxLen = -1, curr;
    cin >> N;

    vector<int> v(N), prefix_sum(N);
    stack<int> best_index;
    pair<int, int> res({-1, -1});

    for(int &x: v) cin >> x;

    prefix_sum[0] = v[0];
    for (int i = 1; i < v.size(); i++)
        prefix_sum[i] = prefix_sum[i - 1] + v[i];

    best_index.push(-1);        // dummy value
    best_index.push(N-1);
    for (int i = v.size() - 2; i > -1; i--){
        if(prefix_sum[best_index.top()] < prefix_sum[i])
            best_index.push(i);
    }

    while (best_index.size()) {
        curr = l > 0 ? prefix_sum[r] - prefix_sum[l-1] : prefix_sum[r];
        if (curr >= 0) {    // if possible, try to increase the interval on the right
            if(r - l > maxLen){
                maxLen =  r - l;
                res = {l, r};
            }
            r = best_index.top();
            best_index.pop();
        } else { // otherwise trim on the left
            ++l;
        }
    }

    for(int i=res.first; i<res.second+1; ++i)
        cout << v[i] << " ";
    cout << endl;
    cout << res.first << " " << res.second << '\n';
    cout << res.second - res.first + 1 << '\n';

    return 0;
}
{% endhighlight %}

Here the $$best$$ index has been replace by the $$best\\_index$$ stack that hold the indices to those unique values.
