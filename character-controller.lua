local m = {}
m.__index = m

m.CAPSULE_HEIGHT = 1 -- the height doesn't include caps, total height is HEIGHT + 2 * RADIUS
m.CAPSULE_RADIUS = 0.3
m.MOUSE_SMOOTHING = 0.3
m.TURNING_SENSITIVITY = 0.002
m.WALKING_SPEED = 5
m.RUNNING_SPEED = 15
m.FRICTION = 1 -- affects the speeds
m.GRAVITY = 6
m.JUMP_SPEED = 15
m.JUMP_DURATION = 0.15
m.FLOOR_SENSE_DISTANCE = 0.2
m.CAMERA_OFFSET = vector()

local casting_shape = nil
local mx_prev, my_prev = lovr.system.getMousePosition()


function m.new(world)
  casting_shape = casting_shape or lovr.physics.newCapsuleShape(m.CAPSULE_RADIUS , m.CAPSULE_HEIGHT)
  local collider = world:newCapsuleCollider(0, 4, 0, m.CAPSULE_RADIUS, m.CAPSULE_HEIGHT)
  collider:getShape():setOffset(0, 0, 0, -math.pi / 2, 1,0,0)
  collider:setContinuous(true)
  collider:setDegreesOfFreedom('xyz', '')

  collider:setFriction(m.FRICTION)
  collider:setTag('character')

  local self = {
    world = world,
    collider = collider,
    transform = lovr.math.newMat4(),
    position = vector(),
    on_ground = false,
    jump_time = 0,
    upward_speed = 0,
    yaw = 0,
    pitch = 0,
    dx = 0,
    dy = 0,
  }
  return setmetatable(self, m)
end


function m:getBasePosition(x, y, z)
  local x, y, z = self.collider:getPosition()
  y = y - m.CAPSULE_HEIGHT / 2 - m.CAPSULE_RADIUS
  return x, y, z
end


function m:setBasePosition(x, y, z)
  self.collider:setPosition(x, y + m.CAPSULE_HEIGHT / 2 + m.CAPSULE_RADIUS, z)
end


function m:setCamera(pass)
  local camera_pose = lovr.math.newMat4(self.collider:getPosition())
    :translate(0, m.CAPSULE_HEIGHT / 3, 0)
    :rotate(self.yaw,   0, 1, 0)
    :rotate(self.pitch, 1, 0, 0)
    :translate(m.CAMERA_OFFSET)
  for i = 1, pass:getViewCount() do
    local pose = lovr.math.newMat4(pass:getViewPose(i))
    pass:setViewPose(i, camera_pose * pose)
  end
end



function m:update(dt)
  local velocity = vector(0)
  local position = vector(self.collider:getPosition())

  local mx, my = lovr.system.getMousePosition()
  local dx = mx - mx_prev
  local dy = my - my_prev
  mx_prev, my_prev = mx, my
  self.dx = (self.dx - dx) * m.MOUSE_SMOOTHING + dx
  self.dy = (self.dy - dy) * m.MOUSE_SMOOTHING + dy
  self.yaw   = self.yaw   - self.dx * m.TURNING_SENSITIVITY
  self.pitch = self.pitch - self.dy * m.TURNING_SENSITIVITY

  if lovr.system.isKeyDown('w', 'up') then
    velocity = vector.forward
  elseif lovr.system.isKeyDown('s', 'down') then
    velocity = vector.backward
  end
  if lovr.system.isKeyDown('a', 'left') then
    velocity = vector.left
  elseif lovr.system.isKeyDown('d', 'right') then
    velocity = vector.right
  end
  if lovr.system.isKeyDown('q', 'left') then
    velocity = vector.up
  elseif lovr.system.isKeyDown('e', 'right') then
    velocity = vector.down
  end
  if velocity:length() > 0 then
    local rot = quaternion(self.yaw, 0, 1, 0) * quaternion(self.pitch, 1, 0, 0)
    velocity = vector.normalize(rot * velocity * vector(1, 0, 1))
    local speed = lovr.system.isKeyDown('lshift', 'rshift') and m.RUNNING_SPEED or m.WALKING_SPEED
    velocity = velocity * speed
  end
  velocity = velocity + vector(0, -m.GRAVITY, 0)
  local floor_sense = position + vector(0, -m.FLOOR_SENSE_DISTANCE, 0)
  local collider = self.world:shapecast(casting_shape, position, floor_sense, quaternion(-math.pi / 2, 1,0,0), '~character')
  --- keep up with the elevator beneath
  if collider and collider:isKinematic() then
    velocity = velocity + collider:getLinearVelocity()
  end
  self.on_ground = collider and true
  if self.on_ground and lovr.system.wasKeyPressed('space') then
    self.jump_time = m.JUMP_DURATION
  end
  if self.jump_time > 0 then
    self.jump_time = self.jump_time - dt
    velocity = velocity + vector(0, m.JUMP_SPEED, 0)
  end
  self.collider:setLinearVelocity(velocity)
end


return m
