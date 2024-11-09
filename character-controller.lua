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
m.CAMERA_OFFSET = Vec3()

local casting_shape = nil
local mx_prev, my_prev = lovr.system.getMousePosition()

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
    transform = Mat4(),
    position = Vec3(),
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
  local camera_pose = mat4(self.collider:getPosition())
    :translate(0, m.CAPSULE_HEIGHT / 3, 0)
    :rotate(self.yaw,   0, 1, 0)
    :rotate(self.pitch, 1, 0, 0)
    :translate(m.CAMERA_OFFSET)
  for i = 1, pass:getViewCount() do
    local pose = mat4(pass:getViewPose(i))
    pass:setViewPose(i, camera_pose * pose)
  end
end



function m:update(dt)
  local velocity = vec3()
  local position = vec3(self.collider:getPosition())

  local mx, my = lovr.system.getMousePosition()
  local dx = mx - mx_prev
  local dy = my - my_prev
  mx_prev, my_prev = mx, my
  self.dx = (self.dx - dx) * m.MOUSE_SMOOTHING + dx
  self.dy = (self.dy - dy) * m.MOUSE_SMOOTHING + dy
  self.yaw   = self.yaw   - self.dx * m.TURNING_SENSITIVITY
  self.pitch = self.pitch - self.dy * m.TURNING_SENSITIVITY

  if lovr.system.isKeyDown('w', 'up') then
    velocity:set(vec3.forward)
  elseif lovr.system.isKeyDown('s', 'down') then
    velocity:set(vec3.back)
  end
  if lovr.system.isKeyDown('a', 'left') then
    velocity:add(vec3.left)
  elseif lovr.system.isKeyDown('d', 'right') then
    velocity:add(vec3.right)
  end
  if lovr.system.isKeyDown('q', 'left') then
    velocity:add(vec3.up)
  elseif lovr.system.isKeyDown('e', 'right') then
    velocity:add(vec3.down)
  end
  if #velocity > 0 then
    local rot = quat(self.yaw,   0, 1, 0):mul(quat(self.pitch, 1, 0, 0))
    velocity = rot:mul(velocity)
    velocity.y = 0
    velocity:normalize()
    local speed = lovr.system.isKeyDown('lshift', 'rshift') and m.RUNNING_SPEED or m.WALKING_SPEED
    velocity:mul(speed)
  end
  velocity:add(0, -m.GRAVITY, 0)
  local floor_sense = position + vec3(0, -m.FLOOR_SENSE_DISTANCE, 0)
  local collider = self.world:shapecast(casting_shape, position, floor_sense, quat(-math.pi / 2, 1,0,0), '~character')
  --- keep up with the elevator beneath
  if collider and collider:isKinematic() then
    velocity:add(collider:getLinearVelocity())
  end
  self.on_ground = collider and true
  if self.on_ground and lovr.system.wasKeyPressed('space') then
    self.jump_time = m.JUMP_DURATION
  end
  if self.jump_time > 0 then
    self.jump_time = self.jump_time - dt
    velocity:add(0, m.JUMP_SPEED, 0)
  end
  self.collider:setLinearVelocity(velocity)
end


return m
