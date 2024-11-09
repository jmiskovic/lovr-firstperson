A simple kick-off starting point for first-person graphics in [LÖVR](https://github.com/bjornbytes/lovr).

Features:
* a small static geometry level for testing controls (by [astrochili](https://github.com/astrochili/defold-kinematic-walker/))
* capturing of the mouse cursor
* 1st person camera control, with mouse smoothing
* basic character controller that can walk (*WASD*), run (*Shift*), slide along walls and jump (*Space*)
* stable behavior on elevators and other moving platforms

The character controller is implemented as a rigid (non-kinematic) body capsule collider that has
rotations disabled. It is controlled by directly setting the body's velocity. This is the most
simple method that gives decent results.

Limitations:
* different speeds when climbing and descending slopes
* character will slowly slide down the steep slopes
* gets stuck when encounters even a short step and a jump is needed to clear it (no auto-stepping)
* sometimes the motion is jerky when sliding along a short step
* many others, probably

It might be a good idea to disable collisions between `character` tag and everything that is not
kinematic. The character could push crates around, but physics would glitch when crates are pushed
into the wall.
