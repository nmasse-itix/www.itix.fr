---
title: "Red Hat Open Demo: From the ESP8266 to the OpenShift cluster: discover what Red Hat can offer for the Edge computing!"
date: 2023-04-04T00:00:00+02:00
draft: false
resources:
- '*.svg'
- '*.png'
- '*.jpeg'
- '*.mp4'
# Featured images for Social Media promotion (sorted from by priority)
images:
- cover.png
topics:
- Edge Computing
---

On April 4, 2023, I presented a webinar named [From the ESP8266 to the OpenShift cluster: discover what Red Hat can offer for the Edge computing!](https://events.redhat.com/profile/form/index.cfm?PKformID=0x1270056abcd&extIdCarryOver=true&sc_cid=701f2000000txokAAA) with three colleagues: [Adrien](https://www.linkedin.com/in/adrien-legros-78674a133/), [Florian](https://www.linkedin.com/in/florian-even/) and [Sébastien](https://www.linkedin.com/in/sebastien-lallemand/).
This webinar showcases a lab that we built and delivered for the {{< internalLink path="/speaking/red-hat-tech-exchange-2023/index.md" >}}.

<!--more-->

## Lab description

In this lab about Edge computing, participants stepped into the role of managing a parcel shipment hub using Red Hat products.
The exercises revolved around the common and relatable theme of "shipment tracking".

Participants helped a fictious company, FSC (the **F**edora **S**hipping **C**ompany), set up its Edge computing infrastructure to support 10 warehouses and a central headquarter across EMEA.

{{< attachedFigure src="slide-context.png" >}}

During the lab, attendees set up and deployed all essential components to create a connected parcel tracking system.
They began by configuring devices, using the Arduino IDE and an [ESP8266](https://en.wikipedia.org/wiki/ESP8266), to read the parcel tracking number using RFIDs, which is then transmitted over Wi-Fi to an MQTT broker.
Using Camel-K, the data was transformed into actionable events and sent to a central headquarter system for real-time reporting.

{{< attachedFigure src="architecture.svg" >}}

Meanwhile, at the headquarter level, a dedicated application visually mapped the movement of parcels as they traveled between hubs, creating an interactive, dynamic view of the entire shipment process.

{{< embeddedVideo src="demo.mp4" autoplay="true" loop="true" muted="true" width="1152" height="720" >}}

To make the lab as much fun and interactive as possible, the participants had to work in teams of six people:

- Two people working in pair programming were setting up the firmware of the ESP8266 microcontrollers to scan **incoming** parcels, along with the MQTT broker and the **incoming** topic.
- Two people, *ditto*, were setting up the firmware of the ESP8266 microcontrollers to scan **outgoing** parcels, along with the MQTT broker and the **outgoing** topic.
- Two people, *ditto*, were setting up the Camel-K routes and the Kafka broker.

{{< attachedFigure src="slide-principle.png" >}}

Then, once everything properly setup, a participant scan a parcel in the **Athens** warehouse and then in the **Paris** warehouse and in realtime a parcel would move from **Athens** to **Paris** on the map displayed on the screen.

## Bill of materials

This lab makes use of physical devices to scan the RFID tags of parcels, so if you plan to replicate this setup, you might need the following Bill of Materials.

| # of items | Description                                                  | Unit price  |
|------------|--------------------------------------------------------------|-------------|
| 1          | 2.4 GHz Access Point, compatible with OpenWRT (TL-WR802N V4) | 27 €        |
| 25         | Wemos D1 mini ESP8266 development kit                        | 6,99 €      |
| 25         | RC522 RFID reader kit (each kit has 2 RFID tags included)    | 3,40 €      |
| 25         | USB A - Micro USB cable                                      | 0,99 €      |
|            |                                                    **Total** | **~ 310 €** |

The ESP8266 and RC522 RFID reader have to be soldered on together.
Rince and repeat for the 25 units!
For each unit, it took me from one hour down to 20 minutes once properly trained.
Quite a time consuming task!

{{< attachedFigure src="esp8266-rc522.jpeg" >}}

## Replay

If you have not been able to attend the live session, I invite you to watch the replay!

{{< youtube _m4JRHeX4LI >}}
