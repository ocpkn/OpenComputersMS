--Lots of variable declarations
local component = require("component")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local term = require("term")
local keyboard = require("keyboard")
local gpu = component.gpu
local w, h = gpu.getResolution()
local maxw, maxh = gpu.maxResolution()
local b = {gpu.getBackground()}
local f = {gpu.getForeground()}
 
local tilecolors = {
    [true] = {
        [0] = {fore = 7, back = 15},
        [1] = {fore = 9, back = 15},
        [2] = {fore = 5, back = 15},
        [3] = {fore = 6, back = 15},
        [4] = {fore = 2, back = 15},
        [5] = {fore = 14, back = 15},
        [6] = {fore = 3, back = 15},
        [7] = {fore = 0, back = 15},
        [8] = {fore = 8, back = 15},
        empty = {fore = 15, back = 7},
        flag = {fore = 14, back = 7},
        mine = {fore = 0, back = 14},
        falseMine = {fore = 14, back = 15},
        unflaggedMine = {fore = 0, back = 15},
        board = {fore = 8, back = 15},
        smiley = {fore = 4, back = 15}
    },
    [false] = {
        [0] = {fore = 8, back = 0},
        [1] = {fore = 11, back = 0},
        [2] = {fore = 13, back = 0},
        [3] = {fore = 14, back = 0},
        [4] = {fore = 10, back = 0},
        [5] = {fore = 12, back = 0},
        [6] = {fore = 9, back = 0},
        [7] = {fore = 15, back = 0},
        [8] = {fore = 7, back = 0},
        empty = {fore = 0, back = 8},
        flag = {fore = 14, back = 8},
        mine = {fore = 15, back = 14},
        falseMine = {fore = 14, back = 0},
        unflaggedMine = {fore = 15, back = 0},
        board = {fore = 7, back = 0},
        smiley = {fore = 1, back = 0}
    }
}
 
local tilechars = {
    [0] = " ",
    [1] = "1",
    [2] = "2",
    [3] = "3",
    [4] = "4",
    [5] = "5",
    [6] = "6",
    [7] = "7",
    [8] = "8",
    empty = " ",
    flag = unicode.char(0x25BA),
    mine = unicode.char(0x25CF),
    falseMine = unicode.char(0x25CF),
    unflaggedMine = unicode.char(0x25CF),
    cleared = unicode.char(0x258C, 32, 0x2590)
}
 
local board, key = {}, {}
local flgs, clrd = 0, 0
local running, darkmode, noGuess, timerMode = false, false, false, false
local gameState = 0
local rows, cols, mines = 0, 0, 0
local resX, resY = 0, 0
local timerId, time, timerLength = 0, 0, 0
 
function updateMineCount()
    setColors("falseMine")
    gpu.set(2, 2, string.format("%03d", mines - flgs))
end
 
function setColors(char)
    gpu.setBackground(tilecolors[darkmode][char].back, true)
    gpu.setForeground(tilecolors[darkmode][char].fore, true)
end
 
function placeClear(r, c, char)
    gpu.setBackground(tilecolors[darkmode][char].back, true)
    gpu.setForeground(tilecolors[darkmode]["board"].back, true)
    gpu.set(c * 4 - 2, r * 2 + 3, tilechars.cleared)
end
 
function placeChar(r, c, char)
    placeClear(r, c, char)
    setColors(char)
    gpu.set(c * 4 - 1, r * 2 + 3, tilechars[char])
end
 
function inBounds(r, c)
    return r > 0 and c > 0 and r <= rows and c <= cols
end
 
function addMines(r, c)
    local m = 0
    while m < mines do
        local randR = math.random(1, rows)
        local randC = math.random(1, cols)
        if key[randR][randC] ~= "mine" and (math.abs(randR - r) > 1 or math.abs(randC - c) > 1) then
            key[randR][randC] = "mine"
            m = m + 1
            for i = -1, 1 do
                for j = -1, 1 do
                    local dr, dc = randR + i, randC + j
                    if (i ~= 0 or j ~= 0) and inBounds(dr, dc) and key[dr][dc] ~= "mine" then
                        key[dr][dc] = key[dr][dc] + 1
                    end
                end
            end
        end
    end
end
--clears a tile on the board
function clearTile(r, c)
    if board[r][c] == "empty" then
        if clrd == 0 and noGuess then
            addMines(r, c)
        end
        board[r][c] = key[r][c]
        placeChar(r, c, board[r][c])
        clrd = clrd + 1
        if board[r][c] == 0 then
            clearAdj(r, c)
        end
    elseif tonumber(board[r][c]) then
        local adjFlgs = 0
        for i = -1, 1 do
            for j = -1, 1 do
                if inBounds(r + i, c + j) and board[r + i][c + j] == "flag" then
                    adjFlgs = adjFlgs + 1
                end
            end
        end
        if adjFlgs == tonumber(board[r][c]) then
            clearAdj(r, c)
        end
    end
    if gameState == 0 then
        if board[r][c] == "mine" then
            gameState = 1
        elseif clrd == rows * cols - mines then
            gameState = 2
        end
    end
end
--clears tiles adjacent to a given tile, called only when a tile with 0 adjacent mines is cleared
function clearAdj(r, c)
    for i = -1, 1 do
        for j = -1, 1 do
            if (i ~= 0 or j ~= 0) and inBounds(r + i, c + j) and board[r + i][c + j] == "empty" then
                clearTile(r + i, c + j)
            end
        end
    end
end
--Function which flags or unflags a tile
function flagTile(r, c)
    if board[r][c] == "empty" then
        board[r][c] = "flag"
        flgs = flgs + 1
    elseif board[r][c] == "flag" then
        board[r][c] = "empty"
        flgs = flgs - 1
    end
    placeChar(r, c, board[r][c])
    updateMineCount()
end
 
function gameover()
    event.cancel(timerId)
    if gameState == 1 then
        for i = 1, rows do
            for j = 1, cols do
                if key[i][j] == "mine" then
                    if board[i][j] == "empty" then
                        placeChar(i, j, "unflaggedMine")
                    end
                elseif board[i][j] == "flag" then
                    placeChar(i, j, "falseMine")
                end
            end
        end
        setColors("smiley")
        gpu.set(math.floor(resX / 2), 2, "X^(")
    elseif gameState == 2 then
        for i = 1, rows do
            for j = 1, cols do
                if key[i][j] == "mine" and board[i][j] == "empty" then
                    placeChar(i, j, "flag")
                end
            end
        end
        flgs = mines
        updateMineCount()
        setColors("smiley")
        gpu.set(math.floor(resX / 2), 2, "B^]")
    end
end
 
function detectClick(_, _, x, y, b)
    if x > resX / 2 - 2 and x < resX / 2 + 3 and y < 4 then
        event.push("restart")
    elseif running then
        running = false
        if clrd == 0 then
            updateTimer()
            timerId = event.timer(1, updateTimer, 998)
        end
        local r = math.floor((y - 2) / 2)
        local c = math.floor((x + 3) / 4)
        if inBounds(r, c) then
            if b == 0 then
                clearTile(r, c)
            else
                flagTile(r, c)
            end
        end
 
        if gameState ~= 0 then
            gameover()
        else
            running = true
        end
    end
end
 
function updateTimer()
    if timerMode and time == -1 and running then
        running = false
        gameState = 1
        gameover()
    else
        setColors("falseMine")
        gpu.set(resX - 3, 2, string.format("%03d", time))
        time = time + (timerMode and -1 or 1)
    end
end
 
function handleKeyDown(_, _, _, key)
    if key == 0x10 then
        event.push("exit")
    elseif key == 0x0E then
        event.push("restart")
    end
end
 
local md = gpu.maxDepth()
if md > 1 then
    gpu.setDepth(4)
else
    io.stderr:write("Requires tier 2 screen and GPU")
    return 1
end
 
local args, options = shell.parse(...)
 
rows, cols, mines = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
 
if options.d then
    darkmode = true
end
 
if options.n then
    noGuess = true
end
 
if options.t then
    timerMode = true
    timerLength = tonumber(options.t)
end
 
if not rows or not cols or not mines or (options.t and not timerLength) then
    io.write("Usage: minesweeper [options] <rows> <columns> <mines>\n")
    io.write(" -d: Dark mode.\n")
    io.write(" -n: No guessing.\n")
    io.write(" --t=<seconds>: Timer mode.\n")
    return
end
 
resX, resY = cols * 4 + 1, rows * 2 + 4
 
local error = false
 
if rows < 4 or resY > maxh then
    io.stderr:write("Height too " .. (rows < 4 and "small" or "large") .. "\n")
    error = true
end
 
if cols < 4 or resX > maxw then
    io.stderr:write("Width too " .. (cols < 4 and "small" or "large") .. "\n")
    error = true
end
    
if mines > rows * cols - (noGuess and 9 or 1) or mines > 999 then
    io.stderr:write("Too many mines\n")
    error = true
end
 
if options.t and (timerLength > 999 or timerLength < 1) then
    io.stderr:write("Timer too " .. (timerLength < 1 and "short" or "long") .. "\n")
    error = true
end
 
if error then return end
 
gpu.setResolution(resX, resY)
 
setColors("board")
gpu.fill(1, 1, resX, resY, " ")
 
gpu.set(1, 1, unicode.char(9556, 9552, 9552, 9552, 9559))
gpu.set(1, 2, unicode.char(9553, 32, 32, 32, 9553))
gpu.set(1, 3, unicode.char(9562, 9552, 9552, 9552, 9565))
 
gpu.copy(1, 1, 5, 3, resX - 5, 0)
gpu.copy(1, 1, 5, 3, math.floor(resX / 2) - 2, 0)
 
for r = 1, rows * 2 + 1 do
    gpu.set(
        1,
        r + 3,
        r % 2 == 0 and string.rep(unicode.char(0x2551), cols + 1, "   ") or
            (r == 1 and
                unicode.char(0x2554) ..
                    string.rep(unicode.char(0x2550, 0x2550, 0x2550), cols, unicode.char(0x2566)) .. unicode.char(0x2557) or
                (r == rows * 2 + 1 and
                    unicode.char(0x255A) ..
                        string.rep(unicode.char(0x2550, 0x2550, 0x2550), cols, unicode.char(0x2569)) ..
                            unicode.char(0x255D) or
                    unicode.char(0x2560) ..
                        string.rep(unicode.char(0x2550, 0x2550, 0x2550), cols, unicode.char(0x256C)) ..
                            unicode.char(0x2563)))
    )
end
 
event.listen("touch", detectClick)
event.listen("key_down", handleKeyDown)
 
repeat
    time = timerMode and timerLength or 0
    updateTimer()
 
    setColors("smiley")
    gpu.set(math.floor(resX / 2), 2, ":^)")
 
    flgs, clrd = 0, 0
    gameState = 0
 
    updateMineCount()
 
    for r = 1, rows do
        board[r] = {}
        key[r] = {}
        for c = 1, cols do
            placeClear(r, c, "empty")
            board[r][c] = "empty"
            key[r][c] = 0
        end
    end
 
    if not noGuess then
        addMines(-1, -1)
    end
 
    running = true
 
    local e = event.pullMultiple("exit", "restart")
 
    running = false
    event.cancel(timerId)
until e == "exit"
 
event.ignore("touch", detectClick)
event.ignore("key_down", handleKeyDown)
gpu.setBackground(b[1], b[2])
gpu.setForeground(f[1], f[2])
term.clear()
gpu.setResolution(w, h)
gpu.setDepth(md)
