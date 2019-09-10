# ReplicatorSourceConnector

Both Europe and US have sales topics, here are how they are defined:

* in Europe: `EUROPE_sales`
* in US: `US_sales`

We want on both continents to have ALL sales in the `sales` topic

If you are using `regexrouter` you will need to specify `topic.config.sync=false`.