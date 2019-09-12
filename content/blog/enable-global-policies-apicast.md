---
title: "Enable global policies on Apicast 3.6"
date: 2019-09-10T00:00:00+02:00
opensource: 
- 3scale
---

Recent versions of Apicast have a pluggable policy mechanism to apply different treatments to each exposed API.
This is very powerful since each service receives its specific configuration.
However, if the same treatment has to be applied to every service exposed, it becomes an administration overhead.

Hopefully, Apicast has the concept of *Global Policies* that applies to every service exposed by itself.
An example of a widespread policy, especially during demos, is the CORS policy to allow the API Developer Portal to query the API Gateway directly.

To configure the *Global Policy Chain*, you will have to provide a custom *Environment file*.
By default, there is one for the [Staging Environment](https://github.com/3scale/APIcast/blob/3.6-stable/gateway/config/staging.lua) and one for the [Production Environment](https://github.com/3scale/APIcast/blob/3.6-stable/gateway/config/production.lua).

Start from those default *Environment Files* and add a `policy_chain` field with your *Policy* inserted wherever you want in the default *Global Policy Chain*.
The default *Global Policy Chain* can be found in the [`gateway/src/apicast/policy_chain.lua`](https://github.com/3scale/APIcast/blob/b8f7f067dd47936f93bc9bd3e6de224c304d58ea/gateway/src/apicast/policy_chain.lua#L67-L72) file.

**production.lua:**
{{< highlight lua "hl_lines=8-14" >}}
return {
    master_process = 'on',
    lua_code_cache = 'on',
    configuration_loader = 'boot',
    configuration_cache = os.getenv('APICAST_CONFIGURATION_CACHE') or 5*60,
    timer_resolution = '100ms',
    port = { metrics = 9421 },
    policy_chain = require('apicast.policy_chain').build({
        'apicast.policy.load_configuration',
        'apicast.policy.find_service',
        'apicast.policy.cors',
        'apicast.policy.local_chain',
        'apicast.policy.nginx_metrics'
    }),
}
{{< / highlight >}}

**staging.lua:**
{{< highlight lua "hl_lines=7-13" >}}
return {
    master_process = 'on',
    lua_code_cache = 'on',
    configuration_loader = 'lazy',
    configuration_cache = os.getenv('APICAST_CONFIGURATION_CACHE'),
    port = { metrics = 9421 }, -- see https://github.com/prometheus/prometheus/wiki/Default-port-allocations,
    policy_chain = require('apicast.policy_chain').build({
        'apicast.policy.load_configuration',
        'apicast.policy.find_service',
        'apicast.policy.cors',
        'apicast.policy.local_chain',
        'apicast.policy.nginx_metrics'
    }),
}
{{< / highlight >}}

Then, create a ConfigMap from those two files and mount it in `/opt/app-root/src/config`:

{{< highlight sh >}}
oc create configmap apicast-cors --from-file=production.lua --from-file=staging.lua
oc set volume dc/apicast-production --add --name=apicast-cors -t configmap --configmap-name=apicast-cors -m /opt/app-root/src/config
oc set volume dc/apicast-staging --add --name=apicast-cors -t configmap --configmap-name=apicast-cors -m /opt/app-root/src/config
{{< / highlight >}}
