#!/bin/bash

# Exit on any error
set -e

# --- Configuration ---
# IPs must be provided as arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <master-private-ip> <edge-node-private-ip>"
    exit 1
fi
MASTER_IP=$1
EDGE_NODE_IP=$2

# S3 Bucket and JAR file location
S3_BUCKET="s3a://usth-spark-project-data-tung-20251121"
JAR_FILE="spark-wordcount-1.0.jar"

# Files to test
  TEST_FILES=("1MB_file.txt" "10MB_file.txt" "20MB_file.txt" "40MB_file.txt" "80MB_file.txt")
# --- End Configuration ---


echo "--- Starting Spark Benchmark ---"
echo "Master IP: $MASTER_IP"
echo "Edge Node IP: $EDGE_NODE_IP"
echo "--------------------------------"

# Loop through each test file and run the Spark job
for FILE in "${TEST_FILES[@]}"; do
    INPUT_PATH="$S3_BUCKET/$FILE"
    OUTPUT_PATH="$S3_BUCKET/output-$FILE-$(date +%s)" # Unique output path

    echo ""
    echo ">>> Running WordCount for: $FILE"

    spark-submit \
      --packages org.apache.hadoop:hadoop-aws:3.3.4 \
      --class WordCount \
      --master spark://$MASTER_IP:7077 \
      --conf spark.driver.host=$EDGE_NODE_IP \
      --conf spark.driver.cores=1 \
      --conf spark.driver.memory=512m \
      --conf spark.executor.cores=1 \
      --conf spark.executor.memory=1024m \
      --conf spark.cores.max=4 \
      --conf spark.eventLog.enabled=false \
      $JAR_FILE \
      $INPUT_PATH \
      $OUTPUT_PATH

    echo ">>> Finished WordCount for: $FILE"
    echo "--------------------------------"
done

echo "--- Benchmark Complete ---"