#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/reset-cluster.sh

echo "Sending sales in Europe cluster"
seq -f "european_sale_%g ${RANDOM}" 10 | docker container exec -i broker-europe kafka-console-producer --broker-list localhost:9092 --topic sales_EUROPE

echo "Sending sales in US cluster"
seq -f "us_sale_%g ${RANDOM}" 10 | docker container exec -i broker-us kafka-console-producer --broker-list localhost:9092 --topic sales_US

echo Consolidating all sales in the US

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
          "src.kafka.bootstrap.servers": "broker-europe:9092",
          "dest.kafka.bootstrap.servers": "broker-us:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.whitelist": "sales_EUROPE"
          }}' \
     http://localhost:8083/connectors | jq .

docker-compose exec connect-us \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicator-merge-all-sales",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicator-merge-all-sales",
          "src.kafka.bootstrap.servers": "broker-us:9092",
          "dest.kafka.bootstrap.servers": "broker-us:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.regex": "sales_.*",
          "topic.poll.interval.ms": 5000,
          "topic.rename.format": "sales"
          }}' \
     http://localhost:8083/connectors | jq .


echo Consolidating all sales in Europe

docker-compose exec connect-europe \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicate-us-to-europe",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicate-us",
          "src.kafka.bootstrap.servers": "broker-us:9092",
          "dest.kafka.bootstrap.servers": "broker-europe:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.whitelist": "sales_US"
          }}' \
     http://localhost:8083/connectors | jq .

docker-compose exec connect-europe \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "replicator-merge-all-sales",
        "config": {
          "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "src.consumer.group.id": "replicator-merge-all-sales",
          "src.kafka.bootstrap.servers": "broker-europe:9092",
          "dest.kafka.bootstrap.servers": "broker-europe:9092",
          "confluent.topic.replication.factor": 1,
          "provenance.header.enable": true,
          "topic.config.sync": false,
          "topic.auto.create": false,
          "topic.preserve.partitions": false,
          "topic.regex": "sales_.*",
          "topic.poll.interval.ms": 5000,
          "topic.rename.format": "sales"
          }}' \
     http://localhost:8083/connectors | jq .


echo "Verify we have received the data in all the sales_ topics in EUROPE"
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --whitelist "sales_.*" --from-beginning --max-messages 20 --property metadata.max.age.ms 30000

echo "Verify we have received the data in all the sales_ topics in the US"
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --whitelist "sales_.*" --from-beginning --max-messages 20 --property metadata.max.age.ms 30000

echo "Verify we have received the data in merged sales topic in EUROPE"
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --topic sales --from-beginning --max-messages 20

echo "Verify we have received the data in merged sales topic in the US"
docker-compose exec broker-us kafka-console-consumer --bootstrap-server broker-us:9092 --topic sales --from-beginning --max-messages 20
