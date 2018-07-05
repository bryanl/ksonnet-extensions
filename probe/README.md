# probe

Create probes for Kubernetes workload objects

## Summary

This module allow you to create readiness and liveness probes for Kubernetes workloads. There are handlers for the default actions:

### exec action

```js
local commands = ['cat', '/tmp/health'];
probe.handlers.exec(commands)
```

Notes:

* commands is a string or an array of strings: e.g `['cat', '/tmp/healthy']`

### HTTP get action

```js
local headers = {
    "X-Custom-Header": "Value",
};
local path = "/";
local port = 80;
local scheme = "https";

probe.handlers.httpGet(headers=headers, path=path, port=port, scheme=scheme);
```

Notes:

* Kubernetes supports a host parameter, but advises users to use `Host` header.

### TCP socket action

```js
local host = "foo.bar";
local port = 80;

probe.handlers.tcpSocket(host=host, port=port);
```

Notes:

* host is optional

## Examples

### Create liveness probe

Assuming you have an object created stored in a variable named `workload`:

```js
local workload = {};
local probe = import 'probe.libsonnet';

// add a liveness probem to a container named nginx
probe.liveness(workload, "nginx", probe.handlers.httpGet(port=80));
```

### Create readiness probe

Assuming you have an object created stored in a variable named `workload`:

```js
local workload = {};
local probe = import 'probe.libsonnet';

// add a liveness probem to a container named nginx
probe.readiness(workload, "nginx", probe.handlers.httpGet(port=80));
```


### Adding multiple probes to a workload

```js
local workload = {};
local probe = import 'probe.libsonnet';

local probes = [
    probe.config("livenessProbe", "nginx", probe.handlers.tcpSocket(port=3306)),
    probe.config("readinessProbe", "nginx2", probe.handlers.httpGet(port=80)),
    probe.config("readinessProbe", "nginx", probe.handlers.exec(['cat', '/tmp/healthy'])),
];


// add multiple probes to workload
probe.add(workload, probes)
```
