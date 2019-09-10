#!/bin/bash

# docker-compose up -d

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


seq -f "sale_%g" 100 | docker container exec -i broker-europe kafka-console-producer --broker-list localhost:9091 --topic EUROPE_sales
seq -f "sale_%g" 100 | docker container exec -i broker-us kafka-console-producer --broker-list localhost:9092 --topic US_sales


docker-compose exec connect-us \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-europe-to-us",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-europe-to-us",
          "src.kafka.bootstrap.servers": "broker-europe:9091",
          "dest.kafka.bootstrap.servers": "broker-us:9092",
          "confluent.topic.replication.factor": 1,
          "topic.whitelist": "EUROPE_sales",
          "topic.poll.interval.ms": 10000,
          "tasks.max": 5}}' \
     http://localhost:8382/connectors

docker-compose exec connect-us curl http://localhost:8382/connectors/replicate-europe-to-us/status | jq .