#!/bin/bash
convert_dir=$PWD
dontaskagain=false
for f in *; do if [[ $f = *" "* ]];then mv "$f" "${f// /_}"; fi; done
for f in *.mp4 *.avi *.mkv *.m4v; do
    file="$f"
    basename="$(basename "${file%.*}")"
    output_dir=/var/www/html/movies/$basename
    file_vcodec="$(ffprobe -i $file -show_entries stream=codec_name -select_streams v:0 -of compact=p=0:nk=1 -v 0)"
    file_vprofile="$(ffprobe -i $file -show_entries stream=profile -select_streams v:0 -of compact=p=0:nk=1 -v 0)"
    file_acodec="$(ffprobe -i $file -show_entries stream=codec_name -select_streams a:0 -of compact=p=0:nk=1 -v 0)"
    file_achannel="$(ffprobe -i $file -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0)"
    ff_vcodec="copy"
    ff_acodec="copy"
    ff_ac=""
    ff_profile=""
    echo "FILE is: $file"
    echo "File acodec        : $file_acodec"
    if [[ $file_acodec != "aac" ]]; then ff_acodec="aac"; ff_ac="-ac 6"; fi
    echo "File vcodec        : $file_vcodec"
    if [[ $file_vcodec != "h264" ]]; then ff_vcodec="libx264"; fi
    echo "File video profile : $file_vprofile"
    if [ "$file_vprofile" = "High 10" ] || [ "$file_vprofile" = "Main 10" ]; then ff_vcodec="libx264"; ff_profile="-profile:v high -pix_fmt yuv420p"; fi
    echo "File achannel      : $file_achannel"
    if [[ $file_achannel == "6" ]]; then ff_acodec="aac"; ff_ac="-ac 6"; fi
    echo "File directory     : $output_dir"
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
        -metadata Title="$basename" \
        -map_chapters -1 \
        -c:v $ff_vcodec \
        $ff_profile \
        -c:a $ff_acodec \
        $ff_ac \
        -vol 256 \
        "$basename".mp4
    echo "creating hls"
    ffmpeg -i "$basename".mp4 \
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
