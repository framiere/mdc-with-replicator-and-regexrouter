# MDC

We have 2 regions, US and EUROPE, both have local `sales` topic.
We want to have a consolidated view of ALL sales in each region.

# Replicator

![Replicator setup](replicator.png "Replicator can rename topics")

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

## The simples way is the following

![Simplest replicator setup](simplest.png "Replicator")

This setup is executable in `simplest.sh`

The main point is that you can subscribe to a wild card topics

```sh
docker-compose exec broker-europe kafka-console-consumer --bootstrap-server broker-europe:9092 --whitelist "sales_.*" --from-beginning --max-messages 20 --property metadata.max.age.ms 30000
```

It does simplify everything as there is

* less data traveling around
* less connectors
* simpler reasoning
* simples monitoring
* native
* simpler ACL management
* ...