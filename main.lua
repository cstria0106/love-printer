local Printer = require("printer")

local fonts = {}
local printer = nil
local spaceDown = false

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')

    local myungjo16 = love.graphics.newFont('myungjo.ttf', 16, 'mono')
    local myungjo18 = love.graphics.newFont('myungjo.ttf', 18, 'mono')
    local myungjo20 = love.graphics.newFont('myungjo.ttf', 20, 'mono')
    local myungjo22 = love.graphics.newFont('myungjo.ttf', 22, 'mono')
    local gulim = love.graphics.newFont('gulim.ttf', 11, 'mono')
    
    fonts['myungjo16'] = myungjo16
    fonts['myungjo18'] = myungjo18
    fonts['myungjo20'] = myungjo20
    fonts['myungjo22'] = myungjo22

    printer = Printer({
        fonts = fonts,
        defaultFont = gulim
    })
end

function love.update(dt)
    if love.keyboard.isDown("space") then
        if spaceDown == false then
            local exampleText = love.filesystem.read('example.txt')
            printer:print(exampleText, {
                x = 0,
                y = 0
            })
            spaceDown = true
        end
    else
        spaceDown = false
    end

    printer:update(dt)
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(2, 2)

    printer:draw()

    love.graphics.pop()
end