#!/bin/ksh
##########################################
# Object Storage Upload + Retry
# Date - 04/10/2021
##########################################

export PARALLEL_UPLOAD=8
export PART_SIZE=1000
export REGION=""
export REGION_FLAG=""

###################
# Print Usage
###################
usage()
{
    echo "$0 :"
    echo "{"
    echo "     -b bucket"
    echo "     -f file_name"
    echo "     -o object_name"
    echo "     -m parallel upload (Optional Dßefault 8)"
    echo "     -p part size (Optional Default 1000)"
    echo "     -r region (Optional)"
    echo "}"
}

while getopts "b:f:o:m:p:r:" args
do
    case $args in
        b) export BUCKET=$OPTARG
            ;;
        f) export FILENAME=$OPTARG
            ;;
        o) export OBJECTNAME=$OPTARG
            ;;
        m) export PARALLEL_UPLOAD=$OPTARG
            ;;
        m) export PART_SIZE=$OPTARG
            ;;
        r) export REGION_FLAG="--region"
           export REGION=$OPTARG
            ;;
        *) usage
            exit 0
            ;;
    esac
done

if [[ -z "$BUCKET" || -z "$FILENAME" || -z "$OBJECTNAME" ]]
then
    echo ""
    echo "Incomplete arguments supplied"
    echo ""
    usage
    exit 1
fi
####################
# Print Info
####################
echo "###############################################################"
echo "# Uploading to Object started at `date` #"
echo "###############################################################"
echo "Bucket    = $BUCKET"
echo "File      = $FILENAME"
echo "Object    = $OBJECTNAME"
echo "Parallel  = $PARALLEL_UPLOAD"
echo "Part Size = $PART_SIZE (MiB)"
if [[ ! -z "$REGION" ]]; then
    echo "Region    = $REGION"
fi
echo ""

####################
# Initiate Upload 
####################
oci os object put --file $FILENAME --name $OBJECTNAME -bn $BUCKET --part-size $PART_SIZE --parallel-upload-count $PARALLEL_UPLOAD $REGION_FLAG $REGION
RET=$?

while [[ $RET -ne 0 ]] 
do
    ##############################################
    # Get Upload Id for the object sort descend
    ##############################################
    if [[ $UPLOAD_ID = "" ]] 
    then
        echo ""
        echo "Exception Occured"
        echo -n "Getting upload ID: "
        UPLOAD_ID=$(oci os multipart list --all -bn shared \
            --query='reverse(sort_by(data, &"time-created")[*].{time:"time-created",id:"upload-id",object:object})' --output=table | \
            grep ${OBJECTNAME} |head -1 | awk '{ print $2 }')
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
    echo "###########################################################################################"
    echo "# Resume-Put using $UPLOAD_ID at `date`"
    echo "###########################################################################################"
    echo ""
    oci os object resume-put --file $FILENAME --name $OBJECTNAME -bn $BUCKET --upload-id $UPLOAD_ID --part-size $PART_SIZE --parallel-upload-count $PARALLEL_UPLOAD  $REGION_FLAG $REGION
    RET=$?
done