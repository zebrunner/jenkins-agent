#!/bin/bash
set -xe
docker run -it --rm -v $PWD:/data android_container:qps bash -c "chmod +x /data/build_qps_sample_android.sh && sh /data/build_qps_sample_android.sh"
