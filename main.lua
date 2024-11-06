local phywire = require'phywire'
local firstperson = require'firstperson'

firstperson.captureCursor(true)
-- for 3rd person camera: firstperson.CAMERA_OFFSET:set(0, 0.3, 1.5)

phywire.options.shapes_palette = {
  {0.184, 0.118, 0.102}, {0.310, 0.200, 0.133}, {0.447, 0.212, 0.153}, {0.584, 0.224, 0.173}, {0.780, 0.333, 0.200}, {0.906, 0.427, 0.275}, {0.576, 0.306, 0.157}, {0.635, 0.400, 0.235}, {0.784, 0.490, 0.251}, {0.961, 0.663, 0.357}, {0.420, 0.545, 0.549}, {0.506, 0.639, 0.557}, {0.667, 0.765, 0.620}, {1.000, 1.000, 1.000}, {0.820, 0.816, 0.808}, {0.729, 0.718, 0.698}, {0.537, 0.541, 0.541}, {0.408, 0.392, 0.380}, {0.333, 0.302, 0.294}, {0.235, 0.239, 0.231}, {0.204, 0.196, 0.188}, {0.529, 0.820, 0.937}, {0.392, 0.631, 0.761}, {0.275, 0.392, 0.502}, {0.184, 0.282, 0.361}, {0.141, 0.180, 0.208}, {0.106, 0.125, 0.149}, {0.667, 0.612, 0.541}, {0.569, 0.498, 0.427}, {0.525, 0.384, 0.290}, {0.443, 0.357, 0.282}, {0.369, 0.282, 0.208},
}

local world = lovr.physics.newWorld({
  allowSleep = false,
  maxPenetration = 5e-3,
  tags = {'torso'}
})
player = firstperson.new(world)

local floor = world:newBoxCollider(0, -1, 0,  50, 2, 50)
floor:setKinematic(true)

---[[ some crates
for i = 1, 100 do
  world:newBoxCollider(
    (math.random() - 0.5) * 30,
    20,
    (math.random() - 0.5) * 30,
    0.5, 0.5, 0.5)
end
--]]

---[[ maze
for x = 0, 7 do
  local slope = world:newBoxCollider(x - 4, x * 0.1, -1,  0.85, 0.2, 2)
  slope:setOrientation(x * 0.12, 1,0,0)
  slope:setKinematic(true)
end

 local maze = {
    {3, 2, 1, 3, 1, 1, 4, 3, 2, 1},
    {4, 0, 0, 0, 0, 0, 0, 0, 2, 2},
    {5, 0, 3, 3, 3, 0, 2, 0, 0, 3},
    {6, 0, 1, 0, 0, 0, 0, 0, 0, 2},
    {7, 0, 1, 0, 0, 0, 0, 0, 0, 1},
    {8, 0, 0, 0, 0, 0, 0, 0, 4, 2},
    {8, 3, 2, 2, 2, 3, 0, 0, 0, 3},
    {8, 7, 6, 5, 4, 4, 2, 0, 0, 2},
    {8, 3, 2, 2, 2, 3, 0, 4, 0, 3},
    {7, 5, 4, 3, 2, 1, 0, 0, 0, 1},
}

local mazeWidth = #maze[1]
local mazeHeight = #maze
local scale = 4.0
local offsetX = -(mazeWidth * scale) / 2 + scale / 2
local offsetY = -(mazeHeight * scale) / 2 + scale / 2

for y = 1, mazeHeight do
    for x = 1, mazeWidth do
        if maze[y][x] > 0 then
            local height = maze[y][x] / 3
            local wall = world:newBoxCollider(offsetX + (x - 1) * scale, height / 2, offsetY + (y - 1) * scale, scale, height, scale)
            wall:setKinematic(true)
        end
    end
end
--]]

function lovr.draw(pass)
  pass:setCullMode('back')
  player:setCamera(pass)
  phywire.draw(pass, world)
  player:draw(pass)
end

function lovr.update(dt)
  world:update(1 / 60)
end
