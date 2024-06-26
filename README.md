# CosmOS
CosmOS is an extensive operating system designed as a drop-in replacement for the default WarpDrive controller script.

This is still very much a work in progress.

Objectives:
1. Make a more user-friendly interface for the WarpDrive controller with clickable buttons and a GUI that can be extended to a monitor.
2. Extend the WarpDrive controller features with Autopilot, Waypoints, Jump Cancelling, A map/general navigation improvements, and Multicore
3. Add hooks for other peripherals, like cloaks, radars, and shields which can be controlled from the GUI and put on specific monitors. Also, peripheral hotswap.

## Installation
First, remove an existing startup scripts, like the original WarpDrive controller script.\
`rm startup`\
Then, download the CosmOS script.\
`wget https://raw.githubusercontent.com/jhammerberg/CosmOS/main/CosmOS.lua startup/CosmOS`\
Then just reboot the computer and the CosmOS will start up.