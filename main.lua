local character_controller = require'character-controller'

lovr.system.setMouseMode('relative')

local world = lovr.physics.newWorld()

local gym = lovr.data.newModelData('gym.glb')
local gym_model = lovr.graphics.newModel(gym)
local gym_collider = world:newMeshCollider(gym)

character = character_controller.new(world)
character:setBasePosition(-20, 0, -20)

local elevator = world:newBoxCollider(-20, 0, -10,  1, 0.1, 1)
elevator:setKinematic(true)

timestep = 1/60
time = 0

function lovr.update(dt)
  local t = lovr.timer.getTime()
  elevator:setLinearVelocity(0, math.sin(t), math.cos(t))
  character:update(dt)
  time = time + dt
  while time >= timestep do
    world:update(timestep)
    time = time - timestep
  end
  world:interpolate(time / timestep)
end


function lovr.draw(pass)
  pass:setFaceCull('back')
  character:setCamera(pass)
  pass:draw(gym_model)
  pass:box(vector(elevator:getPosition()), vector(elevator:getShape():getDimensions()))
  -- player geometry: pass:cylinder(character.pos - vector(0, character.height / 2, 0), character.pos + vector(0, character.height / 2, 0), character_controller.CAPSULE_WIDTH)
end
