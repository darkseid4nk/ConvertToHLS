#!/bin/bash

# -c:v libx264 -profile:v high -pix_fmt yuv420p -c:a aac -ac 6 -vol 256

convert_dir=$PWD
self=${0##*/}
dontaskagain=false

for f in *\ *; do mv "$f" "${f// /_}"; done

for i in *.*; do
    file="$i"
    echo "FILE is: $file"
    file_vstream="$(ffprobe -i $file 2>&1 >/dev/null | grep Stream.*Video)"
    file_vcodec="$(echo $file_vstream | awk '{ print $4 }')"
    file_highten=""
    file_highten="$(echo $file_vstream | grep -e 'High 10' -e 'Main 10')"
    file_astream="$(ffprobe -i $file 2>&1 >/dev/null | grep Stream.*Audio)"
    file_acodec="$(echo $file_astream | awk '{ print $4 }')"
    file_achannel="$(echo $file_astream | awk '{ print $11 }' | tr -d ,)"
    ff_vcodec="copy"
    ff_acodec="copy"
    ff_ac=""
    ff_profile=""

    if [[ $file == $self ]]; then
        echo "self detected. moving to next"
        continue
    fi

    echo "File acodec   : $file_acodec"
    if [[ $file_acodec != "aac" ]]; then
        ff_acodec="aac"
    fi

    echo "File vcodec   : $file_vcodec"
    if [[ $file_vcodec != "h264" ]]; then
        ff_vcodec="libx264"
    fi

    echo "File highten? : $file_highten"
    if [ -n "${file_highten}" ]; then
        ff_vcodec="libx264"
        ff_profile="-profile:v high -pix_fmt yuv420p"
    fi

    echo "File achannel : $file_achannel"
    if [[ $file_achannel == "6" ]]; then
        ff_acodec="aac"
        ff_ac="-ac 6"
    fi

    basename="$(basename "${file%.*}")"
    output_dir=/var/www/html/movies/$basename

    echo "File directory: $output_dir"
    echo "FFMPEG MP4 cmd: ffmpeg -i $file -y -v warning -hide_banner -stats -c:v $ff_vcodec $ff_profile -c:a $ff_acodec $ff_ac -vol 256 $basename.mp4"
    echo "FFMPEG HLS cmd: ffmpeg -i $file -y -v warning -hide_banner -stats -codec: copy -hls_time 10 -hls_list_size 0 -f hls $basename.m3u8"

    if [ "$dontaskagain" == false ]; then
        read -p "Do you want to proceed? default Y, n moves to next in queue (Yy/Nn/Aa/exit) " yn
        case $yn in
            [yY] ) echo "proceeding...";
                ;;
            [nN] ) echo "moving on...";
                continue;;
            "exit" ) exit 1
                ;;
            [aA] ) dontaskagain=true
                echo "proceeding...";
                ;;
            * ) echo "proceeding...";;
        esac
    fi

    echo "make temp dir"
    md5sum="$(md5sum $file | cut -b-32)"
    mkdir -p /tmp/$md5sum/$basename
    echo "copying file to temp dir"
    cp $file /tmp/$md5sum
    echo "changing pwd to temp dir"
    cd /tmp/$md5sum/$basename
    echo "creating mp4"
    ffmpeg -i /tmp/$md5sum/"$file" \
        -y \
        -v warning -hide_banner -stats \
        -c:v $ff_vcodec \
        $ff_profile \
        -c:a $ff_acodec \
        $ff_ac \
        -vol 256 \
        "$basename".mp4
    echo "creating hls"
    ffmpeg -i "$file" \
        -y \
        -v warning -hide_banner -stats \
        -codec: copy \
        -hls_time 10 \
        -hls_list_size 0 \
        -f hls \
        "$basename".m3u8
    echo "making output dir"
    [ -d "$output_dir" ] || mkdir $output_dir
    echo "moving to output dir"
    cd $output_dir
    echo "cleaning output dir"
    rm * 2> /dev/null
    echo "moving files to output dir"
    mv /tmp/$md5sum/$basename/*.mp4 ./
    mv /tmp/$md5sum/$basename/*.ts ./
    mv /tmp/$md5sum/$basename/*.m3u8 ./
    echo "cleaning temp dir"
    rm -rf /tmp/$md5sum
    echo "setting permissions"
    chown --recursive www-data:www-data $output_dir
    echo "changing to convert dir"
    cd $convert_dir
    echo "remove movie from convert dir"
    rm $file
    echo "COMPLETE!"
    echo "-------------------------------------------------"
done
echo "All tasks conplete"
