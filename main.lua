local character_controller = require'character-controller'

lovr.system.setMouseMode('relative')
-- for 3rd person camera: character_controller.CAMERA_OFFSET = vector(0, 0.5, 4)

local world = lovr.physics.newWorld({
  allowSleep = false,
  maxPenetration = 5e-3,
  tags = {'character'}
})


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
end
