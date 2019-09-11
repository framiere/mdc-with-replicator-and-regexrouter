#!/bin/bash

docker-compose up -d

# Verify Kafka Connect europe has started within MAX_WAIT seconds
MAX_WAIT=120
CUR_WAIT=0
echo "Waiting up to $MAX_WAIT seconds for Kafka Connect to start"
while [[ ! $(docker-compose logs connect-europe) =~ "Finished starting connectors and tasks" ]]; do
  sleep 10
  CUR_WAIT=$(( CUR_WAIT+10 ))
  if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
    echo -e "\nERROR: The logs in connect-europe container do not show 'Finished starting connectors and tasks' after $MAX_WAIT seconds. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
    exit 1
  fi
done
echo "Connect europe has started!"

# Verify Kafka Connect us has started within MAX_WAIT seconds
MAX_WAIT=120
CUR_WAIT=0
echo "Waiting up to $MAX_WAIT seconds for Kafka Connect to start"
while [[ ! $(docker-compose logs connect-us) =~ "Finished starting connectors and tasks" ]]; do
  sleep 10
  CUR_WAIT=$(( CUR_WAIT+10 ))
  if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
    echo -e "\nERROR: The logs in connect-us container do not show 'Finished starting connectors and tasks' after $MAX_WAIT seconds. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
    exit 1
  fi
done
echo "Connect us has started!"

# Verify Confluent Control Center has started within MAX_WAIT seconds
MAX_WAIT=300
CUR_WAIT=0
echo "Waiting up to $MAX_WAIT seconds for Confluent Control Center to start"
while [[ ! $(docker-compose logs control-center) =~ "Started NetworkTrafficServerConnector" ]]; do
  sleep 10
  CUR_WAIT=$(( CUR_WAIT+10 ))
  if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
    echo -e "\nERROR: The logs in control-center container do not show 'Started NetworkTrafficServerConnector' after $MAX_WAIT seconds. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
    exit 1
  fi
done
echo "Control Center has started!"

seq -f "european_sale_%g ${RANDOM}" 10 | docker container exec -i broker-europe kafka-console-producer --broker-list localhost:9092 --topic EUROPE_sales

seq -f "us_sale_%g ${RANDOM}" 10 | docker container exec -i broker-us kafka-console-producer --broker-list localhost:9092 --topic US_sales


echo Consolidating all sales in the US

docker-compose exec connect-us \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-europe-to-us-with-regex-router",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-europe-to-us-with-regex-router",
          "src.kafka.bootstrap.servers": "broker-europe:9092",
          "dest.kafka.bootstrap.servers": "broker-us:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.whitelist": "EUROPE_sales",
          "transforms": "dropPrefix",
          "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter",
          "transforms.dropPrefix.regex": "EUROPE_(.*)",
          "transforms.dropPrefix.replacement": "$1"
          }}' \
     http://localhost:8083/connectors | jq .

docker-compose exec connect-us \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-us-to-us-with-regex-router",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-us-to-us-with-regex-router",
          "src.kafka.bootstrap.servers": "broker-us:9092",
          "dest.kafka.bootstrap.servers": "broker-us:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.whitelist": "US_sales",
          "transforms": "dropPrefix",
          "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter",
          "transforms.dropPrefix.regex": "US_(.*)",
          "transforms.dropPrefix.replacement": "$1"
          }}' \
     http://localhost:8083/connectors | jq .

echo Consolidating all sales in Europe

docker-compose exec connect-europe \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-us-to-europe-with-regex-router",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-us-with-regex-router",
          "src.kafka.bootstrap.servers": "broker-us:9092",
          "dest.kafka.bootstrap.servers": "broker-europe:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.whitelist": "US_sales",
          "transforms": "dropPrefix",
          "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter",
          "transforms.dropPrefix.regex": "US_(.*)",
          "transforms.dropPrefix.replacement": "$1"
          }}' \
     http://localhost:8083/connectors | jq .

docker-compose exec connect-europe \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-europe-to-europe-with-regex-router",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-europe-to-europe-with-regex-router",
          "src.kafka.bootstrap.servers": "broker-europe:9092",
          "dest.kafka.bootstrap.servers": "broker-europe:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.whitelist": "EUROPE_sales",
          "transforms": "dropPrefix", 
          "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter",
          "transforms.dropPrefix.regex": "EUROPE_(.*)",
          "transforms.dropPrefix.replacement": "$1"
          }}' \
     http://localhost:8083/connectors | jq .



echo "Verify we have received the data in the sales topic in EUROPE"
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --topic sales --from-beginning --max-messages 20

echo "Verify we have received the data in the sales topic in the US"
docker-compose exec broker-us kafka-console-consumer --bootstrap-server broker-us:9092 --topic sales --from-beginning --max-messages 20

echo "That will not work, but let's verify"
echo "Let's change EUROPE_sales partitions"
docker-compose exec connect-europe kafka-topics --bootstrap-server broker-europe:9092 --topic EUROPE_sales --alter --partitions 2

echo "Resend data to the EUROPE_sales topic"
seq -f "after addind partitions in european sale %g ${RANDOM}" 10 | docker container exec -i broker-europe kafka-console-producer --broker-list localhost:9092 --topic EUROPE_sales

echo "Verify it is now in sales topic in EUROPE"
echo "We are waiting for 30 elements, but there's only 25"
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --topic sales --from-beginning --max-messages 30

echo "Verify it is now in sales topic in the US"
echo "We are waiting for 30 elements, but there's only 25"
docker-compose exec broker-us kafka-console-consumer --bootstrap-server broker-us:9092 --topic sales --from-beginning --max-messages 30


