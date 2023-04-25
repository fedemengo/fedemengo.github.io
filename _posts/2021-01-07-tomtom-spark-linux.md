---
layout: post
title:  "TomTom Spark on Linux"
description: "Load audio files using the command line"
tag:
  - unix
---

I use a TomTom Spark 3 to track my sport activities and I love it. The only problem with that is that it's a pretty old watch, TomTom discontinued the sport series so there is not so much support for it anymore.

I have the Cardio + Music version which allows to upload up ~4GB of audio to listen during my workouts. It's great, in theory.

The truth is that I was never able to have the TomTom app upload the audio data to my watch. So, after spending some time trying to figure out the problem I found a solution.

The watch it's just a usb! It's only necessary to mount it

{% include figure.html path="assets/img/blog/2021-01-07/mount.png" class="img-fluid centered" zoomable=false %}

And put the audio files as well as the the `.m3u8` playlist in the folder `MySportsConnect/Music/`

To do that I create a simple script that generates all the playlist. Let's assume you have 3 folders `podcast`, `music`, `lectures` with audio inside each of them. You would just need to run the script at the same level of these folders. The script will create a `masterplaylist.m3u8` at the top level and a `.m3u8` playlist in each folder.

[mp3info](https://ibiblio.org/mp3info/) is require to extract the file duration

{% highlight bash %}
#!/bin/bash

masterPL="masterplaylist.m3u8"
echo "#TTPLAYLIST" > $masterPL

for dir in *;
do
    if [ -d "$dir" ]; then
        name=$(echo $dir | sed -E 's/^(.)/\U\1/g')
        plFile="$dir/$name.m3u8"
        echo "#EXTM3U" > $plFile
        echo "#TTPLAYLIST_NAME:$name" >> $plFile
        for file in "$dir/"*.mp3;
        do
        	echo "#EXTINF:"$(mp3info -p "%S" "$file")","${file/"$dir/"/}""
        	echo ${file/"$dir/"/};
        done >> $plFile

        echo "#NAME:$name" >> $masterPL
        echo "$plFile" >> $masterPL
    fi
done
{% endhighlight %}

Finally you can just copy everything over to `MySportsConnect/Music/`. Beware that the copying process might terminates rather quickly. In my case the umount process took a while, because the files were still syncing.
