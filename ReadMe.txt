Off-Screen Particle Renderer for Unity
©2015 Disruptor Beam
Written by Jason Booth (slipster216 at gmail)
Given away as part of a presentation at Unite 2015 in Boston, Ma.

Rendering particles and alpha objects can be expensive, usually due to overdraw. 
This system lets you render them to a smaller buffer, saving considerable fill rate.

The OffScreenParticleCamera component should be placed on your rendering camera, like
any other Image Effect. It can render a chosen layer into a 1/2, 1/4, or 1/8 buffer, and
upsample it into the main scene. You’ll need to use or write special shaders for your
materials; two are included as examples. The main difference between these and regular
shaders is that these shaders need to do premultiplied alpha, and do their own z-test
against the depth buffer. This is actually pretty simple, so look in the included shaders
if you want to modify your own shaders to work with the system.


How to run the demo

Open the test scene, hit play, and look around (WASD/Mouse Look). There are two things being rendered in the scene at 
1/4 resolution. One is a particle effect, the other a mist cloud that uses an example of the mist shader we use in 
StarTrek Timelines. The mist shader fades as the user nears or the mesh is viewed on-edge; this allows for more 
stability that using particles for this type of effect.

To blenchmark the speedup, change the "Factor" property on the Camera's OffScreenParticleCamera component to "Full",
and duplicate the particle systems until your frame rate starts to bog down. Now change the Factor to Quarter. 

How to integrate this into your project:
- Create a layer "Offscreen" in your project
- Add the OffScreenParticleCamera component to your camera and set its "downsample layer" property to your new layer
- Make sure your camera doesn't draw your new layer
- Use the included shaders on your effects or write your own, and put them into the offscreen layer


How this system works:
Putting this together, I read a lot of different techniques on the web, and there’s a ton of incomplete information 
out there. In the end, I created my own technique from what I had learned. It works like this:

    A second camera is created which mirrors your own. At post processing time, it down samples the depth buffer into a 
    smaller buffer. Note that many techniques do this in a multi-pass downsample which takes the min or max of 4 
    samples to better preserve the Z-values, but I found this actually made the quality worse and takes a lot more time. 
    So I just downsample straight to the final resolution.
    
    The particles z-test in the pixel shader vs. the high resolution depth buffer.
    
    When up sampling, I compare four samples from the low res depth buffer with the high res depth buffer, and choose 
    the sample which is closest to the hi-res depth buffer to use for the uv sample. We then test to see if we are near
    an edge, and use either the standard bilinear result, or the result from the nearest depth sample. If the depth
    difference is less than the threshold settings, we use the original sample position, which fixes other types of
    artifacts. This is a combination of techniques suggested in several papers which seems to work best.

The effect has minimal artifacts at 1/2 and 1/4 resolutions, but begins to show serious edging issues at 1/8 size. 
These may or may not matter, and playing with the threshold value can clean them up. My suggestion is to only worry
about it if you notice it in game play - in most games, these artifacts get covered by various other effects.


FAQ:
- Does it run on mobile!?
    Yes, it’s designed for mobile, actually. You’ll want to time it, of course, as running a post effect has a 
    pretty fixed time cost; you’ll need to be saving enough fill rate to make it worth it.

- Does it only work with particles?
    Nope, works with any alpha surfaces that have shaders written for it. The mist in the demo is a bunch of meshes.

- My game runs slower!
    The potential speedup of rendering particles at low resolutions comes at the cost of rendering a second camera
    and resolving that rendering back to the screen as part of a post processing effect. This can be quite costly,
    so the effect only runs faster if your saving enough fill rate to make up for the other costs. In our game, 
    we're drawing several dozen screens worth of overlapping particles, so the speedup is pronounced.

- Does it have any gotchas?
    Yes, because it’s drawn as a post processing effect, everything in the low-res layer will be drawn after everything 
    else. This means that by default it will draw over other alpha surfaces in your scene, and won’t interact with them 
    since they don’t write to the depth buffer. Your other option is to force the effect to draw before alpha, and have 
    it only draw behind other effects. 

    Also, shadows - if you use real-time shadows, unity may clear the z-buffer as part of the shadow rendering. I have
    not found an elegant way around this yet, so either don't use real time shadows or modify the code to capture the
    z-buffer at full resolution before shadows are rendered for later use. 


