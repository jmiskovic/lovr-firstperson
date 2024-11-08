local m = {}
m.__index = m

m.CAPSULE_RADIUS = 0.1
m.CAPSULE_HEIGHT = 0.2
m.MOUSE_SMOOTHING = 0.3
m.TURNING_SENSITIVITY = 0.002
m.TURNING_SPEED = 60
m.WALKING_SPEED = 1.5
m.RUNNING_SPEED = 4
m.GRAVITY = 3
m.JUMP_SPEED = 20
m.MAX_SLIDING_BOUNCES = 8
m.SKIN_THICKNESS = 0.025
m.MAX_SLOPE_ANGLE = math.rad(55)
m.CAMERA_OFFSET = Vec3()

local casting_sphere = nil
local mx_prev, my_prev = lovr.system.getMousePosition()


local function V(pass, origin, target, color) -- visualize a vector
  local dir = target - origin
  pass:setColor(color or 0xf99157)
  pass:sphere(origin, 0.01)
  pass:line(origin, target)
  pass:cone(origin + vec3(dir):normalize():mul(#dir - 0.05), target, 0.01)
end


local function projectOnPlane(vector, planeNormal)
  planeNormal = planeNormal:normalize()
  local projection = vector:dot(planeNormal) * planeNormal
  return vector - projection
end


function m.captureCursor(enable)
  local cdef_initialized = package.loaded.ffi and true
  local ffi = require 'ffi'
  local C = ffi.os == 'Windows' and ffi.load('glfw3') or ffi.C
  if not cdef_initialized then
    ffi.cdef [[
      enum {
        GLFW_CURSOR = 0x00033001,
        GLFW_CURSOR_NORMAL = 0x00034001,
        GLFW_CURSOR_HIDDEN = 0x00034002,
        GLFW_CURSOR_DISABLED = 0x00034003,
        GLFW_ARROW_CURSOR = 0x00036001,
        GLFW_IBEAM_CURSOR = 0x00036002,
        GLFW_CROSSHAIR_CURSOR = 0x00036003,
        GLFW_HAND_CURSOR = 0x00036004,
        GLFW_HRESIZE_CURSOR = 0x00036005,
        GLFW_VRESIZE_CURSOR = 0x00036006
      };
      typedef struct GLFWwindow GLFWwindow;
      GLFWwindow* os_get_glfw_window(void);
      void glfwSetInputMode(GLFWwindow* window, int mode, int value);
    ]]
  end
  local window = ffi.C.os_get_glfw_window()
  C.glfwSetInputMode(window, C.GLFW_CURSOR, enable and C.GLFW_CURSOR_DISABLED or C.GLFW_CURSOR_NORMAL)
  local mx_prev, my_prev = lovr.system.getMousePosition()
end


function m.new(world)
  --casting_sphere = casting_sphere or lovr.physics.newSphereShape(m.CAPSULE_RADIUS - m.SKIN_THICKNESS)
  --local torso_collider = world:newSphereCollider(0, 1, 0, m.CAPSULE_RADIUS)
  casting_sphere = casting_sphere or lovr.physics.newCapsuleShape(m.CAPSULE_RADIUS - m.SKIN_THICKNESS, m.CAPSULE_HEIGHT - m.SKIN_THICKNESS)
  local torso_collider = world:newCapsuleCollider(0, 1, 0, m.CAPSULE_RADIUS, m.CAPSULE_HEIGHT)
  torso_collider:getShape():setOffset(0, 0, 0, -math.pi / 2, 1,0,0)
  torso_collider:setKinematic(true)
  torso_collider:setFriction(0)
  torso_collider:setTag('torso')

  local self = {
    world = world,
    torso_collider = torso_collider,
    transform = Mat4(),
    position = Vec3(),
    on_ground = false,
    upward_speed = 0,
    yaw = 0,
    pitch = 0,
    dx = 0,
    dy = 0,
  }
  return setmetatable(self, m)
end


function m:setCamera(pass)
  local camera_pose = mat4(self.torso_collider:getPosition())
    :translate(0, m.CAPSULE_HEIGHT / 3, 0)
    :rotate(self.yaw,   0, 1, 0)
    :rotate(self.pitch, 1, 0, 0)
    :translate(m.CAMERA_OFFSET)
  print(m.CAMERA_OFFSET)
  for i = 1, pass:getViewCount() do
    local pose = mat4(pass:getViewPose(i))
    pass:setViewPose(i, camera_pose * pose)
  end
  if self.on_ground then
    lovr.graphics.setBackgroundColor(0x202020)
  else
    lovr.graphics.setBackgroundColor(0,0,0)
  end
end


function m:collide_and_slide(position, trajectory, is_gravity_pass, recursion_depth, pass)
  if recursion_depth >= m.MAX_SLIDING_BOUNCES then
    return vec3()
  end
  pass:setDepthTest()

  local direction = vec3(trajectory):normalize()
  local target = position + direction * (#trajectory + m.SKIN_THICKNESS)
  local collider, shape, x, y, z, nx, ny, nz, triangle, fraction

  self.world:shapecast(casting_sphere,
    position, target, quat(-math.pi / 2, 1,0,0), '~torso',
    function(...)
      collider, shape, x, y, z, nx, ny, nz, triangle, fraction  = ...
      return 0
    end)

  if not collider then return trajectory end

  local distance_unobstructed = #trajectory * fraction
  local contact = vec3(x, y, z)


  local normal = vec3(nx, ny, nz)
  local trajectory_unobstructed = direction * (distance_unobstructed - m.SKIN_THICKNESS)
  local angle = normal:angle(vec3.up)

  if #trajectory_unobstructed <= m.SKIN_THICKNESS then
    trajectory_unobstructed:set(0, 0, 0)
  end

  if angle < m.MAX_SLOPE_ANGLE then
    self.on_ground = true
    if is_gravity_pass then
      return trajectory_unobstructed
    end
  end
  local leftover = trajectory - trajectory_unobstructed
  local sliding = projectOnPlane(leftover, normal)

  pass:setColor(0xec5f67); pass:sphere(x, y, z, 0.01)
  V(pass, position, position + trajectory_unobstructed, 0x6699cc)
  V(pass, position, position + trajectory, 0x1b2b34)
  V(pass, vec3(x, y, z), vec3(x, y, z) + normal, 0x0dc143)
  pass:text(string.format('%1.3f', angle), position + vec3(0,0.5,0), 0.05)
  pass:setColor(1,1,1,0.08)
  pass:sphere(position + trajectory_unobstructed, m.CAPSULE_RADIUS)
  return trajectory_unobstructed +
    self:collide_and_slide(position + trajectory_unobstructed, sliding, is_gravity_pass, recursion_depth + 1, pass)
end


function m:draw(pass) -- this should be m:update(dt), but at moment it needs to draw debug visuals
  local dt = lovr.timer.getDelta()
  if lovr.system.isKeyDown('f1') then
    local x, y, z = self.torso_collider:getPosition()
    self.torso_collider:setPosition(x, 3, z)
  end
  local mx, my = lovr.system.getMousePosition()
  local dx = mx - mx_prev
  local dy = my - my_prev
  mx_prev, my_prev = mx, my
  self.dx = (self.dx - dx) * m.MOUSE_SMOOTHING + dx
  self.dy = (self.dy - dy) * m.MOUSE_SMOOTHING + dy
  self.dx = math.min(m.TURNING_SPEED, math.max(-m.TURNING_SPEED, self.dx))
  self.dy = math.min(m.TURNING_SPEED, math.max(-m.TURNING_SPEED, self.dy))
  self.yaw   = self.yaw   - self.dx * m.TURNING_SENSITIVITY
  self.pitch = self.pitch - self.dy * m.TURNING_SENSITIVITY

  local torso_position = vec3(self.torso_collider:getPosition())
  local moving_speed = vec3()

  if lovr.system.isKeyDown('w', 'up') then
    moving_speed:set(vec3.forward)
  elseif lovr.system.isKeyDown('s', 'down') then
    moving_speed:set(vec3.back)
  end
  if lovr.system.isKeyDown('a', 'left') then
    moving_speed:add(vec3.left)
  elseif lovr.system.isKeyDown('d', 'right') then
    moving_speed:add(vec3.right)
  end
  if lovr.system.isKeyDown('q', 'left') then
    moving_speed:add(vec3.up)
  elseif lovr.system.isKeyDown('e', 'right') then
    moving_speed:add(vec3.down)
  end
  if #moving_speed > 0 then
    local rot = quat(self.yaw,   0, 1, 0):mul(quat(self.pitch, 1, 0, 0))
    moving_speed = rot:mul(moving_speed)
    moving_speed.y = 0
    moving_speed:normalize()
    local speed = m.WALKING_SPEED
    speed = lovr.system.isKeyDown('lctrl', 'rctrl') and 0.2 or speed
    speed = lovr.system.isKeyDown('lshift', 'rshift') and m.RUNNING_SPEED or speed
    moving_speed:mul(speed)
  end

  ---[[ gravity and jumping
  if self.on_ground and lovr.system.wasKeyPressed('space') then
    self.upward_speed = m.JUMP_SPEED
  end
  self.upward_speed = math.max(0, self.upward_speed - dt * m.GRAVITY)
  local gravity = vec3(0, -m.GRAVITY, 0)
  self.upward_speed = self.upward_speed + gravity.y
  moving_speed:add(0, self.upward_speed, 0)
  --]]

  local position = vec3(self.torso_collider:getPosition())
  self.on_ground = false
  local move_amount = self:collide_and_slide(position, moving_speed * dt, false, 0, pass)
  self.torso_collider:setLinearVelocity(move_amount / dt)
end


return m
