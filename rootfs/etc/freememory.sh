#!/bin/sh -e
   
if sync; then
   echo "sync data between memory cache to file successfully.."
   if echo 3 > /proc/sys/vm/drop_caches; then
   	echo "clear pagecach, dentries, inodes from memory cache successfully.."
   else
       echo "memory cache clear failed!!"
   fi
fi
sync
