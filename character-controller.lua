local m = {}
m.__index = m

m.CAPSULE_WIDTH = 0.3
m.CAPSULE_HEIGHT = 1.7
m.CROUCH_HEIGHT = 1.0
m.EYE_DROP = 0.05                     -- from head top to eye level
m.TURNING_SENSITIVITY = 0.001
m.WALKING_SPEED = 4
m.RUNNING_SPEED = 8
m.CROUCHING_SPEED = 2.5
m.ACCELERATION = 10
m.GROUND_FRICTION = 10
m.GRAVITY = 25
m.JUMP_HEIGHT = 1.28
m.MAX_SLOPE_ANGLE = 45
m.SKIN_WIDTH = 0.002

m.STEP_HEIGHT = m.CAPSULE_HEIGHT / 4
m.JUMP_SPEED = math.sqrt(2 * m.GRAVITY * m.JUMP_HEIGHT)
m.WALKABLE_NORMAL_Y = math.cos(math.rad(m.MAX_SLOPE_ANGLE))


local function slideVector(vec, normal)
  local dot = vec:dot(normal)
  return vec - normal * dot
end


local function shapeCast(world, posStart, posEnd, shape, orientation)
  local collider, _, _, _, _, nx, ny, nz, _, fraction =
    world:shapecast(shape, posStart, posEnd, orientation)
  if not collider then return nil end
  local moveDistance = (posEnd - posStart):length() * fraction
  local moveDirection = (posEnd - posStart):normalize()
  local movePosition = posStart + moveDirection * moveDistance
  local normal = vector(nx, ny, nz)
  -- shapecast normals can be unreliable, refine with an overlap query
  local hit, _, _, _, _, hnx, hny, hnz, _, _ = world:overlapShape(shape, movePosition, orientation, 0.04)
  if hit then normal = vector(hnx, hny, hnz) * -1 end
  return {
    collider = collider,
    normal = normal,
    fraction = fraction,
    movePosition = movePosition,
    moveDirection = moveDirection,
    moveDistance = moveDistance,
  }
end


function m.new(world)
  local mx, my = lovr.system.getMousePosition()
  local self = {
    world = world,
    pos = vector(0, 5, 0),
    vel = vector(),
    height = m.CAPSULE_HEIGHT,
    ground_normal = nil,
    ground_collider = nil,
    was_grounded = false,
    is_crouching = false,
    yaw = 0,
    pitch = 0,
    mx_prev = mx,
    my_prev = my,
  }
  self.stand_shape = lovr.physics.newCylinderShape(m.CAPSULE_WIDTH, m.CAPSULE_HEIGHT)
  self.stand_shape:setOffset(0, 0, 0, math.rad(90), 1, 0, 0)
  self.crouch_shape = lovr.physics.newCylinderShape(m.CAPSULE_WIDTH, m.CROUCH_HEIGHT)
  self.crouch_shape:setOffset(0, 0, 0, math.rad(90), 1, 0, 0)
  self.head_shape = lovr.physics.newCylinderShape(m.CAPSULE_WIDTH, m.CAPSULE_HEIGHT - m.CROUCH_HEIGHT)
  self.head_shape:setOffset(0, 0, 0, math.rad(90), 1, 0, 0)
  self.cast_shape = self.stand_shape
  return setmetatable(self, m)
end


function m:getBasePosition()
  local x, y, z = self.pos:unpack()
  return x, y - self.height / 2, z
end


function m:setBasePosition(x, y, z)
  self.pos = vector(x, y + self.height / 2, z)
end


function m:setCamera(pass)
  local camera_pose = lovr.math.newMat4(self.pos)
    :translate(0, self.height / 2 - m.EYE_DROP, 0)
    :rotate(self.yaw,   0, 1, 0)
    :rotate(self.pitch, 1, 0, 0)
    -- for 3rd person: :translate(0, 0.5, 4)
  for i = 1, pass:getViewCount() do
    local pose = lovr.math.newMat4(pass:getViewPose(i))
    pass:setViewPose(i, camera_pose * pose)
  end
end


function m:applyFriction(delta)
  local speed = vector(self.vel.x, 0, self.vel.z):length()
  if speed < 0.001 then
    self.vel.x = 0
    self.vel.z = 0
    return
  end
  local new_speed = math.max(speed - speed * m.GROUND_FRICTION * delta, 0)
  local scale = new_speed / speed
  self.vel.x *= scale
  self.vel.z *= scale
end


function m:accelerate(wishdir, wishspeed, accel, delta)
  local currentspeed = self.vel.x * wishdir.x + self.vel.z * wishdir.z
  local addspeed = wishspeed - currentspeed
  if addspeed <= 0 then return end
  local accelspeed = math.min(accel * wishspeed * delta, addspeed)
  self.vel.x += accelspeed * wishdir.x
  self.vel.z += accelspeed * wishdir.z
end


function m:slideMove(move, iteration, planes)
  iteration = (iteration or 0) + 1
  planes = planes or {}
  if iteration > 5 or move:length() < 0.001 then
    return vector(self.pos), planes
  end
  local orientation = quaternion.angleaxis(self.cast_shape:getOrientation())
  local ray = shapeCast(self.world, self.pos, self.pos + move, self.cast_shape, orientation)
  if not ray then
    self.pos = self.pos + move
    return vector(self.pos), planes
  end
  local hit_fraction = 0
  local distance = move:length()
  if distance > 0.001 then hit_fraction = ray.moveDistance / distance end
  self.pos = ray.movePosition + ray.normal * m.SKIN_WIDTH
  local leftover = move * (1 - hit_fraction)
  local slid = slideVector(leftover, ray.normal)
  table.insert(planes, ray.normal)
  for _, n in ipairs(planes) do
    if slid:dot(n) < 0 then slid = slideVector(slid, n) end
  end
  local max_length = leftover:length()
  if slid:length() > max_length then slid = slid:normalize() * max_length end
  if slid:length() < 0.001 then return vector(self.pos), planes end
  return self:slideMove(slid, iteration, planes)
end


function m:tryStepMove(move, was_grounded)
  if not was_grounded then return nil end
  local start = vector(self.pos)
  local orientation = quaternion.angleaxis(self.cast_shape:getOrientation())
  local up = shapeCast(self.world, self.pos, self.pos + vector(0, m.STEP_HEIGHT, 0), self.cast_shape, orientation)
  if up then return nil end
  self.pos = self.pos + vector(0, m.STEP_HEIGHT, 0)
  self:slideMove(move)
  local stepped = vector(self.pos) - start
  stepped.y = 0
  local wanted = vector(move.x, 0, move.z)
  if stepped:length() < wanted:length() * 0.5 then
    self.pos = start
    return nil
  end
  local down = shapeCast(self.world, self.pos, self.pos - vector(0, m.STEP_HEIGHT * 3, 0), self.cast_shape, orientation)
  if down and down.normal.y > m.WALKABLE_NORMAL_Y then
    self.pos = down.movePosition + down.normal * m.SKIN_WIDTH
    return down.normal
  end
  self.pos = start
  return nil
end


function m:iterateMovement(move, delta)
  local start = vector(self.pos)
  self.ground_normal = nil
  local slid_pos, slide_planes = self:slideMove(move)
  local slide_ground = self.ground_normal
  self.pos = start
  self.ground_normal = nil
  local step_ground = nil
  if self.was_grounded and move.y <= 0.001 then
    step_ground = self:tryStepMove(move, self.was_grounded)
  end
  if step_ground and not slide_ground then
    self.ground_normal = step_ground
  else
    self.pos = slid_pos
    self.ground_normal = slide_ground
    for _, n in ipairs(slide_planes or {}) do
      if n.y <= m.WALKABLE_NORMAL_Y then
        local into = self.vel:dot(n)
        if into < 0 then self.vel = self.vel - n * into end
      end
    end
  end
end


function m:setCrouching(want_crouch)
  if want_crouch == self.is_crouching then return end
  local bottom = self.pos.y - self.height / 2
  local fits = true
  if not want_crouch then
    local head_pos = vector(self.pos.x, bottom + (m.CAPSULE_HEIGHT + m.CROUCH_HEIGHT) / 2, self.pos.z)
    local blocked = self.world:overlapShape(self.head_shape, head_pos, quaternion.angleaxis(self.head_shape:getOrientation()), 0)
    fits = blocked == nil
  end
  if not fits then return end
  self.height = want_crouch and m.CROUCH_HEIGHT or m.CAPSULE_HEIGHT
  self.cast_shape = want_crouch and self.crouch_shape or self.stand_shape
  self.pos = vector(self.pos.x, bottom + self.height / 2, self.pos.z)
  self.is_crouching = want_crouch
end


function m:update(delta)
  local mx, my = lovr.system.getMousePosition()
  local dx = mx - self.mx_prev
  local dy = my - self.my_prev
  self.mx_prev, self.my_prev = mx, my
  self.yaw   = self.yaw   - dx * m.TURNING_SENSITIVITY
  self.pitch = self.pitch - dy * m.TURNING_SENSITIVITY

  local input_vel = vector()
  if lovr.system.isKeyDown('w', 'up') then
    input_vel = input_vel + vector.forward
  elseif lovr.system.isKeyDown('s', 'down') then
    input_vel = input_vel + vector.backward
  end
  if lovr.system.isKeyDown('a', 'left') then
    input_vel = input_vel + vector.left
  elseif lovr.system.isKeyDown('d', 'right') then
    input_vel = input_vel + vector.right
  end
  input_vel = input_vel:normalize()

  local camera_quat = quaternion(self.yaw, 0, 1, 0) * quaternion(self.pitch, 1, 0, 0)
  local forward = camera_quat * vector(0, 0, -1)
  forward.y = 0
  forward = forward:normalize()
  local left = camera_quat * vector(-1, 0, 0)
  left.y = 0
  left = left:normalize()
  input_vel = forward * -input_vel.z + left * -input_vel.x

  self:setCrouching(lovr.system.isKeyDown('c', 'lctrl'))

  local grounded = self.ground_normal ~= nil
  self.was_grounded = grounded
  if grounded then self.vel.y = 0 end

  local will_jump = grounded and not self.is_crouching and lovr.system.wasKeyPressed('space')

  local wishdir = input_vel
  local wishspeed = wishdir:length()
  if wishspeed > 0.001 then wishdir = wishdir:normalize() end
  local running = lovr.system.isKeyDown('lshift', 'rshift')
  local max_speed = self.is_crouching and m.CROUCHING_SPEED or (running and m.RUNNING_SPEED or m.WALKING_SPEED)
  if grounded then
    if not will_jump then self:applyFriction(delta) end
    self:accelerate(wishdir, max_speed, m.ACCELERATION, delta)
  else
    self:accelerate(wishdir, max_speed * 0.3, m.ACCELERATION, delta)
  end
  if will_jump then self.vel.y = m.JUMP_SPEED end
  self.vel.y = self.vel.y - m.GRAVITY * delta

  -- ride along with moving kinematic colliders
  if self.ground_collider and self.ground_collider:isKinematic() then
    local ground_velocity = vector(self.ground_collider:getLinearVelocity())
    self.pos = self.pos + ground_velocity * delta
  end

  local move = self.vel * delta
  self:iterateMovement(move, delta)

  self.ground_collider = nil
  if self.vel.y <= 0.001 then
    local orientation = quaternion.angleaxis(self.cast_shape:getOrientation())
    local ray = shapeCast(self.world, self.pos, self.pos + vector(0, -0.05, 0), self.cast_shape, orientation)
    if ray and ray.normal.y > m.WALKABLE_NORMAL_Y then
      self.pos.y = ray.movePosition.y + ray.normal.y * m.SKIN_WIDTH
      self.ground_normal = ray.normal
      self.ground_collider = ray.collider
    end
  end

  local just_landed = (not grounded) and (self.ground_normal ~= nil)
  if self.ground_normal and self.vel.y < 0 then
    if just_landed then
      self.vel = slideVector(self.vel, self.ground_normal)
      if self.vel.y > 0 then self.vel.y = 0 end
    end
  end
end


return m
