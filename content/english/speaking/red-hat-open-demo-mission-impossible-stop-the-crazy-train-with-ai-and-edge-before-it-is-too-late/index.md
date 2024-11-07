---
title: "Red Hat Open Demo: Mission impossible #1 - Stop the crazy Train with AI and Edge before it is too late"
date: 2024-11-05T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
- '*.png'
- '*.mp4'
# Featured images for Social Media promotion (sorted from by priority)
images:
- mission-impossible-crazy-train-cover.png
topics:
- Artificial Intelligence
- Edge Computing
---

On November 5, 2024, I presented a webinar named [Mission impossible 1 : Stop the crazy Train with AI and Edge before it is too late](https://events.redhat.com/profile/form/index.cfm?PKformID=0x1270056abcd&extIdCarryOver=true&sc_cid=701f2000000txokAAA) with three colleagues: [Adrien](https://www.linkedin.com/in/adrien-legros-78674a133/), [Mourad](https://www.linkedin.com/in/mourad-ouachani-0734218/) and [Pauline](https://www.linkedin.com/in/trg-pauline/).

This webinar is the pinacle of ten months of hard work.
In this article, I will give you an overview of the demo and you will be able to watch the replay in case you missed the live event.

<!--more-->

## The "Mission impossible" demo

We designed this demo for the {{< internalLink path="/speaking/platform-day-2024/index.md" >}} event based on the latest opus of the movie **Mission Impossible: Dead Reckoning**.
In this demo, **Ethan Hunt** needs help to stop the **Lego City #60337** train before it's too late!
Nothing less than the fate of humanity is at stake!

{{< attachedFigure src="mission-impossible-plot.png" >}}

The scenario requires **Ethan Hunt** to board the train to connect a **Nvidia Jetson Orin Nano** card to the train's computer network and deploy an AI that will recognise the traffic signs and stop the train on time before it derails!
A console will provide a remote view of the train's video surveillance camera, with the results of the AI model's inference overlaid.

{{< attachedFigure src="mission-impossible-scenario.png" >}}

To run this demo, we equipped the **Lego** train with a **Nvidia Jetson Orin Nano** card, a webcam and a portable battery.
The Nvidia Jetson Orin card is a System On Chip (SoC), it includes all the hardware that **Ethan Hunt** needs for its mission: CPU, RAM, storage...
Plus a GPU to speed up the calculations!
The Jetson receives the video stream from the onboard camera and transmits orders to the **Lego** Hub via the **Bluetooth Low Energy** protocol.
It is powered by a portable battery for the duration of the mission.

{{< attachedFigure src="rhel-booth-mission-impossible-demo.jpeg" >}}

We are in an Edge Computing context.
On the Jetson, we have installed **Red Hat Device Edge**.
This is a variant of Red Hat Enterprise Linux adapted to the constraints of **Edge Computing**.
We installed **Microshift**, Red Hat's Kubernetes tailored for the Edge.
And using Microshift, we deployed *over-the-air* microservices, an **MQTT broker** and the artificial intelligence model.

The Jetson is connected, for the duration of the mission, to an OpenShift cluster in the AWS cloud via a 5G connection.
In the AWS cloud, there is a RHEL 9 VM that we can use to build the **Red Hat Device Edge** images for the Jetson SoC.
In the OpenShift cluster, the video surveillance application that broadcasts the video stream from the train's on-board camera.
The video stream is broadcast from the Jetson via a **Kafka broker**!
On top of this, there are MLops pipelines to train the AI model.
And finally CI/CD pipelines to build the container images of our microservices for x86 and ARM architectures.

{{< attachedFigure src="mission-impossible-hardware-architecture.png" >}}

To enable **Ethan Hunt** to carry out its mission successfully, we had to guarantee end-to-end data transmission.
To do this, we implemented five services that communicate via an asynchronous message transmission system (**MQTT**).

The first service captures ten images per second at regular intervals.
Each image is resized to 600x400 pixels and encapsulated in an event with a unique identifier.
This event is transmitted to the AI model, which enriches it with the result of the prediction.
The latter is transmitted to a transformation service whose role is to extract the train's action, transmit it to the train controller to slow down or stop the train and at the same time send the event to the streaming service (**Kafka**) deployed on a remote Openshift, which displays the images and the prediction in real time.

{{< attachedFigure src="mission-impossible-software-architecture.png" >}}

And finally, we had to build an artificial intelligence model.
To do this, we followed best practices for managing the model's lifecycle, known as **MLOps**:

- **Acquire the data**: We used an open source dataset containing data from an on-board camera mounted on a car, which was annotated with the signs encountered on its route.
  The photos were taken on roads in the European Union and therefore show "standard" road signs (potentially slightly different from **Lego** signs).
- **Develop an AI model**: We chose a learning algorithm and trained the model on an OpenShift cluster with GPUs to speed up the calculation.
- **Deploying the model**: We deployed the model in an inference server for consumption via APIs.
  The model had to be integrated into the software architecture (via MQTT).
- **Measure performance and re-train**: By observing the model's behaviour, we were able to measure the quality of the predictions and note that not all **Lego** panels were well recognised.
  We decided to re-train the model by refining it with an enriched dataset.

{{< attachedFigure src="mission-impossible-ai.png" >}}

## Watch the replay!

If you have not been able to attend the live session, I invite you to watch the replay!

{{< youtube 8BTLBF0eQqc >}}

If you’re ready to dive deeper, have questions, or just want to connect, I would love to hear from you.
Feel free to reach out directly on [LinkedIn](https://www.linkedin.com/in/nicolasmasse/), [X](https://x.com/nmasse_itix), or your favorite social platform to start a conversation.
You can also engage [with the Red Hat team behind this demo](https://github.com/Demo-AI-Edge-Crazy-Train) for more insights and guidance on how we’re innovating in open-source technology.
Let’s connect and build together!
