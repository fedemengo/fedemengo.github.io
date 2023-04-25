---
title: "Getting started with Elasticsearch"
subheadline: "Overview on Elasticsearch"
teaser: "Introduction to the Elasticsearch environment"
categories: elasticsearch
---

Elasticsearch is a document-oriented searching engine that allow to store, search (in near real time), analyze big amount of data<!--more-->. To do that,
it maintains a data structure called **inverted index** that maps each words that appear in a text to the relative document.

To create an inverted index, Elasticsearch performs two operations:
* Split the content of each document in a list of unique word (**token**)
* Create a structure with a relation `one-to-many` between a token and all IDs of documents where the token appears in.

Here is an example
```
Lorem Ipsum is simply random text of the printing industry
```
{: title="Document 1"}

```
Contrary to popular belief, Lorem Ipsum is not simply random text
```
{: title="Document 2"}

The resulting highly simplified inverted index structure (in reality is more complex than that)

<div align="center">
  <table style="border-spacing: 5px; table-layout: fixed;">
    <tr style="text-align: center; border: 1px solid black;">
      <th style="text-align: center; border: 1px solid black; width: 30%;">Token</th>
      <th style="text-align: center; border: 1px solid black; width: 20%;">Document ID</th>
      <th style="text-align: center; border: 1px solid black; width: 30%;">Token</th>
      <th style="text-align: center; border: 1px solid black; width: 20%;">Document ID</th>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">belief</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">popular</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">2</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">contrary</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">printing</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">industry</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">random</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">ipsum</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">simply</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">is</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">text</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">lorem</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1, 2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">the</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">not</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">2</td>
      <td style="text-align: center; border: 1px solid black; width: 30%;">to</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">2</td>
    </tr>
    <tr style="text-align: center; border: 1px solid black;">
      <td style="text-align: center; border: 1px solid black; width: 30%;">of</td>
      <td style="text-align: center; border: 1px solid black; width: 20%;">1</td>
    </tr>
  </table>
</div>

## Terminology

#### Cluster
A collection of node that holds the entire data. Using a cluster it's possible to drastically decrease to time for each search.

#### Node
A node is a single server that is a part of a cluster (if by itself, the cluster is made of just the node) and stores data.

#### Field
In the JSON format, a field represent the `key` to which can be assigned a `value`.

#### Document
Documents are the basic unit of data that can be index, they are basically a set of fields.

#### Index
An index is a collection of documents with similar characteristics.

#### Shard
Shards are fully functional fractions of an index that can be stored as independent entity on server. Are use to split
the index when it's dimension are too big for storing it on a single machine (or just for load balancing).
Shards are very useful for:
* Horizontal scale
* Distribute and parallel operations

#### Replica
To prevent loss of data, replicas are identical copy of index's shards that are stored in different node that the one that store
the original shards. Replicas are a mechanic to prevent data being inaccessible when, for example, a nod goes down.

{%comment%}
{% highlight js %}
curl -XGET "http://localhost:9200/vehicles/car/_search?pretty"
curl -XPUT "http://localhost:9200/vehicles/car/126" -d '{ "make": "Yamaha", "Color": "Green", "HP": 450, "miliage": 1000, "price": 35000 }'
{% endhighlight %}
{%endcomment%}

{%comment%}
{% for job in site.jobs reversed %}{% unless job.hidden %}
 * <span title="{{ job.dates.from }}">{{ job.dates.from | date: '%Y' }}</span>
   --
   <span title="{{ job.dates.to }}">{{ job.dates.to | date: '%Y' }}</span>
   {% include datediff.liq begin=job.dates.from end=job.dates.to measure='dynamic' %}
   {% if result != 0 %}(~{{ result }}&nbsp;{{ measure }}){% endif %}:
   [**{{ job.title }}**]({{ site.baseurl }}{{ job.url }}){: title="{{ job.type }}: {{ job.role }} in {{ job.maintech }}"}{% endunless %}{% endfor %}
{%endcomment%}
