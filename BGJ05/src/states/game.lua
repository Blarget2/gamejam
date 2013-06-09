require("util/gamestate")
require("util/resources")

require("scene/world")

require("entities/background")
require("entities/building")
require("entities/wisp")
require("entities/lamp-chain")
require("entities/lamp-static")
require("entities/lamp-antenna")
require("entities/lamp-airplane")
require("entities/lamp-star")

Game = class("Game", GameState)

function Game:__init()
    self.keyHelpOpacity = 1
    self:reset()
end

function Game:reset()
    self.world = World()
    self.wisp = Wisp()
    self.wisp.position = Vector(-10, -100)
    self.world:add(self.wisp)

    local lampstatic = LampStatic()
    lampstatic.position = Vector(0, -200)
    lampstatic.energyDrainSpeed = 0
    self.world:add(lampstatic)

    -- local lampantenna = LampAntenna()
    -- lampantenna.position = Vector(-200, -200)
    -- self.world:add(lampantenna)

    -- local lampairplane = LampAirplane()
    -- lampairplane.position = Vector(0, -500)
    -- self.world:add(lampairplane)

    -- local lampstar = LampStar()
    -- lampstar.position = Vector(0, -600)
    -- self.world:add(lampstar)

    self.generatedUntil = -SIZE.x*5

    self.zoom = 1
    self.paused = false
    self.gameOver = false
    self.gameOverTimer = 0
    self.score = 0
    self.bellStreak = 0
    self.bellTimeout = 0

    self.camCenter = Vector(0, -300)
    self.maxCamX = self.camCenter.x
end

function Game:getKeyboardVector()
    local v = Vector()
    if love.keyboard.isDown("left")  then v.x = v.x - 1 end
    if love.keyboard.isDown("right") then v.x = v.x + 1 end
    if love.keyboard.isDown("up")    then v.y = v.y - 1 end
    if love.keyboard.isDown("down")  then v.y = v.y + 1 end
    return v:normalized()
end

function Game:onUpdate(dt)
    if self.paused then return end

    if not self.gameOver then
        self.score = math.floor(self.maxCamX/10)*10
    end

    self.bellTimeout = self.bellTimeout - dt
    if self.bellTimeout < 0 then
        self.bellStreak = 0
    end

    self.wisp:move(self:getKeyboardVector())

    self.keyHelpOpacity = math.max(0, self.keyHelpOpacity - dt / 10)

    -- generate full view and a bit (GENEREATE_AHEAD)
    local ahead = GENERATE_AHEAD / self.zoom
    while self.wisp.position.x + ahead > self.generatedUntil do
        self:generateWorld()
    end

    for k,v in pairs(self.world.entities) do
        if v.__name ~= "Wisp" and v.position.x + (v.size and v.size.x or 0) < self.camCenter.x - SIZE.x/MIN_ZOOM * 2 then
            v:kill()
        end
    end

    self.world:update(dt)

    if self.wisp.position.y > SIZE.y / 2 / self.zoom then
        self.gameOver = true
    end

    if self.wisp.position.x < self.camCenter.x - SIZE.x/2/self.zoom then
        self.gameOver = true
    end

    if self.gameOver then
        for k,v in pairs(self.world:findByType("Lamp", true)) do
            v:burnout(true)
        end

        self.gameOverTimer = self.gameOverTimer + dt
    end

    local zoomSpeed = 400 / (Vector(self.wisp.physicsObject.body:getLinearVelocity()):len() or 1)
    local zoomHeight = self.wisp.position.y < 0 and (SIZE.y-150)/-self.wisp.position.y/2 or zoomSpeed
    local zoomSpeed = 0.7
    local zoom = math.min(zoomSpeed, zoomHeight) * (zoomSpeed*dt) + self.zoom * (1-zoomSpeed*dt)
    self.zoom = math.min(MAX_ZOOM, math.max(MIN_ZOOM, zoom))
end

function Game:generateWorld()
    local x = self.generatedUntil
    local w = math.random(4, 10) * 50
    local h = randf(500, MAX_HEIGHT)
    self.world:add(Building(x, Vector(w, h)))

    if math.random(0, 2) <= 0 then
        local airplane = LampAirplane()
        airplane.position = Vector(x + w, -randf(1000, 5000))
        self.world:add(airplane)
    end

    for i=0,4 do
        local starlamp = LampStar()
        starlamp.position = Vector(x + randf()*w, -randf(3000, 30000))
        self.world:add(starlamp)
    end

    self.generatedUntil = x + w * randf(1.0, 4)

    local bx = x

    if x > 200 then
        while x < self.generatedUntil do
            local lamp = LampStatic()
            lamp.position = Vector(x, -300) --randf(-100, -500))
            self.world:add(lamp)
            x = x + randf(600, 1000)
        end
    end

    while bx < self.generatedUntil do
        self.world:add(Background(bx))
        bx = bx + randf(20, 90)/3
    end
end

function Game:onDraw()
    LIGHT_CANVAS:clear(0, 0, 0)

    love.graphics.setBackgroundColor(20, 10, 50)
    love.graphics.clear()

    love.graphics.setBackgroundColor(255, 255, 255)
    love.graphics.draw(resources.images.sky, 0, 0, 0, (HALFSIZE):unpack())

    local wp = Vector(self.wisp.position:unpack())
    local s = SIZE/3/2

    if wp.x < self.camCenter.x - s.x then self.camCenter.x = wp.x + s.x
    elseif wp.x > self.camCenter.x + s.x then self.camCenter.x = wp.x - s.x
    end

    if wp.y < self.camCenter.y - s.y then self.camCenter.y = wp.y + s.y
    elseif wp.y > self.camCenter.y + s.y then self.camCenter.y = wp.y - s.y
    end

    self.camCenter.y = math.min(self.camCenter.y, (-HALFSIZE.y+150)/self.zoom)
    self.maxCamX = math.max(self.camCenter.x, self.maxCamX)
    self.camCenter.x = math.max(self.maxCamX - SIZE.x, self.camCenter.x)

    TRANSLATION = -(self.camCenter - HALFSIZE)
    love.graphics.push()
    love.graphics.translate(HALFSIZE:unpack())
    love.graphics.scale(self.zoom)
    love.graphics.translate((-self.camCenter):unpack())

    -- ground
    for i=3,1,-1 do
        local a = 10 + 10 * i
        love.graphics.setColor(unpack(BACKGROUND_COLORS[i]))
        love.graphics.rectangle("fill", self.camCenter.x - HALFSIZE.x/self.zoom, -100-100*i, SIZE.x/self.zoom, 500)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", self.camCenter.x - HALFSIZE.x/self.zoom, 0, SIZE.x/self.zoom, SIZE.y/self.zoom)

    self.world:draw()

    love.graphics.pop()
    TRANSLATION = Vector()

    -- lights
    drawLights()

    -- help
    TRANSLATION = -(self.camCenter - HALFSIZE)
    love.graphics.push()
    love.graphics.translate(HALFSIZE:unpack())
    love.graphics.scale(self.zoom)
    love.graphics.translate((-self.camCenter):unpack())

    --love.graphics.setColor(255, 255, 255)
    --love.graphics.draw(resources.images.left, -SIZE.x, center.y-HALFSIZE.y, 0, SIZE.x, SIZE.y)

    love.graphics.setColor(255, 255, 255, 255 * self.keyHelpOpacity)
    local ax, ay, s = 0, -400, resources.images.key_arrow:getWidth() * 0.5 + 4
    love.graphics.draw(resources.images.key_arrow, ax,   ay,   math.pi * 0.5, 0.5, 0.5, resources.images.key_arrow:getWidth()/2, resources.images.key_arrow:getHeight()/2)
    love.graphics.draw(resources.images.key_arrow, ax+s, ay+s, math.pi * 1.0, 0.5, 0.5, resources.images.key_arrow:getWidth()/2, resources.images.key_arrow:getHeight()/2)
    love.graphics.draw(resources.images.key_arrow, ax,   ay+s, math.pi * 1.5, 0.5, 0.5, resources.images.key_arrow:getWidth()/2, resources.images.key_arrow:getHeight()/2)
    love.graphics.draw(resources.images.key_arrow, ax-s, ay+s, math.pi * 0.0, 0.5, 0.5, resources.images.key_arrow:getWidth()/2, resources.images.key_arrow:getHeight()/2)

    love.graphics.pop()
    TRANSLATION = Vector()

    local p = 1 - math.pow(1-math.min(1, self.gameOverTimer * 2 - 1), 3)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(resources.images.key_space, SIZE.x / 2, SIZE.y - p * 100,
        0.0, 0.5, 0.5, resources.images.key_space:getWidth() / 2, 0)

    love.graphics.setFont(resources.fonts.big)
    love.graphics.printf("Game Over", 0, p * 100, SIZE.x, "center")

    -- debug info
    love.graphics.setFont(resources.fonts.medium)
    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Score " .. string.gsub(""..self.score, "0", "O"), 10, 10)

    -- pause screen
    if self.paused then
        love.graphics.setColor(0, 0, 0, 200)
        love.graphics.rectangle("fill", 0, 0, SIZE.x, SIZE.y)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(resources.fonts.big)
        love.graphics.printf("Game paused", 0, SIZE.y/3, SIZE.x, "center")

        local scale = 0.5
        local s = resources.images.key_f:getWidth() * scale
        local x = SIZE.x / 2
        local y = SIZE.y / 2

        love.graphics.setFont(resources.fonts.normal)

        love.graphics.draw(resources.images.key_esc, x-0.25*s, y, 0, scale, scale, s/scale, s/scale*0.5)
        love.graphics.print("Continue", x+0.25*s, y - love.graphics.getFont():getHeight() / 2)
        y = y + s * 1.5

        love.graphics.draw(resources.images.key_q, x-0.25*s, y, 0, scale, scale, s/scale, s/scale*0.5)
        love.graphics.print("Quit", x+0.25*s, y - love.graphics.getFont():getHeight() / 2)
        y = y + s * 1.5

    end
end

function Game:onKeyPressed(k, u)
    if k == "escape" then
        self.paused = not self.paused
    elseif k == "q" then
        stack:pop()
    elseif k == " " then
        if self.gameOver then
            self:reset()
        else
            self.wisp:jump(self:getKeyboardVector())
        end
    end
end
