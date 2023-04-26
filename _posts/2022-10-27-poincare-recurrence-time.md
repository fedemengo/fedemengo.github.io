---
layout: post
title: Poincaré recurrence time in cellular automata
date: 2022-10-27
description: Exploring the asimptotical behavior of CA
tags: computation automata
hidden: true
---


From wikipedia:
> The Poincaré recurrence theorem states that certain dynamical systems will, after a sufficiently long but finite time, return to a state arbitrarily close to (for continuous state systems), or exactly the same as (for discrete state systems), their initial state.
>
> The Poincaré recurrence time is the length of time elapsed until the recurrence. This time may vary greatly depending on the exact initial state and required degree of closeness.

Cellular automata are clearly discrete system. We can measure the Poincaré recurrence (PR) time in terms of steps (we can consider 1 step equivalent to 1 unit of time). It's enough to check if at any given step we enter in a state already seen. It's necessary to store each state seen (an entry in a dictionary) and check for evaluation.


```python
import numpy as np
import math
import matplotlib.pyplot as plt
```


```python
import import_ipynb
from automata_generation import generate, plot_run, make_columns
```

    importing Jupyter notebook from automata_generation.ipynb






```python
def find_recurrence(x):
    steps = {}
    for i in range(len(x)):
        row = x[i].tobytes()
        if row in steps:
            return i-steps[row]
        steps[row] = i

    if len(steps) == len(x):
        return -1
```


```python
def plot_recurrence_upperbound(rule, size=500, step_limit=1000):
    xs = np.empty(size-1)
    ub = np.zeros(size-1)
    steps = np.zeros(size-1)

    for i in range(1, size):
        xs[i-1] = i
        ub[i-1] = i
        x, idx = generate(rule, i, step_limit, test_recurrence=True, exit_on_recurrence=True)
        if idx != (-1, -1):
            d = idx[1] - idx[0]
            steps[i-1] = math.log2(d)
        else:
            steps[i-1] = -1

    return xs, ub, steps
```


```python
x, recurrence_indices = generate(50, 100, 100, test_recurrence=True, exit_on_recurrence=False)
find_recurrence(x)
```




    2




```python
def plot_recurrence_match(recurrence_indices):
    if recurrence_indices <= (0, 0):
        print("recurrence was not found")
        return

    y = np.concatenate(
        (
            x[max(0, recurrence_indices[0]-1):recurrence_indices[0]+2][:],
            [np.zeros(len(x[0]))],
            x[recurrence_indices[1]-1:min(recurrence_indices[1]+2, len(x)-1)][:]
        ),
        axis=0,
    )
    plot_run(y)
```


```python
plot_recurrence_match(recurrence_indices)
```


{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_8_0.png" class="img-fluid rounded " zoomable=true %}


It could be interesting to see poincare recurrence for each rule. Let's calculate the PR for each rule, with size in $[1...K]$ and a maximum number of step N and see what kind of trend we get for each rule.


```python
import time

colorize = np.vectorize(lambda x: 'red' if x == -1 else 'green')
execution_time = []
try:
    step_limit = 20000
    for r in range(0, 256):
        plt.clf()
        print(f'rule {r}')
        start = time.time()
        xs, ub, steps = plot_recurrence_upperbound(r, 50, step_limit=step_limit)
        end =  time.time()
        execution_time.append((end-start, r))
        print("\t", end - start)
        #plt.rcParams["figure.figsize"]=10,10
        #plt.plot(xs, ub)
        #plt.scatter(xs, steps, marker='.', c=colorize(steps))
        #plt.show()
        #plt.savefig(f"rule-{r}_{step_limit}steps.png")
except Exception as e:
    print("aborted", e)

execution_time.sort(reverse=True)
for e in execution_time[:20]:
    print(f"rule{e[1]} took {e[0]}")
```

    rule 0
    	 0.014295816421508789
    rule 1
    	 0.014110088348388672
    rule 2
    	 0.06731963157653809
    rule 3
    	 0.13080883026123047
    rule 4
    	 0.009865045547485352
    rule 5
    	 0.010412931442260742
    rule 6
    	 0.08333683013916016
    rule 7
    	 0.011668920516967773
    rule 8
    	 0.007643938064575195
    rule 9
    	 0.09536623954772949
    rule 10
    	 0.06816911697387695
    rule 11
    	 0.09696221351623535
    rule 12
    	 0.011855125427246094
    rule 13
    	 0.05993509292602539
    rule 14
    	 0.06050300598144531
    rule 15
    	 0.08336710929870605
    rule 16
    	 0.05897998809814453
    rule 17
    	 0.11812114715576172
    rule 18
    	 0.6909589767456055
    rule 19
    	 0.014127016067504883
    rule 20
    	 0.0891580581665039
    rule 21
    	 0.013031959533691406
    rule 22
    	 0.09264206886291504
    rule 23
    	 0.018725872039794922
    rule 24
    	 0.0650792121887207
    rule 25
    	 0.14934778213500977
    rule 26
    	 0.97776198387146
    rule 27
    	 0.1139979362487793
    rule 28
    	 0.054821014404296875
    rule 29
    	 0.011471986770629883
    rule 30
    	 26.5013108253479
    rule 31
    	 0.019721031188964844
    rule 32
    	 0.013998746871948242
    rule 33
    	 0.01690983772277832
    rule 34
    	 0.10316276550292969
    rule 35
    	 0.23908495903015137
    rule 36
    	 0.016974687576293945
    rule 37
    	 0.04945206642150879
    rule 38
    	 0.16737580299377441
    rule 39
    	 0.20819401741027832
    rule 40
    	 0.015106916427612305
    rule 41
    	 0.2780458927154541
    rule 42
    	 0.10079574584960938
    rule 43
    	 0.15611600875854492
    rule 44
    	 0.014432191848754883
    rule 45
    	 29.741049766540527
    rule 46
    	 0.06091904640197754
    rule 47
    	 0.08320116996765137
    rule 48
    	 0.05670809745788574
    rule 49
    	 0.11656785011291504
    rule 50
    	 0.031477928161621094
    rule 51
    	 0.00950002670288086
    rule 52
    	 0.08253312110900879
    rule 53
    	 0.11395692825317383
    rule 54
    	 0.041037797927856445
    rule 55
    	 0.009826183319091797
    rule 56
    	 0.06255269050598145
    rule 57
    	 0.10928201675415039
    rule 58
    	 0.061155080795288086
    rule 59
    	 0.10793924331665039
    rule 60
    	 8.379151105880737
    rule 61
    	 0.12112307548522949
    rule 62
    	 0.0664830207824707
    rule 63
    	 0.010135173797607422
    rule 64
    	 0.008372068405151367
    rule 65
    	 0.09740424156188965
    rule 66
    	 0.06685113906860352
    rule 67
    	 0.11491107940673828
    rule 68
    	 0.007071018218994141
    rule 69
    	 0.05895090103149414
    rule 70
    	 0.05468010902404785
    rule 71
    	 0.010773181915283203
    rule 72
    	 0.008522987365722656
    rule 73
    	 0.2297210693359375
    rule 74
    	 0.06133317947387695
    rule 75
    	 31.90888786315918
    rule 76
    	 0.008646249771118164
    rule 77
    	 0.029652833938598633
    rule 78
    	 0.05922889709472656
    rule 79
    	 0.05463671684265137
    rule 80
    	 0.06371021270751953
    rule 81
    	 0.09065103530883789
    rule 82
    	 0.9790999889373779
    rule 83
    	 0.11075472831726074
    rule 84
    	 0.06128096580505371
    rule 85
    	 0.12448692321777344
    rule 86
    	 26.123712062835693
    rule 87
    	 0.012782096862792969
    rule 88
    	 0.05713701248168945
    rule 89
    	 30.4510018825531
    rule 90
    	 4.750530004501343
    rule 91
    	 0.015636920928955078
    rule 92
    	 0.06093168258666992
    rule 93
    	 0.06131482124328613
    rule 94
    	 0.03467392921447754
    rule 95
    	 0.011383056640625
    rule 96
    	 0.008281230926513672
    rule 97
    	 0.16131186485290527
    rule 98
    	 0.06476068496704102
    rule 99
    	 0.09926390647888184
    rule 100
    	 0.010210990905761719
    rule 101
    	 29.457420825958252
    rule 102
    	 8.820180892944336
    rule 103
    	 0.11405014991760254
    rule 104
    	 0.007352113723754883
    rule 105
    	 6.224099159240723
    rule 106
    	 0.11618804931640625
    rule 107
    	 0.3177459239959717
    rule 108
    	 0.0222320556640625
    rule 109
    	 0.23206615447998047
    rule 110
    	 1.3274178504943848
    rule 111
    	 0.10014700889587402
    rule 112
    	 0.062280893325805664
    rule 113
    	 0.11414384841918945
    rule 114
    	 0.07397580146789551
    rule 115
    	 0.11969828605651855
    rule 116
    	 0.06546783447265625
    rule 117
    	 0.092742919921875
    rule 118
    	 0.0684971809387207
    rule 119
    	 0.010839223861694336
    rule 120
    	 0.07424807548522949
    rule 121
    	 0.17499327659606934
    rule 122
    	 0.40232205390930176
    rule 123
    	 0.01334381103515625
    rule 124
    	 1.1915581226348877
    rule 125
    	 0.10111403465270996
    rule 126
    	 0.742887020111084
    rule 127
    	 0.013633012771606445
    rule 128
    	 0.011010169982910156
    rule 129
    	 0.7216980457305908
    rule 130
    	 0.07665300369262695
    rule 131
    	 0.08456707000732422
    rule 132
    	 0.008452177047729492
    rule 133
    	 0.05306386947631836
    rule 134
    	 0.09484601020812988
    rule 135
    	 26.81414794921875
    rule 136
    	 0.00937199592590332
    rule 137
    	 1.0686559677124023
    rule 138
    	 0.0604400634765625
    rule 139
    	 0.05618906021118164
    rule 140
    	 0.007270097732543945
    rule 141
    	 0.052774906158447266
    rule 142
    	 0.06703519821166992
    rule 143
    	 0.06638312339782715
    rule 144
    	 0.05845022201538086
    rule 145
    	 0.07192397117614746
    rule 146
    	 0.6040017604827881
    rule 147
    	 0.0495760440826416
    rule 148
    	 0.09687376022338867
    rule 149
    	 28.464774131774902
    rule 150
    	 5.020642042160034
    rule 151
    	 0.008892059326171875
    rule 152
    	 0.06734585762023926
    rule 153
    	 9.347355127334595
    rule 154
    	 1.0050771236419678
    rule 155
    	 0.08692622184753418
    rule 156
    	 0.06453824043273926
    rule 157
    	 0.07854413986206055
    rule 158
    	 0.11428189277648926
    rule 159
    	 0.009076118469238281
    rule 160
    	 0.008481979370117188
    rule 161
    	 0.7498009204864502
    rule 162
    	 0.05953097343444824
    rule 163
    	 0.08424711227416992
    rule 164
    	 0.0076100826263427734
    rule 165
    	 4.555773973464966
    rule 166
    	 0.10415410995483398
    rule 167
    	 1.0875978469848633
    rule 168
    	 0.008850812911987305
    rule 169
    	 22.293861865997314
    rule 170
    	 0.06535601615905762
    rule 171
    	 0.060491085052490234
    rule 172
    	 0.008649110794067383
    rule 173
    	 0.05925178527832031
    rule 174
    	 0.06543493270874023
    rule 175
    	 0.05765032768249512
    rule 176
    	 0.06086015701293945
    rule 177
    	 0.08470869064331055
    rule 178
    	 0.043411970138549805
    rule 179
    	 0.03549790382385254
    rule 180
    	 0.09203505516052246
    rule 181
    	 0.9599258899688721
    rule 182
    	 0.6476240158081055
    rule 183
    	 0.00801396369934082
    rule 184
    	 0.06304502487182617
    rule 185
    	 0.06536316871643066
    rule 186
    	 0.058175086975097656
    rule 187
    	 0.06926488876342773
    rule 188
    	 0.1292402744293213
    rule 189
    	 0.062432050704956055
    rule 190
    	 0.07839202880859375
    rule 191
    	 0.012982845306396484
    rule 192
    	 0.00967097282409668
    rule 193
    	 1.0988030433654785
    rule 194
    	 0.06521081924438477
    rule 195
    	 9.893154859542847
    rule 196
    	 0.008414983749389648
    rule 197
    	 0.05427098274230957
    rule 198
    	 0.05717802047729492
    rule 199
    	 0.055357933044433594
    rule 200
    	 0.0076580047607421875
    rule 201
    	 0.012023210525512695
    rule 202
    	 0.06798315048217773
    rule 203
    	 0.01167607307434082
    rule 204
    	 0.0077970027923583984
    rule 205
    	 0.008475065231323242
    rule 206
    	 0.05967307090759277
    rule 207
    	 0.008154869079589844
    rule 208
    	 0.06399059295654297
    rule 209
    	 0.06505799293518066
    rule 210
    	 1.040682315826416
    rule 211
    	 0.08469080924987793
    rule 212
    	 0.061270713806152344
    rule 213
    	 0.07012605667114258
    rule 214
    	 0.1096339225769043
    rule 215
    	 0.01001286506652832
    rule 216
    	 0.06030988693237305
    rule 217
    	 0.009869813919067383
    rule 218
    	 0.29715800285339355
    rule 219
    	 0.013760089874267578
    rule 220
    	 0.058279991149902344
    rule 221
    	 0.010712146759033203
    rule 222
    	 0.03295779228210449
    rule 223
    	 0.01018214225769043
    rule 224
    	 0.00860595703125
    rule 225
    	 19.760647296905518
    rule 226
    	 0.06753420829772949
    rule 227
    	 0.07141613960266113
    rule 228
    	 0.009190082550048828
    rule 229
    	 0.06753706932067871
    rule 230
    	 0.12091898918151855
    rule 231
    	 0.059455156326293945
    rule 232
    	 0.00868082046508789
    rule 233
    	 0.016736984252929688
    rule 234
    	 0.07507705688476562
    rule 235
    	 0.015402078628540039
    rule 236
    	 0.010314226150512695
    rule 237
    	 0.011841058731079102
    rule 238
    	 0.0683908462524414
    rule 239
    	 0.012744903564453125
    rule 240
    	 0.06637382507324219
    rule 241
    	 0.06178689002990723
    rule 242
    	 0.060775041580200195
    rule 243
    	 0.06935501098632812
    rule 244
    	 0.07609987258911133
    rule 245
    	 0.11420083045959473
    rule 246
    	 0.09661698341369629
    rule 247
    	 0.009140968322753906
    rule 248
    	 0.08502388000488281
    rule 249
    	 0.013747930526733398
    rule 250
    	 0.05302023887634277
    rule 251
    	 0.012362957000732422
    rule 252
    	 0.07380986213684082
    rule 253
    	 0.011536121368408203
    rule 254
    	 0.03669404983520508
    rule 255
    	 0.008320093154907227
    rule75 took 31.90888786315918
    rule89 took 30.4510018825531
    rule45 took 29.741049766540527
    rule101 took 29.457420825958252
    rule149 took 28.464774131774902
    rule135 took 26.81414794921875
    rule30 took 26.5013108253479
    rule86 took 26.123712062835693
    rule169 took 22.293861865997314
    rule225 took 19.760647296905518
    rule195 took 9.893154859542847
    rule153 took 9.347355127334595
    rule102 took 8.820180892944336
    rule60 took 8.379151105880737
    rule105 took 6.224099159240723
    rule150 took 5.020642042160034
    rule90 took 4.750530004501343
    rule165 took 4.555773973464966
    rule110 took 1.3274178504943848
    rule124 took 1.1915581226348877



    <Figure size 640x480 with 0 Axes>



```python
time_only = [x[0] for x in execution_time]
plt.hist(time_only)
plt.title("histogram")
plt.show()
```



{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_11_0.png" class="img-fluid rounded " %}



For the great majority of rules the PRT is almost constant up to size 50, so let's just investigate the rules for which $$PRT > 20$$. Those would be
- rule75
- rule89
- rule45
- rule101
- rule149
- rule135
- rule30
- rule86
- rule169
- rule225
- rule195

Let's plot them


```python
width = 100
fig, axes = plt.subplots(5, 2, figsize=(width, 2.5*width))
rules = [75, 89, 45, 101, 149, 135, 30, 86, 169, 225, 195]
for ax, rule in zip(axes.flat, rules):
    x, _ = generate(rule, size=3*width, steps=3*width)
    ax.set_axis_off()
    ax.imshow(x, interpolation='none', cmap=plt.cm.binary)
    ax.set_title(f"{rule} - {bin(rule)}", fontdict = {'fontsize':70})
```



{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_13_0.png" class="img-fluid rounded " %}



Interestingly enough each pair can be considered as a single rule as the rules in each pair are simmetrical. While the first 8 rules have a similar behavior, showing a clear pattern, the last two rules are very different from the other. Let's run them for a while and see if there is a pattern there.


```python
#rule60 took 8.85617208480835
#rule195 took 8.831139087677002
#rule102 took 8.81187391281128
#rule153 took 8.585221767425537

#rule105 took 5.552289962768555
#rule150 took 4.471593856811523
#rule165 took 4.46081280708313
#rule90 took 4.451854705810547

rule = 169
size = 200
steps = 40000
data, _ = generate(rule, size, steps, test_recurrence=True, exit_on_recurrence=False)
```


```python
parts = make_columns(data, 20, spacing=4)
plot_run(parts)
```



{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_16_0.png" class="img-fluid rounded " zoomable=true %}




```python
rule = 110
size = 200
steps = 10000
data110, rec_indices = generate(rule, size, steps, test_recurrence=True, exit_on_recurrence=False)
print(rec_indices)
parts = make_columns(data110, 10, spacing=10)
plot_run(parts)
```

    (-1, -1)




{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_17_1.png" class="img-fluid rounded " zoomable=true %}




```python
rule = 122
size = 300
steps = 200_000
start = np.zeros(size)
start[45:55] = 1
data122, _ = generate(rule, size, steps, test_recurrence=True, exit_on_recurrence=False, with_init=start)
```


```python
parts = make_columns(data122, 25, spacing=10)
plot_run(parts)
```




{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_19_0.png" class="img-fluid rounded " zoomable=true %}


```python
rule = 122
size = 100
steps = 20_00
start = np.zeros(size)
start[45:55] = 1
data122_closeup, _ = generate(rule, size, steps, with_init=start)
cols = make_columns(data122_closeup, 5, spacing=10)
plot_run(cols)
```



{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_21_0.png" class="img-fluid rounded " zoomable=true %}




```python
plot_run(data122_closeup[:100])
```



{% include figure.html path="assets/img/blog/2022-10-27/poincare-recurrence-time_22_0.png" class="img-fluid rounded " zoomable=true %}


