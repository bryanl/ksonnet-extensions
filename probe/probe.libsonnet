local k = import "k.libsonnet";

{

    // config creates probe configs
    //
    // * @param type probe type: linessProbe|readinessProbe
    // * @param containerName container name
    // * @param handler handler to apply
    config(type, containerName, handler)::
        if type != 'livenessProbe' && type != 'readinessProbe' then
            error 'probe type is %s. must be livenessProbe or readinessProbe' % type
        else if std.type(containerName) != 'string' then
            error 'container name must be a string'
        else if std.type(handler) != 'function' then
            error 'handler must be a function'
        else
            {
                type: type,
                containerName: containerName,
                handler: handler
            },

    // add adds multiple probes to a workload
    //
    // * @param workload workload to apply probes to
    // * @param probeConfigs array of probe configs. Configs can be created with `config`
    add(workload, probeConfigs)::
        local l = std.length(probeConfigs);

        if std.type(probeConfigs) != 'array' then
            error 'probeConfigs must be an array of probeConfig objects'
        else if l == 0 then
            workload
        else
            local fn(aggregate, config) =
                hidden.probe(config.type, aggregate, config.containerName, config.handler);
            std.foldl(fn, probeConfigs, workload),

    // create liveness probe for a workload
    //
    // * @param workload workload tro apply probe to
    // * @param containerName name of container
    // * @param handler handler to apply
    liveness(workload, containerName, handler)::
        hidden.probe("livenessProbe", workload, containerName, handler),

    // create readiness probe for a workload
    //
    // * @param workload workload tro apply probe to
    // * @param containerName name of container
    // * @param handler handler to apply
    readiness(workload, containerName, handler)::
        hidden.probe("readinessProbe", workload, containerName, handler),

    handlers:: {
        exec(command)::
            function(probeName, container, containerType)
                container + containerType.mixin[probeName].exec.withCommand(command),
        httpGet(headers={}, path="/", port=80, scheme="http")::
            function(probeName, container, containerType)
                local httpGetType = containerType.mixin[probeName].httpGetType;
                local kHeaders = [
                    httpGetType.httpHeadersType
                        .withName(key)
                        .withValue(headers[key])

                    for key in std.objectFields(headers)
                ];


                container + if std.length(kHeaders) > 0 then
                    containerType.mixin[probeName].httpGet
                        .withHttpHeaders(kHeaders)
                        .withPath(path)
                        .withPort(port)
                        .withScheme(scheme)
                    else
                        containerType.mixin[probeName].httpGet
                            .withPath(path)
                            .withPort(port)
                            .withScheme(scheme),

        tcpSocket(host="", port=80)::
            function(probeName, container, containerType)
                container + if std.length(host) > 0
                    then
                        containerType.mixin[probeName].tcpSocket
                            .withHost(host)
                            .withPort(port)
                    else
                        containerType.mixin[probeName].tcpSocket
                            .withPort(port)

    },

    local hidden = {
        probe(probeName, workload, containerName, handler)::
            local podSpec = self.workloadType(workload).mixin.spec.template.spec;
            hidden.modifyContainer(probeName, workload, podSpec, containerName, handler),

        modifyContainer(probeName, workload, podSpec, name, modifier)::
            local containers = [
                if container.name == name then
                    modifier(probeName, container, podSpec.containersType)
                else
                    container

                for container in workload.spec.template.spec.containers
            ];

            workload + podSpec.withContainers(containers),

        workloadType(workload)::
            local kind = self.lowerFirstLetter(workload.kind);
            local group = self.objectGroup(workload.apiVersion);
            local version = self.objectVersion(workload.apiVersion);

            k[group][version][kind],

        objectGroup(apiVersion)::
            local parts = std.split(apiVersion, "/");

            if std.length(parts) == 1 then
                "core"
            else
                self.lowerFirstLetter(parts[0]),

        objectVersion(apiVersion)::
            local parts = std.split(apiVersion, "/");

            if std.length(parts) == 1 then
                parts[0]
            else
                parts[1],

        // converts Group to group and ReplicaSet to replicaSet
        lowerFirstLetter(name)::
            local chars = std.stringChars(name);
            local fn(i, x) =
                if std.type(x) != 'string' then
                    error '%s is not a valid group name' % name
                else
                    if i == 0 then
                        std.asciiLower(x)
                    else
                        x;

            std.join('', std.mapWithIndex(fn, chars)),
    },
}