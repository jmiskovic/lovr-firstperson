A simple kick-off starting point for first-person graphics in [LÖVR](https://github.com/bjornbytes/lovr).

Features:
* quake-like character controller by [Luffaren](http://www.luffaren.com/)
* walk (WASD), run (Shift), crouch (ctrl / C), jump (space)
* capturing the mouse cursor
* 1st person camera with mouse smoothing
* stable behavior on elevators and other moving platforms
* a small static geometry level for testing controls by [astrochili](https://github.com/astrochili/defold-kinematic-walker/)

The character controller is modeled after Quake. There is no capsule collider presence in the physics
world. Any interaction between player controller and world is strictly one-way, through casting and
querying. The player controller won't influence any physics as a part of this library.

A logical next step towards a first-person gameplay is to make a sensor capsule collider that tracks
the player position, to respond to bullets and environmental dangers. Out of scope for this lib.
