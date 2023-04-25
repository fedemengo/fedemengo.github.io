---
layout: post
title:  "K-way merge"
description: "Merge K sorted container"
categories: puzzle
tags:
    - cpp
    - java
---

Given $$K$$ sorted arrays (or any sequential container) of size $$N$$, merge them into one sorted array.

## Naive solution

A naive solution would require to inspect the first element of all $$K$$ array to find the minimum<!--more-->. This process would be repeated for all $$N \cdot K$$ values, giving a total complexity of $$O(N\cdot K^2)$$

## Improved solution

Another approach consist of creating the new array with all $$N\cdot K$$ value and then sort it, with a running time of $$O((N\cdot K)\log (N\cdot K))$$. The problem with this is that we don't exploit the fact that the arrays are already sorted.

## Optimal solution

An optimal solution require to quickly find the next element in the sequence among other $$K$$ elements. For this reason it's possible to use a heap of $$K$$ elements that "always" stores the first element of each $$K$$ arrays. When we remove the minimum value, let's say from array $$i$$, we need to push in the heap the next element from the same array $$i$$.

In the following example the algorithm is used to merge $$K$$ linked list of size $$N$$

{% highlight cpp %}
void kway_merge(std::vector<single_linked<int>> &lists, single_linked<int> &res){

    binary_heap<int, int> max_heap([](int k1, int k2) { return k1 > k2;});

    for(int i=0; i < lists.size(); ++i){
        if(lists[i].size()){
            max_heap.push(lists[i].front(), i);
            lists[i].pop_front();
        }
    }

    // keep a heap with the next lists.size() == K, larger elements
    while(max_heap.size()){     // N * K
        auto curr_top = max_heap.top();
        max_heap.pop();                     // LOG K

        int val = curr_top.first;
        int list_idx = curr_top.second;

        res.push_back(val);

        if(lists[list_idx].size()) {    // I should add a new element from the next list
            max_heap.push(lists[list_idx].front(), list_idx);   // LOG K
            lists[list_idx].pop_front();
        }
    }

    // Total complexity O(N * K log K)

}
{% endhighlight %}

This particular implementation of the heap allows to store a `key-value` element instead of the classic heap where the value is also the key. The `key` represent the actual value of the element and the `value` represent the index of the array the item is from.

It's necessary to fill the heap with the first elements of each array, this operations takes $$\sum\limits_i^K \log i = O(K \log K)$$ and then, the while loop it's going to perform $$N \cdot K$$ iteration during which the minimum/maximum value is removed from the heap and new value is pushed, so the time complexity would be $$O(N\cdot K \log K)$$.

Overall the total running time is going to be $$O(K \log K) + O(N\cdot K \log K) = O(N\cdot K \log K)$$, the main improvement is achieved by keeping only $$K$$ values in the heap.

## Optimal solution (variant)

Another similar solution consists in merging two lists at the time until we end up with just one list, the result. In this case, with the same assumption as before, we are performing $$\dfrac{K}{2}, \dfrac{K}{4}, \dots, 2 = \log_{2}K$$ merges of $$N, 2 \cdot N, \dots, 2^{\log_{2}K} \cdot N = K \cdot N$$ elements. This solution has the same running time of $$ O(N\cdot K \log K)$$

{% highlight java %}
Node kwayMerge(Node[] lists){
    Queue<Node> q = new LinkedList<>();

    for(Node n: lists) {
        q.add(n);
    }

    while(q.size() > 1) {
        for(int i=0; i<q.size(); i+=2) {
            Node x = q.poll();
            Node y = q.poll();
            Node z = merge(x, y);
            q.add(z);
        }
    }

    return q.poll();
}
{% endhighlight %}


<details>
<summary><a>Expand</a> merge routine</summary>

{% highlight java %}
class Node {
    int val;
    Node next;

    Node(v) {
        val = v;
    }
}

Node merge(Node l1, Node l2) {
    if(l1 == null)
            return l2;
    if(l2 == null)
        return l1;

    ListNode root = new ListNode(-1);
    ListNode next = root;

    while(l1 != null || l2 != null) {
        if(l1 != null && l2 != null) {
            next.next = l1.val < l2.val ? l1 : l2;
        } else if(l1 != null) {
            next.next = l1;
        } else {
            next.next = l2;
        }

        if(next.next == l1) {
            l1 = l1.next;
        } else {
            l2 = l2.next;
        }

        next = next.next;
    }

    return root.next;
}
{% endhighlight %}
</details>
