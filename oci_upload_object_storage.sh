#!/bin/ksh
##########################################
# upload + retry if failed
##########################################

if [ -z "$1" ]; then
    echo ""
    echo "Error, File name not specified. !!!"
    echo ""
    echo "$0 Bucket FileName ObjectName "
    echo ""
    exit 1
fi

export BUCKET=$1
export FILENAME=$2
export OBJECTNAME=$3

export PARALLEL_UPLOAD=8
export PART_SIZE=1000

####################
# Initiate Upload 
####################
oci os object put --file $FILENAME --name $OBJECTNAME -bn $BUCKET --part-size $PART_SIZE --parallel-upload-count $PARALLEL_UPLOAD
RET=$?

while [[ $RET -ne 0 ]] 
do
    ##############################################
    # Get Upload Id for the object sort descend
    ##############################################
    if [[ $UPLOAD_ID = "" ]] 
    then
        echo -n "Getting upload ID: "
        UPLOAD_ID=$(oci os multipart list --all -bn shared --query='reverse(sort_by(data, &"time-created")[*].{time:"time-created",id:"upload-id",object:object})' --output=table |grep ${OBJECTNAME} |head -1 | awk '{ print $2 }')
        echo "$UPLOAD_ID"
    fi
    if [[ $UPLOAD_ID = "" ]] 
    then
        echo "Unable to find upload-id, exiting."
        exit
    fi
    ##############################################
    # Resume Put
    ##############################################
    echo ""
    echo "Resume-Put using $UPLOAD_ID at `date`"
    oci os object resume-put --file $FILENAME --name $OBJECTNAME -bn $BUCKET --upload-id $UPLOAD_ID --part-size $PART_SIZE --parallel-upload-count $PARALLEL_UPLOAD
    RET=$?
done