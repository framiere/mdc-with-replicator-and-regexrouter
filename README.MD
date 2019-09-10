# ReplicatorSourceConnector

Both Europe and US have sales topics, here are how they are defined:

* in Europe: `EUROPE_sales`
* in US: `US_sales`

We want on both continents to have ALL sales in the `sales` topic

Let's use replicator for that. https://docs.confluent.io/current/connect/kafka-connect-replicator

But we can't use `topic.rename.format` --> https://docs.confluent.io/current/connect/kafka-connect-replicator/configuration_options.html#destination-topics

Why can't we use the `RegexRouter` SMT ? https://docs.confluent.io/current/connect/transforms/regexrouter.html#regexrouter

... because Replicator is NOT handling topic configuration during the `poll()`.

This project is a demonstration.