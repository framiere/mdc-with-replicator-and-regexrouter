# MDC and single views

* [Objective](#Objective)
* [Replicator](#Replicator)
    * [Using rename-format](#Using-rename-format)
    * [Using RegexRouter](#Using-RegexRouter)
    * [Using the default mode](#Using-the-default-mode)

## Objective

We have 2 regions: `US` and `EUROPE` each have a topic with sales that happened regionaly.
We want on each region to have a way to see **all** sales in **all** regions.

# Replicator

![Replicator setup](replicator.png "Replicator can rename topics")

Why is it that we need to set `topic.config.sync=false` ?

In this example, if `EUROPE_sales` and `US_sales` do not share the same setup... what would be `sales` topic like ?
It's now up to you to sync these, and not replicator.
If you want no have this problem, just use Replicator in its default mode :)

## Using `rename-format`

https://docs.confluent.io/current/connect/kafka-connect-replicator/configuration_options.html#destination-topics

This setup is executable in `rename-format.sh`

## Using `RegexRouter`

https://docs.confluent.io/current/connect/transforms/regexrouter.html

you will need to specify:

* `topic.config.sync=false`
* `topic.auto.create=false`
* `topic.preserve.partitions=false`

This setup is executable in `regexrouter.sh`

## Using the default mode

![Simplest replicator setup](simplest.png "Replicator")

This setup is executable in `simplest.sh`

The main point is that you can subscribe to a list of topics or to a regex.

It's native to the consumer protocol
https://docs.confluent.io/current/clients/javadocs/org/apache/kafka/clients/consumer/KafkaConsumer.html#subscribe-java.util.regex.Pattern-

It is also there to be leveraged in the `kafka-console-consumer`

```sh
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --whitelist "sales_.*" --from-beginning --max-messages 20 --property metadata.max.age.ms 30000
```

### Why specifying `metadata.max.age.ms` ?


We specify `metadata.max.age.ms 30000` (30s) because the default is 5 minutes, we want new topics to be discovered faster.

### Why using this method ?

It does simplify everything as there is

* no duplication
* simpler reasoning
* simpler monitoring
* simpler ACL management
* less data traveling around
* less connectors
* native
* ...
