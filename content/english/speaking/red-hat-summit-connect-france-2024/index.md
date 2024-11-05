---
title: "Red Hat Summit Connect France 2024"
date: 2024-10-08T00:00:00+02:00
draft: false
resources:
- '*.jpeg'
- '*.png'
- '*.mp4'
# Featured images for Social Media promotion (sorted from by priority)
images:
- open-code-quest-microservices.png
- rhel-booth-mission-impossible-demo.jpeg
- rhel-booth-mission-impossible-demo-3.jpeg
topics:
- Developer Relations
- Site Reliability Engineer
- Artificial Intelligence
- Edge Computing
---

On October 8, 2024, I took part in the [Red Hat Summit Connect France 2024](https://www.redhat.com/fr/summit/connect/emea/paris-2024) event in a double role:

- I was in charge of the Leaderboard for the **Open Code Quest** workshop and I acted as SRE for the platform of this workshop.
- I was present on the RHEL stand to present our "Mission Impossible" demo with the Lego train.

<!--more-->

## Open Code Quest: a technological and heroic adventure

The **Open Code Quest** workshop brought together technology enthusiasts in an immersive setting that blended technological innovation with the world of superheroes.
The aim was to offer participants an in-depth discovery of Quarkus, OpenShift and OpenShift AI, sprinkled with a pinch of security and a seamless developer experience.
All while immersing them in a captivating adventure where every exercise involved superheroes.

During the workshop, participants had to develop no less than four microservices to build an application simulating combat between superheroes and super villains.

{{< attachedFigure src="open-code-quest-microservices.png" >}}

The microservices were developed in Quarkus, the native Java framework for the cloud, demonstrating how it can transform application development by combining speed of development, lightness and performance.
In particular, Quarkus significantly reduces the memory footprint of applications, while enabling them to start up almost instantaneously.
We have also positioned [Red Hat Developer Hub](https://developers.redhat.com/rhdh/overview), the Red Hat distribution of **Backstage**, an open source platform developed by Spotify to improve the management of complex environments, as the flagship product.
**Red Hat Developer Hub** captured the attention of attendees by offering a unified interface for central management of microservices, CI/CD pipelines and other essential development tools.
Its extensibility made it easy to integrate plugins tailored to the needs of the workshop, simplifying the application lifecycle.
For both developers and architects, **Red Hat Developer Hub** has proved to be a valuable tool, facilitating collaboration and providing a clear view of the infrastructure while improving productivity.
At **Open Code Quest**, we also highlighted [Red Hat Trusted Application Pipelines](https://www.redhat.com/en/products/trusted-application-pipeline), a product designed to secure and automate the software supply chain.
Based on the **Tekton Chains** and **Sigstore** technologies, this product offers complete traceability and guarantees the integrity of software components at every stage of the CI/CD pipeline.
Attendees were able to discover how these tools enhance the security of deployments by providing proof of compliance and transparency on the dependencies used in applications.
I'll let you discover the full list of tools used in the **Open Code Quest** workshop:

{{< attachedFigure src="open-code-quest-namespaces.png" >}}

Before and during the **Open Code Quest**, the administration of the **platform** played a key role in the success of the event.
As an organising member, I was responsible, along with [Sébastien Lallemand](https://sebastienlallemand.net/), for preparing, sizing, installing and configuring the eight OpenShift clusters needed for the workshops to run smoothly.
This included a central cluster, one dedicated to AI, and six others reserved for the participants for their missions.
This crucial preparation phase ensured a stable, high-performance infrastructure.
During the event, my role as SRE (Site Reliability Engineer) was to closely monitor critical metrics, such as resource utilisation, to ensure a smooth and optimal experience for all participants.
Thanks to this proactive monitoring, we were able to offer constant availability of the environments and thus facilitate the smooth running of the workshop.

{{< attachedFigure src="open-code-quest-clusters.png" >}}

Another challenge I tackled for the Open Code Quest was the creation of a **Leaderboard** designed to encourage emulation between participants.
This project required me to think outside the box, as I had to use tools such as **Prometheus** and **Grafana** for a task they weren't designed for: sorting participants by order of finish.
By circumventing the limitations of these monitoring technologies, I used my creativity to design a live ranking system.
Despite the technical complexity, the result exceeded our expectations: the Leaderboard stimulated (friendly) competition between participants, adding a dynamic and engaging dimension to the event.

For us,**Open Code Quest** was much more than just a workshop. It was a day where experts and beginners could exchange ideas, learn and have fun together, while discovering useful technologies for developers and architects.
Whether it was accelerating development with Quarkus, improving the developer experience with Red Hat Developer Hub, managing the security of the supply chain with **Red Hat Trusted Application Pipelines** or using AI with Quarkus, each tool provided concrete value, demonstrated through the exercises.

We also had the opportunity to create an environment that encouraged networking, where participants were able to exchange ideas with experts and their peers.

As a member of the organising team, I'm extremely proud of the success of the **Open Code Quest**.
This workshop showed that it is possible to combine technical learning and entertainment in an immersive and stimulating environment. We would like to thank all the participants for their commitment and enthusiasm, as well as our partners for their support. We look forward to seeing you at future events as we continue to explore together the technological innovations that are transforming our world.

Want to find out more about the Leaderboard?
How did I take into account the specific features of Prometheus when designing the Leaderboard?
How have I calibrated the bonuses and accelerators to encourage competition and emulation?

Everything is explained in these two articles:

1. {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-designed-leaderboard/index.md" >}}
2. {{< internalLink path="/blog/behind-the-scenes-at-open-code-quest-how-i-implemented-leaderboard-with-acm/index.md" >}}

## "Mission Impossible" demo: Lego, AI & Edge Computing

For part of the day, I was on the RHEL booth, accompanied by [Adrien](https://www.linkedin.com/in/adrien-legros-78674a133/), [Mourad](https://www.linkedin.com/in/mourad-ouachani-0734218/) and [Pauline](https://www.linkedin.com/in/trg-pauline/) to install the "Mission Impossible" demo and answer questions from the public.
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

If you weren't able to come and see us on the stand, you can catch up with us in the video below (captured during the {{< internalLink path="/speaking/platform-day-2024/index.md" >}}).
You can see the train stop when it detects the corresponding road sign.

{{< embeddedVideo src="mission-impossible-demo.mp4" autoplay="true" loop="true" muted="true" width="1920" height="1080" >}}

This demonstration shows the relevance of Red Hat solutions for carrying out large-scale IT projects combining **Artificial Intelligence** and **Edge Computing**.

## Conclusion

Through the **Open Code Quest** workshop and the captivating demonstration of the **Lego** train, participants were able to explore innovative solutions for application development, Artificial Intelligence, Edge Computing and Supply Chain security.
All the work done on the platform and the originality of the Leaderboard helped to energise the event, reinforcing the friendly competition between participants while offering them a technical and human experience that we hope will be unforgettable.

For me, this Red Hat Summit Connect was an opportunity to highlight the importance of technologies like Quarkus and OpenShift, but also to share a collective adventure where each participant was able to leave with new skills, inspiration and the desire to continue exploring these solutions.
We hope to continue developing this event to offer even more challenges and innovations to the developer, architect and engineering communities.
See you soon for more technological adventures!
