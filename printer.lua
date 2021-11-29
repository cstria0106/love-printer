local utf8 = require('utf8')
local Object = require("classic")

local Printer = Object:extend()
local Text = Object:extend()
local PrinterHandle = Object:extend()
local Char = Object:extend()

local function mergeOptions(optionsList)
    local options = {}

    for _, o in ipairs(optionsList) do
        for key, value in pairs(o) do
            options[key] = value
        end
    end

    return options
end

function Printer:new(options)
    self.handles = {}
    self.options = options or {}

    self.options = mergeOptions({
        {
            defaultFont = love.graphics.getFont(),
        },
        self.options,
    })
end

function Printer:print(text, options)
    local handle = PrinterHandle(self, text, options)
    table.insert(self.handles, handle)
    return handle
end

function Printer:update(dt)
    for _, handle in ipairs(self.handles) do
        handle:update(dt)
    end
end

function Printer:draw()
    for _, handle in ipairs(self.handles) do
        handle:draw()
    end
end

function Printer:destroy(handle)
    for i = #self.handles, 1, -1 do
        if self.handles[i] == handle then
            table.remove(self.handles, i)
        end
    end
end

function Text:new(text, charOptions)
    self.text = text
    self.charOptions = charOptions
end

local function getUtf8Char(text, index)
    return text:sub(utf8.offset(text, index), utf8.offset(text, index + 1) - 1)
end

local function split(text, delimeter)
    if delimeter == nil then
        delimeter = "%s"
    end

    local splitted = {}

    for str in string.gmatch(text, "([^"..delimeter.."]+)") do
        table.insert(splitted, str)
    end

    return splitted
end

local function parse(text)
    local tokens = {}

    local index = 1
    local textLength = utf8.len(text)

    local bracketOpening = false
    local optionsList = {}
    local tokenContents = ""

    while index <= textLength do
        local char = getUtf8Char(text, index)
        if char == "[" then
            if bracketOpening then
                if #tokenContents > 0 then
                    error('unexpected token [')
                else
                    tokenContents = tokenContents .. "["
                    bracketOpening = false
                end
            else
                if index ~= 1 then
                    table.insert(tokens, Text(tokenContents, mergeOptions(optionsList)))
                end

                tokenContents = ""
                bracketOpening = true
            end
        elseif char == "]" and bracketOpening then
            if #tokenContents == 0 then
                if #optionsList > 0 then
                    table.remove(optionsList, #optionsList)
                else
                    error('no opened printer attribute bracket')
                end
            else
                local options = {}
                local splitted = split(tokenContents, "=")

                if #splitted == 1 then
                    options[splitted[1]] = true
                elseif #splitted == 2 then
                    options[splitted[1]] = splitted[2]
                end

                table.insert(optionsList, options)
            end

            bracketOpening = false

            tokenContents = ""
        else
            tokenContents = tokenContents .. getUtf8Char(text, index)
        end

        index = index + 1
    end

    if #optionsList ~= 0 then
        error('printer attribute bracket must be closed')
    end

    if #tokenContents > 0 then
        table.insert(tokens, Text(tokenContents, {}))
    end

    return tokens, utf8.len(text)
end

function PrinterHandle:new(printer, text, options)
    self.printer = printer
    self.targetTextList, self.targetTextFullLength = parse(text)
    self.options = options or {}
    self.time = 0
    self.delay = 0.1
    self.printedChars = {}
    self.lastChar = nil
    self.printedWidth = 0
    self.printedHeight = 0
end

function PrinterHandle:getNextChar()
    local char = getUtf8Char(self.targetTextList[1].text, 1)
    local delay = char == " " and 0 or self.delay

    return Char(
        self.printer,
        char,
        self.printedWidth + (self.options.x or 0),
        self.printedHeight + (self.options.y or 0),
        delay,
        self.targetTextList[1].charOptions
    )
end

function PrinterHandle:update(dt)
    self.time = self.time + dt

    while
        #self.targetTextList > 0 and
        self.time >= 0
    do
        local nextChar = self:getNextChar()

        self.time = self.time - nextChar.delay
        table.insert(self.printedChars, nextChar)

        local font = self.printer.options.defaultFont
        if nextChar.options.font then
            font = self.printer.options.fonts[nextChar.options.font]
        end

        self.printedWidth = self.printedWidth + font:getWidth(nextChar.char)

        if nextChar.char == "\n" then
            self.printedWidth = 0
            self.printedHeight = self.printedHeight + font:getHeight()
        end

        self.targetTextList[1].text = self.targetTextList[1].text:sub(#nextChar.char + 1)
        while #self.targetTextList > 0 and #self.targetTextList[1].text == 0 do
            table.remove(self.targetTextList, 1)
        end
        self.targetTextFullLength = self.targetTextFullLength - 1
    end

    for _, char in ipairs(self.printedChars) do
        char:update(dt)
    end
end

function PrinterHandle:draw()
    if self.options.font then
        love.graphics.setFont(self.options.font)
    end

    for _, char in ipairs(self.printedChars) do
        char:draw()
    end
end

function PrinterHandle:pause()
end

function PrinterHandle:destroy()
    self.printer.destroy(self)
end

local movementFunctions = {
    wiggle = function (time, speed, power)
        time = time * speed
        return math.cos(time) * power, math.sin(time) * power
    end
}

function Char:new(printer, char, x, y, delay, options)
    self.printer = printer
    self.char = char
    self.options = options or {}
    self.initX = x
    self.initY = y
    self.x = self.initX
    self.y = self.initY
    self.delay = delay
    self.time = 0

    if options.movement then
        self.movementFunction = movementFunctions[options.movement]
        self.movementSpeed = options.movementSpeed and tonumber(options.movementSpeed) or 1
        self.movementPower = options.movementPower and tonumber(options.movementPower) or 1
    end
end

function Char:update(dt)
    self.time = self.time + dt

    if self.movementFunction then
        local dx, dy = self.movementFunction(self.time, self.movementSpeed, self.movementPower)
        self.x = self.initX + dx
        self.y = self.initY + dy
    end
end

local function rgba(text)
    local r, g, b, a = text:sub(1, 2), text:sub(3, 4), text:sub(5, 6), #text == 8 and text:sub(7, 8) or 'ff'
    return {tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255}
end

function Char:draw()
    if self.options.color then
        love.graphics.setColor(rgba(self.options.color))
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    if self.options.font then
        love.graphics.setFont(self.printer.options.fonts[self.options.font])
    else
        love.graphics.setFont(self.printer.options.defaultFont)
    end

    love.graphics.print(self.char, self.x, self.y)
end

return Printer