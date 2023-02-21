---
title: "Red Hat Tech Exchange 2023"
date: 2023-02-03T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
---

During the Red Hat Tech Exchange 2023 that took place in Dublin, I presented a Lab with a group of colleagues.
The lab is named **"From the ESP32 to the OpenShift cluster: discover what Red Hat can offer for the Edge computing!"**.

Through the common theme of "shipment tracking", this lab helps you understand what Red Hat can offer for the Edge computing.

In this lab, you are at the head of a "parcel shipment hub" and you deploys everything needed to:

* read the parcel RFID (using arduino and ESP32),
* send data to a MQTT broker over wifi,
* transform those data using Camel-K
* and send relevant events to the headquarter for reporting.

An application at the headquarter displays the parcels moving from one hub to another in realtime.

The whole room had a lot of fun!

{{< attachedFigure src="Image_20230203_090806_445.jpeg" title="I presented the Lab organization." >}}

If you want to play with the Lab, all the code is under the [RHTE-2023-Edge-Lab](https://github.com/RHTE-2023-Edge-Lab) organization.

* [rhte-gitops](https://github.com/RHTE-2023-Edge-Lab/rhte-gitops): the Kubernetes manifests to deploy the Lab on OpenShift using ArgoCD
* [worldmap-front](https://github.com/RHTE-2023-Edge-Lab/worldmap-front): the frontend that shows shipments on a worldmap
* [camel-kafka-enricher](https://github.com/RHTE-2023-Edge-Lab/camel-kafka-enricher): a Camel Quarkus app that enriches events from the warehouses with metadata and merges them in a single topic
* [kafka-streams-shipments](https://github.com/RHTE-2023-Edge-Lab/kafka-streams-shipments): a Quarkus app that uses Kafka Streams to transform location event (*a parcel has been seen at this location*) to shipment events (*a parcel has moved from this location to this location*)
* [parcel-tracker-arduino](https://github.com/RHTE-2023-Edge-Lab/parcel-tracker-arduino): the firmware of the ESP8266 to scan parcels using RFID

The Lab instructions are [here](https://rhte-2023-edge-lab.github.io/).
