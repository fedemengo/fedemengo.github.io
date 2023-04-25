---
layout: post
title: "Designing an efficient webcrawler"
description: "What's powering every search engine?"
categories: system-design
---

## Terminology

- Web crawlers generally start from a **seed** web page and can collect data form many more pages by following all outgoing links <!--more-->
- Web crawlers can be **exhaustive** or **topical/focused** depending on the pages they will inspect (follow one topic, follow pages newer than a given data and so on..)
- A crawling strategy can be selective on the maximum number of pages to fetch: **short** vs **long crawls**

## Architecture

### Components

- Frontier
- Fetcher
- Parser
  - url extractor
  - url filtering
  - url prioritizer
- Storage

In addition to those component, that consists of the bare minium for a simple crawler,  a distributed web crawler will require  a url distributor that will take care of assigning url to each crawler (right after extracting them) based on on the respective locality.

#### Frontier

A **frontier/open-list** (list of unvisited urls) is initialized with a seed and store all the unvisited urls. Can be an in-memory data structure for small crawlers while it usually stores the urls on disk for large scale systems. It's necessary to avoid adding duplicates to the frontier, so a separate hash-table or Bloom filter can be used to avoid the problem. When the frontier reaches it's maximum capacity, only **one** new url can be added from the current page. Urls extracted from a page are generally assigned a score depending on their importance according to the crawling strategy.

It may happens that the frontier contains many urls that point to the same or similar page, this problem is referred to as the **spider-trap**. In this case it's reasonable to only accept $$k$$ urls for the same domain every $$n$$ urls processed.crawcraw

When urls are assigned a crawling priority it useful to implement the frontier as priority queue. The problem when using a disk-based priority queue is that is necessary to rearrange elements periodically and that would results in many disk seeks, consequentially limiting the number of insertion per second.

A possible solution is to discretize the priority and have as many frontier as interval of priority.


#### Fetching

An http client is necessary to fetch a webpage. It needs to be configured with a timeout (to avoid wasting waiting for a response too long), it has to to inspect the header of page (for redirection, last modified date and so on). Before fetching a page from a new host, the crawler should check for a `robots.txt` file that inform the crawler to skip specific urls.

In a distributed crawler it's important to avoid issuing multiple overlapping request to the same server (denial-of-service), to do this one solution could be to map a domain to a single crawling unit. Another way to avoid sending too many requests consists on adding a delay before requesting another page form the same domain (for example 10 times the time it took to download the last page); in real implementation there is generally just one frontier per worker and many backend frontiers (in the url distributor), each one assigned to a specific domain.

Other data-structure used to improved the performances of a crawler are the robot.txt cache and the DNS cache.

#### Parsing

A **crawling loop** fetch the next url in the frontier, extract application specific data and add the page'urls to the frontier.

Before adding new urls to a page, such url need to be **canonicalized** meaning it's necessary to transform the url applying certain criteria, the key is applying them consistently

- Convert protocol and hostname to lowercase
- Remove anchor or references
- Perform url-encoding of special characters
- Add trailing `/` when necessary (`x.y` and `x.y/`)
- Remove default web pages (`x.y/` and `x.y/index.html`)
- Resolve local path
- Leave port number unless is port `80` (default)
- Known mirrors
- Consider limiting the url size to 128/256 characters

When extracting data from a page, it's a good practice to **stoplist** (remove common stop works) and **stem** (conflate words to a common root).

In the case of a distributed crawler that partitions the url space among each replica, it's important to have a mean to send an extracted url to the appropriate instance: this can be achieved with p2p communication (consistent hashing/DHT or using a central source of urls distribution)

## Algorithms

### Naive Best-First crawler

Each fetched page is represented as list of words weighted by their frequency, it then computes the similarity between the page and the description provided by the user. A similarity function can be

$$
sim(q, p) = \dfrac{Vq \cdot{ Vp}}{\mid\mid Vq\mid\mid \cdot \mid\mid Vq \mid\mid}
$$

Where $$Vq, Vp$$ are the term frequency vector for query and fetched page and $$\mid\mid v \mid\mid$$ is the Euclidean norm of the vector $$v$$

### SharkSearch

This algorithm uses the anchor-text, anchor context and inherited scores to assigned a more refined score by also keeping track of the value of the pages on a path (if such pages are not important it stops crawling down the path, a depth bound is also used as upper bound). The following function can be used

$$
score(url) = \gamma \cdot inherited(url) + (1-\gamma) \cdot neighborhood(url)
$$

where $$\gamma < 1$$, $$inherited$$ is obtain from the ancestor of the page and $$neighborhood$$ is calculated using anchor-text and anchor context.

The $$inherited$$ score is computed as

$$
inherited(url) =
\begin{cases}
    \delta \cdot sim(q, p) & \mbox{if } sim(q, p) > 0 \\
    \delta \cdot inherited(p) & \mbox{otherwise}
\end{cases}
$$

where $$\delta < 1$$, $$q$$ is the query and $$p$$ is the page from which the url is extracted.

while the $$neighborhood$$ is calculate as

$$
neighborhood(url) = \beta \cdot anchor(url) + (1-\beta) \cdot context(url)
$$

where $$\beta < 1$$, $$anchor(url) = sim(q, anchorText)$$ and

$$
context(url) =
\begin{cases}
    1 & \mbox{if } anchor(url) > 0 \\
    sim(q, augContext) & \mbox{otherwise}
\end{cases}
$$

The algorithms is defined with as a parametrized function $$SharkSearch(d, \gamma, \delta, \beta)$$

### Advanced

Other advanced crawler are **focused crawlers, context focused crawler** and **InfoSpiders**

## Page importance

- Keyword in document: depends on the number and frequency of keywords in the query that the page contains
- Similarity to a query: generally used when the query is a relatively long text
- Similarity to seed page: calculated using the similarity function between all seed pages combined and the crawled page
- Classifier score: either a boolean or continuos relevance score assigned to each page using a trained classifier
- Retrieval system rank: $$N$$ different crawlers (namely using different strategy) are started form the same seeds and allowed to crawl $P$$ pages, once the $$N \cdot P$$ have been crawled, they get ranked against the initial query using some retrieval system.
- Link bases popularity: PageRank, HITS or simpler version such as using the number of in-links to the crawled page

### Gotchas/Tips

- Consistent hashing to partition the urls
- Keep seen-urls in a disk-based hash table that store them sparsely and use, for example, the first $$k$$ bit of the hash to identify the disck block.

## References

- [Crawling the Web](https://dollar.biz.uiowa.edu/~gpant/Papers/crawling.pdf)
- [Web Crawling](http://infolab.stanford.edu/~olston/publications/crawling_survey.pdf)
