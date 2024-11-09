local character_controller = require'character-controller'

character_controller.captureCursor(true)
-- for 3rd person camera: character_controller.CAMERA_OFFSET:set(0, 0.5, 4)

local world = lovr.physics.newWorld({
  allowSleep = false,
  maxPenetration = 5e-3,
  tags = {'character'}
})


local gym_model = lovr.graphics.newModel('gym.glb')
local gym_collider = world:newMeshCollider(gym_model)

character = character_controller.new(world)
character:setBasePosition(-20, 0, -20)

local elevator = world:newBoxCollider(-20, 0, -10,  1, 0.1, 1)
elevator:setKinematic(true)

function lovr.update(dt)
  local t = lovr.timer.getTime()
  elevator:setLinearVelocity(0, math.sin(t), math.cos(t))
  character:update(dt)
  world:update(1 / 60)
end


function lovr.draw(pass)
  pass:setCullMode('back')
  character:setCamera(pass)
  pass:draw(gym_model)
  pass:box(vec3(elevator:getPosition()), vec3(elevator:getShape():getDimensions()))
end
