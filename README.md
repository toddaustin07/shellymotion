# SmartThings Edge driver for Shelly Motion Sensors; includes forwarding bridge server

### Background
Today, there is no direct integration of Shelly Motion Sensors supported by SmartThings.  This might be accomplished through a cloud-to-cloud connection, but a local LAN integration would be more desireable in most cases.

SmartThings Edge drivers - SmartThing's solution for local hub-based device integration - cannot reserve a specific port for LAN communication on the SmartThings hub.  Therefore, a wifi device such as the Shelly Motion Sensor, which can be configured to send an HTTP message upon motion detection, cannot directly connect with an Edge driver in a programatic way.  If one *were* to discover the port number currently in use by the supporting Edge driver, and configure the phyiscal Shelly device with that IP and port number, this would work only temporarily until the Edge driver was restarted or the hub rebooted, since in either of those two scenarios, the driver's port number will change.

In order to solve the problem described above, an intermediate forwarding bridge server is needed to faciliate a long-lasting connection between Edge drivers and these kinds of devices.

## Project Description

This project contains both an Edge Driver for Shelly Motion Sensors, and a forwarding bridge server to faciliate communications to the physical device.

### Edge Driver
The Edge driver is a very straight-forward simple driver for basic motion sensor type devices.  What makes it unique is its use of the bridge server to receive notifications from the Shelly Motion Sensor device when motion is detected.  

The driver currently responds only to motion detected messages.  The Shelly Motion Sensors can also be configured to send a message when motion stops, however to maximize the Shelly Motion Sensor's battery life, it's best to configure it to only send messages when motion is detected.  Thus this driver uses a configurable setting for how long (in seconds) to set device motion **active** before *automatically* returning to **inactive** state.  This should be sufficient for most automation needs.

### Forwarding Bridge Server
The forwarding bridge server (subsequently referred to as 'server') included in this repository has broader capability beyond support for this particular use case (Shelly Motion Sensor).  This section will describe *all* features, as well as highlight how it is used in this particular Shelly Motion Sensor scenario.

The server itself is simply a Python script that can be run on any 'always on' Windows/Linux/Mac computer.  The server is provided either as a 3.7x Python source script or a Windows executable program file.  It can read an optional configuration file created by the user (see below).

The server includes these capabilities:
#### 1. Forward HTTP requests from an Edge driver to any URL
Another limitation of Edge drivers is that the hub platform allows them to communicate to only **local** IP addresses.  This excludes any internet requests or other external Restful API calls, for example.  With this solution, an Edge driver can send a request to the server to be forwarded, which the server will do and return the response back to the requesting Edge driver.  (My Web Requestor https://github.com/toddaustin07/webrequestor devices can also be used to initiate these requests)
##### SmartThings API calls
An additional capability of the server is that it recognizes requests being forwarded to the **SmartThings RESTful API**, and using the Token configured by the user, can forward those requests and return the response, allowing Edge drivers access to any SmartThings API call.  For example, this can allow a driver to get the device status of ANY SmartThings device, and use it in its logic - allowing it to perform SmartApp-like functions.
#### 2. Forward requests from LAN-based devices or applications to a specific Edge driver
As described above, Edge drivers cannot use any specific port, so this makes it impractical for other LAN-based configurable devices (e.g. Shelly Motion Sensor) or applications to be able to send messages directly *TO* an Edge driver without first establishing a unique peer-to-peer or client/server link.  This is possible, but requires more custom coding to make it work (discovery, monitoring connection, managing change, etc.).  

This server offers a simpler solution:  an Edge driver 'registers' with the server what IP address it is interested in getting messages from.  The LAN device or application is configured to send its messages to the server (which has a fixed IP/port number).  Then when the server receives those messages, it looks up who is registered to receive them, and then forwards them to the appropriate IP/port number.  If/when the Edge driver port number changes, it simply re-registers the new port number with the server.  No configuration change is needed at the LAN device or application.  A static IP address is typically recommended for the physical device or application.
### Installation
#### Edge Driver
The Edge Driver is installed like any other through a shared channel invitation.

Once the driver is available on the hub, the mobile app is used to perform an Add device / Scan nearby, and a new device called Shelly Motion Sensor is created and will be displayed in the 'No room assigned' room.  Additional devices can be created using a button on the device details screen ('Create new device').

Before the driver can be operational, the forwarding bridge server must be running on a computer on the same LAN as the SmartThings hub.  See below.

If the server is running, the new SmartThings Shelly Motion Sensor device can be configured by going to the device details screen and tapping the 3 vertical dots in the upper right corner and then selecting Settings.  There are four options that will be displayed:
* Auto motion revert to inactive - this option allows you to control the behavior of the SmartThings motion device when it receives an active motion message from the physical Shelly Motion Sensor via the bridge server.  Typically this would be set to 'Auto-revert to inactive', but this can also be set to NOT auto-revert to inactive (leave in active state)
* Active Motion duration - If the auto revert to inactive setting is chosen, then this is the number of seconds you can configure before the motion sensor reverts to inactive
* Shelly Device Address - this is the IP address of the physical Shelly Motion Sensor; this should be a static IP address
* Bridge Address - this is the IP and port number address of the forwarding bridge server; this should be a static IP address.  The server port number can be configured by the user (see below), but **defaults to 8088**.

Once the Bridge address is configured, the driver will attempt to connect.  Messages should be visible on the server message console.

#### Forwarding Bridge Server

Download the Python script or Windows executable file to a folder on your computer.  You can start it manually or preferrably, configure your computer to auto start the program whenever it reboots.
##### Configuration file
If you want to change the default port number of the server (8088), you can do so by creating a configuration file which will be read when the server is started.  This config file can also be used to provide your SmartThings Token if you plan to do any SmartThings API calls.
The format of the file is as follows:
```
[config]
Server_Port = nnnnn
SmartThings_Bearer_Token = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```
This configuration file is **optional**.

##### Run the Server

Start the server by this command:
```
python3 edgebridge.py
```
It is recommended to run this in a window where you can monitor the output messages.  You may want to log them permanently to a file as well.

Note that the server creates and maintains a hidden file ('.registrations') which contains records capturing the Edge driver ID, hub address, and LAN device/application IP address to be monitored.  As driver port numbers change due to restarts, the registrations file may contain old records for a short time, but these will eventually be cleared out after 3 failed attempts to communicate with the 'old' port number(s).
