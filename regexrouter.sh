#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/reset-cluster.sh

echo "Sending sales in Europe cluster"
seq -f "european_sale_%g ${RANDOM}" 10 | docker container exec -i broker-europe kafka-console-producer --broker-list localhost:9092 --topic EUROPE_sales

echo "Sending sales in US cluster"
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


