---
layout: page
permalink: /links/
title: links
description: A living list of interesting links, articles, tools, and resources.
nav: true
nav_order: 5
group_by: category
group_undefined_label: Misc
_styles: |
  .links-page .links-list li { margin: .2rem 0; }
  .links-page .links-toc { font-size: 0.85rem; }
  .links-page .links-toc ul { list-style: none; padding-left: 0; margin: 0; }
  .links-page .links-toc li { margin: .2rem 0; }
  .links-page .links-toc a { text-decoration: none; }
  /* Ensure in-page anchors are not hidden behind fixed navbar */
  .links-page .section-title { scroll-margin-top: 70px; }
  /* Keep sticky TOC clear of fixed navbar */
  .links-page .links-toc.sticky-top { top: 70px; }
---

{% assign links = site.data.links %}
{% if links and links.size > 0 %}
  {% assign groups = links | group_by: page.group_by | sort: 'name' %}

  <div class="links-page">
    <div class="row">
      <div class="col-sm-9">
        {% for group in groups %}
          {% assign section_name = group.name %}
          {% if section_name == '' or section_name == nil %}
            {% assign section_name = page.group_undefined_label | default: 'Misc' %}
          {% endif %}

          <div class="links-section">
            {% assign section_id = section_name | slugify %}
            <h2 id="{{ section_id }}" class="section-title">
              <a href="#{{ section_id }}">{{ section_name }}</a>
            </h2>
            {% assign items = group.items | sort: 'date' | reverse %}
            <ul class="links-list">
              {% for item in items %}
                <li>
                  <a href="{{ item.url }}">{{ item.title | default: item.url }}</a>{% if item.description %}: {{ item.description }}{% endif %}
                </li>
              {% endfor %}
            </ul>
          </div>
        {% endfor %}
      </div>
      <div class="col-sm-3">
        <nav class="links-toc sticky-top">
          <div class="text-muted small mb-1">Sections</div>
          <ul>
            {% for group in groups %}
              {% assign section_name = group.name %}
              {% if section_name == '' or section_name == nil %}
                {% assign section_name = page.group_undefined_label | default: 'Misc' %}
              {% endif %}
              {% assign section_id = section_name | slugify %}
              <li><a href="#{{ section_id }}">{{ section_name }}</a></li>
            {% endfor %}
          </ul>
        </nav>
  </div>
  </div>
  </div>
{% else %}
  <div>...</div>
{% endif %}
