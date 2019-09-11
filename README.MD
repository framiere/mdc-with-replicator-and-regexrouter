# ReplicatorSourceConnector

Both Europe and US have sales topics, here are how they are defined:

* in Europe: `EUROPE_sales`
* in US: `US_sales`

We want on both continents to have ALL sales in the `sales` topic

If you are using [`RegexRouter`](https://docs.confluent.io/current/connect/transforms/regexrouter.html) you will need to specify:

* `topic.config.sync=false`
* `topic.auto.create=false`
* `topic.preserve.partitions=false`
* § https://docs.confluent.io/current/connect/kafka-connect-replicator/configuration_options.html#destination-topics
