---
layout: post
title:  "Betweeness Centrality"
description: "Implementation of Betweeness Centrality using Dijkstra and Fibonacci heap"
categories: algorithms
tags: data-structures cpp
---

The betweenness centrality is a measure of centrality in a graph based on shortest paths. It provide useful information
in any kind of situation where a network is involved<!--more-->. For example in a social network, it may represent the influence of
a single person (based on the number of mutual connection with other people). In a computer network a high value of
betweenness centrality, means that a computer is more involved in sharing information than another (important when analyzing
fault-tolerance). This is an implementation of [Brandes' algorithm](http://www.tandfonline.com/doi/abs/10.1080/0022250X.2001.9990249).

### Definition

Let $$G = (V, E) $$ be a graph with $$V$$ the set of vertices and $$E$$ the set of edges, $$\sigma_{st}(v)$$ be the number ofbit
shortest path from $$s$$ to $$t$$ through $$v$$ and $$\sigma_{st}$$ be the number of shortest path from $$s$$ to $$t$$. Then the betweenness centrality
index of $$v$$ is defined as $$B_C(v) = \sum\limits_{s\neq v\neq t \in V} \dfrac{\sigma_{st}(v)}{\sigma_{st}}$$

## Shortest Paths and Centrality Index

The problem itself can be seen and the combination of two problems:

- First of all, we must calculate all shortest path in the graph. In particular we need APSP (All Pair Shortest Path), this can
be done using Floyd-Warshall algorithm, but for sake of performances I used $$V$$ times Dijkstra algorithm (in particular it allow
to use an additional $$O(V)$$ memory instead of $$O(V^2)$$).

- The second problem require to calculate the centrality index using the formula.

### Shortest Paths

It's useful to augment Dijkstra algorithm to save some additional information. In particular for each node it's possible
to save a list of predecessor for any SP to the node and the total number of SPs. Finally, a stack is used to save the order
in which the nodes are visited.

{% highlight cpp %}
	// Betweeness Centrality (Dijkstra + centrality calculation)
void centrality(int V, graph &G, std::vector<double> &BC){

    fibonacci_heap<int, int> FH(V);             // FH with key(INT) and int(INT)
    std::stack<int> visited;
    std::vector<int> dist(V);
    std::vector<double> SP_count(V), BC_acc(V);
    std::vector<std::vector<int>> pred(V, std::vector<int>());
        // calculate SP from one node at the time and accumulate BC
    for(int source=0; source<V; ++source){
        FH.fill(V, INF);
        std::fill(dist.begin(), dist.end(), INF);
        std::fill(SP_count.begin(), SP_count.end(), 0.0);
        std::fill(BC_acc.begin(), BC_acc.end(), 0.0);

            // shortest-path with Dijkstra
        SP_count[source] = 1;
        dist[source] = 0;
        FH.decrease_key(source, 0);
        while(!FH.empty()){
            int u = FH.extract_min().vertex;
            visited.push(u);
            for(int i=0; i<G[u].size(); ++i){
                int v = G[u][i].vertex, w = G[u][i].weight;
                // new SP found that reach v, remove all the SP to v saved so far
                if(dist[v] > dist[u] + w){
                    dist[v] = dist[u] + w;
                    FH.decrease_key(v, dist[v]);
                    pred[v].clear();
                    pred[v].push_back(u);
                    SP_count[v] = SP_count[u];
                }
                // another SP that reach v with the same lengh, add it to the set of SP to v
                else if(dist[v] == dist[u] + w){
                    pred[v].push_back(u);
                    SP_count[v] += SP_count[u];
                }
            }
        }
        /*
            Centrality calculation
        */
    }
}
{% endhighlight %}

### Centrality Index

With the additional information stored while finding the SPs it's possible to calculate the centrality index in linear time
using Brandes intuition.

{% highlight cpp %}
	// Betweeness Centrality (Dijkstra + centrality calculation)
void centrality(int V, graph &G, std::vector<double> &BC){
    std::fill(BC.begin(), BC.end(), 0.0);

    std::stack<int> visited;
    std::vector<double> SP_count(V), BC_acc(V);
    std::vector<std::vector<int>> pred(V, std::vector<int>());
        // calculate SP from one node at the time and accumulate BC
    for(int source=0; source<V; ++source){
        /*
            Dijkstra
        */
            // centrality calculation
        while(!visited.empty()){
            int v = visited.top(); visited.pop();
            for(int i=0; i<pred[v].size(); ++i){
                int u = pred[v][i];
                double centrality = SP_count[v] ? SP_count[u]/SP_count[v] : 0;
                BC_acc[u] += (centrality + centrality*BC_acc[v]);
            }
            if(v != source)
                BC[v] += BC_acc[v];
        }
    }
}
{% endhighlight %}

I personally tested the algorithm using different data structure for Dijkstra algorithm (priority queue based on min-heap,
STL priority queue, STL set). The implementation using Fibonacci Heap performed better than expected, it can be compared to
the min-heap implementation. The Fibonacci Heap implementation can be found [here]({% post_url 2018-01-20-fibonacci-heap %}).
