---
title: "How to size your projects for Red Hat's single sign-on technology"
date: 2021-06-07T00:00:00+02:00
draft: false
opensource:
- keycloak
- K6
topics:
- Performance testing
---

Red Hat's single sign-on (SSO) technology is an identity and access management tool included in the Red Hat Middleware Core Services Collection that's based on the well-known Keycloak open source project.
As with other Red Hat products, users have to acquire subscriptions, which are priced according to the number of cores or vCPU used to deploy the product.

This presents an interesting problem for pre-sales engineers like me.
To help my customers acquire the correct number of subscriptions, I need to sketch the target architecture and count how many cores they need.
This would not be a problem if off-the-shelf performance benchmarks were available; however, they are not.

This article will help colleagues and customers estimate their SSO projects more precisely.
We will examine the performance benchmarks I ran, how I designed them, the results I gathered, and how I drew conclusions to size my SSO project.

[Continue reading on developers.redhat.com](https://developers.redhat.com/articles/2021/06/07/how-size-your-projects-red-hats-single-sign-technology)
