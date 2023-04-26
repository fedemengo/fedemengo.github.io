---
layout: post
title: Visualizing cellular automata
date: 2022-10-28
description:
tags: computation automata
hidden: true
---

<script>

let renderModels = (models, darkTheme) => {
    for(let model of models) {
        // get the parent element of the viewer
        let parentDiv = document.getElementById (model.id);
        if(parentDiv.hasChildNodes()) {
            parentDiv.removeChild(parentDiv.firstChild)
        }

        // initialize the viewer with the parent element and some parameters
        let viewer = new OV.EmbeddedViewer(parentDiv, {
            backgroundColor : new OV.RGBAColor(255, 255, 255, 0),
            defaultColor : new OV.RGBColor(127, 127, 127),
            edgeSettings : {
                showEdges : true,
                edgeColor : new OV.RGBAColor(0, 0, 0, 1),
                edgeThreshold : 0.5
            },
            environmentSettings : {
                environmentMap : [],
                backgroundIsEnvMap : false
            },
            onModelLoaded : () => {
                let model = viewer.GetModel ();
            }
        });

        viewer.viewer.SetFixUpVector (false);
        viewer.LoadModelFromUrlList ([
            model.m,
            "/assets/models/automata.mtl"
        ]);
    }
}

window.addEventListener('load', () => {
    darkTheme = window.__theme__ == 'dark'
    renderModels([
        {"m": "/assets/models/rule30.obj", "cap": "rule 30", "id": "viewer-rule-30"},
        {"m": "/assets/models/rule110.obj", "cap": "rule 110", "id": "viewer-rule-110"},
        {"m": "/assets/models/rule169.obj", "cap": "rule 169", "id": "viewer-rule-169"},
        {"m": "/assets/models/code422.obj", "cap": "code 422", "id": "viewer-code-422"},
        {"m": "/assets/models/code460.obj", "cap": "code 460", "id": "viewer-code-460"},
    ], darkTheme)
});

</script>

In this post I plan to set the scene for a nice visualization of cellular automata and pretty much anything else.

The idea is basically a mix of Github ability to preview `.stl` 3d files and the illustration in Wolfram's "A new kind of science".

Bulding on what I did in the previos post, once the run for a CA rule has been generate, it's easy to manipulare the bits and generate vertexes and faces of the 3d figure (in this case the format is [.obj](https://en.wikipedia.org/wiki/Wavefront_.obj_file))

```python
import numpy as np
import math
import matplotlib.pyplot as plt

import import_ipynb
from automata_generation import generate, plot_run, make_columns

# manually specify the logic to map a cube face to 4 of its 8 vertexes
def face(face, count):
    if face == 1:
        return f'f {count+1} {count+2} {count+4} {count+3}'
    elif face == 2:
        return f'f {count+1} {count+2} {count+6} {count+5}'
    elif face == 3:
        return f'f {count+2} {count+6} {count+8} {count+4}'
    elif face == 4:
        return f'f {count+3} {count+4} {count+8} {count+7}'
    elif face == 5:
        return f'f {count+1} {count+5} {count+7} {count+3}'
    elif face == 6:
        return f'f {count+5} {count+6} {count+8} {count+7}'

def generate_cell(file, count, i, j):
    start = count * 8

    lines = [f'g cell{i}-{j}\n', 'usemtl Red\n']
    vertex = []
    z = 0
    for di in [0, 1]:
        for dj in [0, 1]:
            for dz in [0, 1]:
                vertex.append(f'v {j+dj} {i+di} {z+dz}\n')

    for v in vertex:
        lines.append(v)

    for i in range(6):
        lines.append(face(i+1, start) + '\n')

    lines.append("\n")
    file.writelines(lines)


def create_3d_obj(rule, data):
    count = 0
    filename = f'{rule}.obj'
    file = open(filename, "w")
    file.writelines(["mtllib automata.mtl\n"])

    for i, row in enumerate(data):
        for j, col in enumerate(row):
            if data[i][j] == 1: # 0 or 1 depending on the CA
                generate_cell(file, count, len(data)-i, j)
                count += 1

    file.close()
    return filename
```


```python
rule = 30
size = 200
steps = 200
start = np.zeros(size)
start[45:55] = 1
data, _ = generate(rule, size, steps, with_init=start)

create_3d_obj(rule, data)
```




    '30.obj'

And here's the result

<div id="viewer-rule-30" style="width: 800px; height: 600px;"></div>
<div class="caption">rule 30</div>

<div id="viewer-rule-110" style="width: 800px; height: 600px;"></div>
<div class="caption">rule 110</div>

<div id="viewer-rule-169" style="width: 800px; height: 600px;"></div>
<div class="caption">rule 169</div>

This gets even more cool with 2D CA

<div id="viewer-code-422" style="width: 800px; height: 600px;"></div>
<div class="caption">code 422</div>

<div id="viewer-code-460" style="width: 800px; height: 600px;"></div>
<div class="caption">code 460</div>

Coming soon:

I'm no expert on 3d visualization but I think the reason the figures are a bit laggy, especially if they are large enough, is that each CA cell is its own figure. One optimization that I'll try to implement in the future is to merge all adjacent cells into one figure (this mean that all non-edge vertex can be removed and several faces merged together).

I'll probably need to use use [SCC](https://en.wikipedia.org/wiki/Strongly_connected_component) to undersand which cells should be merged together. The tricky thing will probably be specifying the vertexes for such non regular faces (since the list of vertex needs to be ordered - in general counter clock wise). I will probably need to used some idea from the [convex hull](https://en.wikipedia.org/wiki/Convex_hull) to specify such ordering.

It should be fun

