---
title: "Homelab: 2U server, short depth, with front IO, based on Ampere Altra and Asrock Rack ALTRAD8UD-1L2T motherboard"
date: 2024-06-21T00:00:00+02:00
opensource:
- Fedora
topics:
- Edge Computing
- Homelab
resources:
- '*.jpeg'
- '*.webp'
---

In March of this year, I decided to find a new server to host the family's data (Jellyfin, Nextcloud, etc.), control the house with Home Assistant and run the VMs I need for my work.
In this article, I detail my constraints and the construction of this server, based on an **Ampere Altra** CPU (**ARM64** architecture).

<!--more-->

## Current gear

I am currently hosting my services on a **HP DL20 Gen9** server, purchased second-hand in June 2021 for €640.

This **HP DL20 Gen9** server is equipped with :

- 1 CPU **Intel Xeon E3-1270 v6** at 4.2 GHz (4C/8T)
- 48 GB ECC RAM
- 2 x 3.5" disks, 4 TB each, configured as RAID 1 using the HP RAID card
- 6 x 1 GbE RJ-45 ports

{{< attachedFigure src="hp-dl20-gen9.webp" title="The existing HP DL20 Gen9 server." >}}

This server is currently racked in a 7U, short depth IT rack in the basement of the house and is currently running **CentOS Stream 8** which I have configured as a [router](/fr/blog/fibre-orange-remplacer-livebox-routeur-centos-stream-8) and hypervisor (with **libvirt**).

The hypervisor runs several VMs:

- **Kubernetes** vanilla with all family services (Jellyfin, Nextcloud, etc)
- **Home Assistant**
- A bastion (**CentOS Stream 8**) for incoming SSH connections
- A seedbox (**qBittorrent**)
- A reverse proxy (**Traefik**) to dispatch on the internal network TLS connections incoming on the only IPv4 address I own.
- The **Unifi** controller that manages my switches and Wifi access points.

## Current hardware limitations and upcoming needs

Between the time I bought this **HP DL20 Gen9** and now, my needs have evolved and the technological context has changed too.

I had not anticipated the number of services I would be running in my **Kubernetes**.
I now have 54 pods spread over 35 namespaces.

At the time, I went for a vanilla **Kubernetes**, but the time has passed, and I realized that a vanilla Kubernetes requires more time and energy to administer on a daily basis than I have to offer.
So I'm looking to migrate all my services to **OpenShift**.

The performance of 3.5" hard disks is becoming a burden for large file transfers.
The RAID card's cache fills up quickly, and I hit a ceiling at the meager throughput of the 3.5" 7200 rpm hard disks: ~187 MB/s.

The CPU, although powerful at the time, no longer holds up to the comparison.
The **AMD Ryzen 7 7840U** CPU on my **Framework Laptop 13** has 64% higher floating-point computing performance than the **Intel Xeon E3-1270 v6** on the **HP DL20 Gen9** server.

The 48 GB RAM currently installed allows me to run my current services, but not the services I'm planning (**OpenShift** in particular).

The expansion capabilities of the **HP DL20 Gen9** are quite limited: 2 PCIe x8 slots.
The full-height slot is taken by the RAID controller and the half-height slot is taken by the 4-port GbE network card.

Last but not least, the motherboard and CPU of the **HP DL20 Gen9** do not support **SR-IOV**. This currently forces me to run network routing functions directly on the hypervisor.
SR-IOV would allow me to put the [CentOS Stream router](/fr/blog/fibre-orange-remplacer-livebox-routeur-centos-stream-8) into a VM without performance loss.

To sum up, I need :

- More RAM
- A more powerful CPU
- Fast NVMe storage
- More free PCIe slots
- SR-IOV

## Form factor

What I like about the **HP DL20 Gen9** is its form factor: 1U short depth.
It's convenient to store in a wall-mounted IT rack, and it doesn't take up floor space.
On the other hand, to put everything I need in it, I need to target a little bigger: **2U format**.

With this in mind, I set out to find the Holy Grail of Edge Computing: a 2U case, short depth, front IO, with NVMe backplane and CRPS power supply.

After so many acronyms and buzzwords, a few explanations are required:

- Case height is expressed in rack units (**U**).
  **2U** is the minimum height required to fit a PCIe card or NVMe disk vertically, and thus achieve good density.
- In Edge Computing projects, servers are often racked in small, short depth IT racks (60 cm, sometimes even 45 cm), as opposed to datacenters where racks are usually deeper (120 cm).
  Servers that fit into these cabinets are called **short depth**.
- These computer cabinets are often wall-mounted, which means that access to the rear of the server is difficult: it's gained through the sides of the cabinet, with limited visibility.
  Servers with I/O on the **front side** are called **front IO**.
- Finally, to accommodate high-speed flash storage in **U.2** slots, the enclosure must be equipped with an **NVMe backplane**.
- Servers on the market with these features generally require power supplies in **CRPS** (*Common Redundant Power Supply*) format.
  The **CRPS** format defines the size of the power supplies, the voltages they deliver and the communication between the power supply and the motherboard (**SMbus**).

In the basement of my house, I have a 60 cm-deep IT rack (**Digitus DN-19 07U-6/6-EC-SW**), of which only 45.9 cm can be used to house a server.

**So I went in search of a short depth, front IO server, with a NVMe backplane and a CRPS power supply!**

## ASRock Rack ALTRAD8UD-1L2T motherboard

In December 2023, **Asrock Rack** released a server motherboard supporting **Ampere Altra** CPUs: the [ALTRAD8UD-1L2T](https://www.asrockrack.com/general/productdetail.asp?Model=ALTRAD8UD-1L2T#Specifications).
This motherboard has created quite a stir in the specialist press. [Patrick Kennedy](https://www.servethehome.com/author/patrick/) even went so far as to headline "[ASRock Rack ALTRAD8UD-1L2T Review This is the Ampere Arm Motherboard You Want!](https://www.servethehome.com/asrock-rack-altrad8ud-1l2t-review-this-is-the-ampere-arm-motherboard-you-want/)".

On its own, the card has everything to please:

- Support for Ampere Altra / Ampere Altra Max CPUs
- 8 DDR4 slots (supporting ECC memory), 1 DIMM per channel, max 256 GB per DIMM. A maximum of 2 TB RAM.
- 2 PCIe 4.0 x16 slots + 2 PCIe 4.0 x8 slots
- 2 M.2 2280/2230 slots (PCIe 4.0 x4)
- 4 SlimSAS connectors (PCIe 4.0 x8)
- 2 OCuLink connectors (PCIe 4.0 x4)
- Intel X550 network card with 2 RJ45 ports (10 GbE)
- Intel i210 network card: 1 RJ45 port (1 GbE)
- IPMI console

First problem: the card is in **Deep Micro-ATX** format.
This format is a bit out of the norm: it looks like [Micro-ATX](https://fr.wikipedia.org/wiki/Format_ATX), but 2.3 cm deeper.
Obviously, case manufacturers don't advertise their compatibility with this **Deep Micro-ATX** format, because... well, it's not standard! 😡

The tricky part is then getting the processor to go with it!
Altra Ampere CPUs are virtually impossible to find on online high-tech retailer websites. 😱

## Ampere Altra Q64-22 processor

Fortunately, [Asrock Rack](https://www.asrockrack.com/), [Ampere Computing](https://amperecomputing.com/) and [Newegg](https://www.newegg.com/) have joined forces to make all this possible for the "Homelab" community.

Newegg offers two bundles on its site:

- [ASRock Rack ALTRAD8UD-1L2T + Ampere Altra Q64-22](https://www.newegg.com/asrock-rack-altrad8ud-1l2t-q64-22-ampere-altra-max-ampere-altra-processors/p/N82E16813140134)
- [ASRock Rack ALTRAD8UD-1L2T + Ampere Altra M128-26](https://www.newegg.com/asrock-rack-altrad8ud-1l2t-q64-22-ampere-altra-max-ampere-altra-processors/p/N82E16813140135)

And both bundles include the heatsink that is compatible with 2U cases. 🥳

I chose the **Ampere Altra Q64-22** because it allows me not to blow the budget.
And I say to myself that by the time I've used all 64 cores, water will have flowed under the bridge and maybe 128-core Ampere Altra Max CPUs will be found on eBay for a reasonable price.
Then it will still be time to upgrade to a more powerful CPU.

The **Ampere Altra Q64-22** CPU has a TDP of 69 W according to the [Ampere Altra datasheet](https://d1o0i0v5q5lp8h.cloudfront.net/ampere/live/assets/documents/Altra_Rev_A1_DS_v1.27_20220331.pdf).

{{< attachedFigure src="ampere-altra-q64-22.jpeg" title="The Ampere Altra Q64-22 CPU, mounted on the ASRock Rack ALTRAD8UD-1L2T motherboard" >}}

Another difficulty is that I live in France, and Newegg doesn't ship to France...
So I had to go through a reshipper: a company located the USA that receives packages and ships them all over the world.

## The reshipper, an essential intermediary

I used the services of [Ship7](https://www.ship7.com/), which seemed honest and not too expensive.
Well, between the cost of Ship7, the cost of the transporter who will bring the parcel to France and the taxes to clear customs, it's illusory to shop in the US and expect to pay less than in France.
The opposite is true! On the other hand, for equipment that's impossible to find on this side of the Atlantic ocean, it's a great way to get by!

The procedure for using the reshipper service is pretty straightforward:

- I created an account on [Ship7](https://www.ship7.com/)
- Ship7 gave me a suite number and the address of its warehouse
- On the Newegg website, when placing an order, I gave the Ship7 warehouse address and put my suite number in the Full Name field and in the second line of the address.
  (The suite number is what allows Ship7 to put my packages in the right box when they arrive at their warehouse).
- Once the parcels had arrived at Ship7, I received an e-mail notification and was able to schedule them for shipment by UPS to my home.

It should be noted that Ship7 takes care of printing the documents for customs, but I had to declare the exact amount of the items contained in the parcel.
At this stage, you have to be careful not to make a mistake.

If I don't enter the right price, the customs duties will be wrong:

- Too high and I'll pay too much duty.
- Too low and I risk paying too little in customs duties.
- The right amount is the one shown on the Newegg invoice (excluding shipping costs).

## Innovision M24306 enclosure

Finding the right case was the most time-consuming and tedious part of the process, for several reasons:

- My requirements led me to "Edge Computing" type enclosures, which were scarce, often out of stock and deliverable only to a business address, with a valid VAT number. 😭
- The motherboard I chose is in **Deep Micro-ATX** format, which is non-standard.
  And it's difficult to estimate the compatibility of a case with this format on the basis of photos (often not contractually binding). 🤔
- The cases I've been able to find often require a **CRPS** format power supply, which aren't easy to find and little documentation exists on the subject. 😡

Before deciding to buy the [Innovision M24306](http://iovserver.com/2u-server-case/m24306.html) case, I evaluated other cases, of which I leave the references below in case the case I chose is no longer available.

- [Chenbro RM252 FIO](https://www.chenbro.com/en-global/products/RackmountChassis/2U_Chassis/RM252), reference **RM25206H02\*15621**
- [AIC RMC-2E](https://www.aicipc.com/en/productdetail/51295), reference **XE1-2E000-04**

The **Innovision M24306** is available on [Aliexpress](https://www.aliexpress.us/item/1005005856237609.html) and [Alibaba](https://www.alibaba.com/product-detail/Ultra-Short-2U-rackmount-Server-Chassis_1600636420062.html).

{{< attachedFigure src="innovision-m24306.jpeg" title="The Innovision M24306 case." >}}

Some useful notes (I asked for clarification before ordering):

- The four 8038 fans are supplied with the case.
- The CRPS power supply must be purchased separately.
- The 6 SFF caddies are supplied with the case.
- The type of backplane (**NVMe**) must be specified when ordering.
- Cables to connect the NVMe backplane to the motherboard must be purchased separately.

Note: the VGA connector on the server's right ear is not connected to anything.
But this isn't a problem in the sense that the case has its inputs/outputs on the front side, so the VGA connector is already on the front side and doesn't need to be remoted.

{{< attachedFigure src="vga-not-connected.jpeg" title="The VGA socket on the right ear of the Innovision M24306 is not connected." >}}

## FSP CRPS power supply

The **Innovision M24306** enclosure has a slot for a **CRPS 1+1** power supply.
**CRPS** stands for *Common Redundant Power Supply* and is a standard developed by the Modular Hardware System working group (https://www.opencompute.org/projects/mhs) of the **Open Compute** consortium.
Among other things, it defines the dimensions and voltages of redundant power supplies for servers.
It's a relatively recent standard (v1.0 was released in July 2023).

The term **1+1** means that the power supply is redundant and can tolerate the failure of one out of two devices.

Unlike ATX power supplies, which are a single unit, CRPS power supplies are made up of three parts:

- Two modules that convert the mains current into 12V direct current.
  These two modules are identical and interchangeable.
  If one module fails, the second can take over.
- A module whose task is to adjust the 12V voltage to the other voltages required by the server components (3.3V, 5V, etc.) and to perform the failover in the event of failure.

If you want to learn more about this standard, I invite you to read the specifications published on [the Open Compute wiki](https://www.opencompute.org/w/index.php?title=Server/MHS#Current_Status).

I've identified two brands that make CRPS power supplies and have a good network of distributors: [FSP](https://www.digikey.com/en/ptm/f/fsp-technology/common-redundant-power-supply-series) and [Athena Power](http://athenapower.com/product/power-supply/redundant/ap-rru2m5562).
I chose the Power Distribution Board [FSP-FC210](https://www.fsp-group.com/download/pro/FSP-FC210FSP-FC210E_Datasheet.pdf) as it was the model most likely to fit in the case.
And I was right!
The [FSP-FC250](https://www.fsp-group.com/download/pro/FSP-FC250_Datasheet.pdf), a little more high-end, has the advantage of being modular, but it's 4 cm deeper and wouldn't fit in the case.

I then opted for the lowest-powered power supply module available, as 2 x 550W is already a lot for a small server!
This is the [FSP550-20FM](https://www.fsp-group.com/download/pro/FSP550-20FM_Datasheet.pdf) model.

{{< attachedFigure src="psu-fsp.webp" title="The composition of the FSP CRPS power supply." >}}

Please note that the Power Distribution Board is only fixed to the case by two small screws.
To prevent it from moving, I had to shim it with a piece of foam.
Once everything's in place, it's not noticeable. 😎

In the manufacturer's data sheet, I was unable to find details of the connectors attached to the **FSP-FC210**.
For those wondering, the **FSP-FC210** Power Distribution Board is equipped with :

- 1 PMbus connector
- 1 ATX 24-pin connector
- 6 SATA connectors
- 7 PCIe 12V connectors

## SlimSAS PCIe 4.0 cables

To connect the NVMe backplane to the motherboard, I had to find the right cable.
The connector on the motherboard and on the backplane are of the same kind: **SlimSAS** / **SFF-8654**.

The reference **CAB-8654/8654-8i-11-P0.5M-85** from [10Gtek](https://www.10gtek.com/8654) has all the required characteristics:

- SlimSAS cables are available in two widths: *4 lanes* (**4i**) or *8 lanes* (**8i**).
  Both motherboard and *backplane* are in *8 lanes* (**8i**).
- Cables are available in two impedance versions: 85 ohms or 100 ohms.
  It would seem that for PCIe signals, the **85 ohms** version should be chosen.
- Different lengths are available, and I've chosen **50 cm** cables.
- Finally, you can opt for angled or straight connectors.
  I chose the **straight connectors**.

{{< attachedFigure src="slimsas-cables.webp" title="SlimSAS / SFF-8654 cable routing in the Innovision M24306 box." >}}

## Storage

For storage, I would have liked to use the six U.2 slots of the NVMe backplane.
That was one of my criteria.
But buying three to six SSDs of the model I was aiming for (Samsung PM1733) would have blown my budget.

So I decided to reuse three **Samsung PM1735** NVMe SSDs, 6.4TB each, which I also had in my homelab.
I had bought these SSDs at a time when they were cheaper than they are now.
These SSDs are in *Add-in Card (AIC)*, half-height, half-length (**HHHL**) format, which takes up 3 PCIe slots out of the 4 on the motherboard.
But for the time being, it keeps me going.
And if I find an eBay auction with a batch of Samsung PM1733 SSDs at a good price, I'll just have to transfer the data to the new SSDs to get 3 PCIe slots back.

{{< attachedFigure src="nvme-storage.jpeg" title="Three Samsung PM1735 SSDs and one Samsung 980 PRO SSD installed in the case." >}}

It should be noted that the **Samsung PM1733A** SSDs have been tested by **Ampere Computing** and have shown good performance with their CPU! See [Samsung FIO Performance - Solution Brief](https://amperecomputing.com/briefs/samsung-FIO-performance).

On top of that, I've added an NVMe SSD in M.2 format to host the operating system: a **Samsung SSD 980 PRO** (equipped with a heatsink).

I also tested six U.2 format (PCIe 3.0) NVMe SSDs on the case's NVMe backplane. And it works! However, I didn't test the hotplug feature, as I don't think the case's backplane has it implemented.

{{< attachedFigure src="more-nvme-storage.webp" title="Six more NVMe SSDs, for a total of 26.4 TB of NVMe storage!" >}}

## Bill of Materials

For anyone wanting to build their own identical server, I've assembled a list of the hardware to be purchased.
In the "Description" and " Dealer" columns, I've included links to the manufacturer's datasheet, as well as the dealer I used to buy the hardware.

| Category | Description | Dealer | Quantity | Total price |
| ----------------- | ------------------------------------------------------------------------- | ----- |:--------:| ----------:|
| Motherboard | [ASRock Rack ALTRAD8UD-1L2T + Ampere Altra Q64-22 64](https://www.asrockrack.com/general/productdetail.asp?Model=ALTRAD8UD-1L2T) | [Newegg](https://www.newegg.com/asrock-rack-altrad8ud-1l2t-q64-22-ampere-altra-max-ampere-altra-processors/p/N82E16813140134) | 1 | 1500,00 $ |
| RAM | [Micron 64GB DDR4 3200 8Gx72 ECC CL22 RDIMM](https://www.crucial.com/memory/server-ddr4/mta36asf8g72pz-3g2r) | [Newegg](https://www.newegg.com/micron-64gb-288-pin-ddr4-sdram/p/1FR-009G-00004) | 2 | 310,00 $ |
| Case | [Innovision M24306 with NVMe backplane](https://www.iovstech.com/2u-server-case/m24306.html) | [Alibaba](https://www.alibaba.com/product-detail/Ultra-Short-2U-rackmount-Server-Chassis_1600636420062.html) | 1 | 256,00 $ |
| PSU | [FSP FC210 Power Distribution Board](https://www.fsp-group.com/download/pro/FSP-FC210FSP-FC210E_Datasheet.pdf) | [Digikey](https://www.digikey.com/en/products/detail/fsp-technology-inc/FSP-FC210/16164277) | 1 | 145,90 € |
| PSU | [FSP 550-20FM AC/DC Converter 12V 500W](https://www.fsp-group.com/download/pro/FSP550-20FM_Datasheet.pdf) | [Digikey](https://www.digikey.com/en/products/detail/fsp-technology-inc/FSP550-20FM/16164275) | 2 | 277.02 € |
| Cable | [10Gtek SFF-8654 8i Cable, SAS 4.0, 85 ohm, 0.5 meter](https://www.10gtek.com/8654) | [10Gtek](https://www.10gtek.com/8654) | 3 | 89,00 $ |
| Cable | [StarTech.com 9 Pin Serial Male to 10 Pin Motherboard Header LP Slot Plate](https://www.startech.com/en-us/cables/plate9mlp) | [Amazon](https://www.amazon.fr/StarTech-com-PLATE9MLP-Plaque-broches-encombrement/dp/B001EHFV02/) | 1 | 5,52 € |
| Cable | Molex to to Dual SATA Power Adapter Splitter | [Amazon](https://www.amazon.fr/gp/product/B07QWX3G26/) | 2 | 4,99 € |
| Storage | [Samsung SSD 980 PRO M.2 PCIe NVMe 2 To](https://www.samsung.com/fr/memory-storage/nvme-ssd/980-pro-with-heatsink-2tb-nvme-pcie-gen-4-mz-v8p2t0cw/) | [LDLC](https://www.ldlc.com/fiche/PB00475439.html?offerId=AR202110130112) | 1 | 196,90 €   |
| Storage | [Samsung SSD PM1735 6.4 TB](https://semiconductor.samsung.com/ssd/enterprise-ssd/pm1733-pm1735/) | [eBay](https://www.ebay.com/sch/175669/i.html?_from=R40&_nkw=MZPLJ6T4HALA-00007) | 3 | 1694,00 € |

With an exchange rate of 1 USD = 0.93 EUR, the total comes to **€4,328.48** or **$4,654.28**.
And in this price, I haven't counted shipping costs, customs duties, etc. 💸

## Cooling

It should be noted that, by default, the airflow of the **FSP 550-20FM** power supply and **Innovision M24306** case fans is reversed: the power supply fans blow in a **front to back** direction, while the case fans blow in a **back to front** direction.
Fortunately, the case fans can be reversed.

{{< attachedFigure src="fans-air-flow.webp" title="I flipped all four fans to have front to back airflow. In this configuration, the fan labels are not visible from inside the case." >}}

I haven't done a performance test yet, but the temperatures measured are lower with this optimized airflow.
The effect is most noticeable in the 6 NVMe SSDs on the left.
In fact, they are cooled solely by the power supply fans.

The case is designed for motherboards with 7 PCIe slots, whereas the **ASRock Rack ALTRAD8UD-1L2T** has only 4.
The three unused slots can be masked to force airflow to where it's most needed.

## End result

The external appearance of the product is rather flattering, almost professional.

{{< attachedFigure src="final-product.webp" title="2U server based on an Innovision M24306 case, an ASRock Rack ALTRAD8UD-1L2T motherboard and an Ampere Altra Q64-22 CPU. Front view is on the top, rear view is on the bottom." >}}

The interior isn't as well designed as an HP or Dell server, but I'd be quite happy with it. 😎

{{< attachedFigure src="internal-layout.webp" title="Internal layout of the Innovision M24306 case with an ASRock Rack ALTRAD8UD-1L2T motherboard and an Ampere Altra Q64-22 CPU." >}}

Last photos, this time with the cover in place, ready to be racked! 🚀

{{< attachedFigure src="perspective-view.webp" title="Innovision M24306 case with an ASRock Rack ALTRAD8UD-1L2T motherboard and an Ampere Altra Q64-22 CPU." >}}

## Conclusion

I opted for an ARM64 architecture because it met my needs, but above all I wanted to improve my skills in this area.
And clearly I wasn't disappointed!
I learned a lot assembling this 2U server based on Ampere Altra (ARM64 architecture).

And if you'd like to take the plunge, come and discuss your project on the [Ampere Computing forum](https://community.amperecomputing.com/u/nmasse-itix/activity)!
