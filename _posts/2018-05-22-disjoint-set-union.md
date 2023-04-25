---
layout: post
title:  "Disjoint Set"
description:   "An efficent DSU implementation"
categories: data-structures
tags:
    - cpp
---

A Disjoint Set data structure (or Disjoint-Set-Union DSU) allows to efficiently determine whether two elements belong to same set when those set are dynamic<!--more-->

Given a collection $$S = \\{S_1, S_2, \dots, S_N\\}$$ of disjoint set, with the DSU data structure it's possible to merge some of this collections and retrieve the set a collection belongs to. Such structure should support the following operations:dis

* `MakeSet(x)` - Create a new disjoint whose only member is $$x$$, that's it $$X = \\{x\\}$$
* `Union(x, y)` - Unites the two disjoint sets $$x$$ and $$y$$ in a new set that is the union of the two: given $$Y = \\{y\\}$$ and $$X = \\{x\\}$$ then $$Z = Union(x, y) = X \cup Y = \\{x, y\\}$$
* `FindSet(x)` - Find in which set the element $$x$$ is contained. Following the above example $$FindSet(x) = Z$$

A naive implementation of such structure might be a linked list of collection, with each list representing a disjoint set.

A `MakeSet(x)` would consist in creating a new linked list identified by $$X$$ in $$O(1)$$. The `Union(x, y)` would append the list representing the $$Y$$ set to the list representing the $$X$$ set, this is done in $$O(l)$$ where $$l$$ is the length of $$Y$$ since every element of $$Y$$ need to be updated. `FindSet(x)` would consist in determining in which list the element belong too, easy to do it in $$O(1)$$ (just save the a reference to the list when merging two sets).

There can be at most $$N-1$$ `Union(x, y)` calls (this because each call reduce the number if disjoint set by $$1$$) and it's trivial to create a <a href="#explanation">sequence*</a> of call that would make the total running time $$O(N^2)$$ it's important to find a better solution.

The first observation is that it's more convenient to append the shorter list to longer one. This is an heuristic technique called **union by rank**.

To achieve another increase in performances a tree-like structure should be considered (merge would just append one set to another by making it one of its children nodes). In this way, when merging two set, it's not necessary to update the reference of every elements. The update operations will be performed by a recursive `FindSet(x)` operations. Since `FindSet(x)` would locate the element $$x$$ and the follow the tree until its root (where is stored the set identifier), it's possible to update, for every nodes, its root while walking up to the root using **path compression**. By doing that after a `FindSet(x)` call, every element in $$X$$ would directly have a reference to $$X$$.

The code below can help understand the reasoning.

{% highlight cpp %}
#include <vector>

class dsu {
private:
    std::vector<int> parent;
    std::vector<int> rank;
public:
    dsu(int size) : parent(size), rank(size, 0) {
        for(int i=0; i<size; ++i){
            parent[i] = i;
        }
    }

    int find_set(int x){
        // Path compression
        if(parent[x] != x){
            parent[x] = find_set(parent[x]);
        }
        return parent[x];
    }

    void unite(int x, int y){
		int set_x = find_set(x);
		int set_y = find_set(y);
        if(set_x != set_y){
            // Union by rank
            if(rank[set_x] > rank[set_y]){
                parent[set_y] = set_x;
            } else {
                parent[set_x] = set_y;
            }
            if(rank[set_x] == rank[set_y]){
                rank[set_y]++;
            }
        }
    }
};
{% endhighlight %}

The code doesn't show the `MakeSet(x)` operations because it assume that the maximum number of initial disjoint set it's known, anyway it would be trivial to implement it.

<a name="explanation">\*</a> If `Union(x, y)` merge set $$X$$ and set $$Y$$ by appending $$Y$$ to $$X$$ such sequence is given by the following. Let $$S = \\{S_1, S_2, \dots, S_N\\}$$ be a collection of disjoint set and $$B = S_1$$, then $$\forall A \in S \setminus B, B = Union(A, B)$$. The set $$B$$ would then became $$\\{S_2\\} \cup \\{S_1\\}$$, $$\\{S_3\\} \cup \\{S_1, S_2\\} \dots$$ and finally $$\\{S_N\\} \cup \\{S_1, S_2, \dots, S_{N-1}\\}$$. At every iteration the larger set is updated, yielding to a running time of $$\sum\limits_{i = 1}^{N-1} i = \dfrac{(N-1)N}{2}= O(N^2)$$
