local Game = ...
local Character = require 'character'
local bg = require 'bg'
local anima = require 'anima'
local Projectile = require 'projectile'
local script = require 'script'
local Reader = require 'reader'
local audio = require 'audio'
local Enemy = require 'enemy'
local Physics = require 'physics'
local splash = require 'lib/splash'

local finchMoveset = {
    ["left"]  = vec2(-1.0, 0.0),
    ["right"] = vec2(1.0, 0.0),
    ["up"]    = vec2(0.0, 1.0),
    ["down"]  = vec2(0.0, -1.0)
}

local avaMoveset = {
    ["a"]  = vec2(-1.0, 0.0),
    ["d"] = vec2(1.0, 0.0),
    ["w"]    = vec2(0.0, 1.0),
    ["s"]  = vec2(0.0, -1.0)
}

local idleAnimation = {
    { row = 1, col = 1 },
    { row = 1, col = 2 },
}

local bulletCooldown = 0.05

local invulnTime = 1.0

local hurt = am.sfxr_synth(20560004)
local dead = am.sfxr_synth(50323902)

local gameover = require 'gameover'

function update_players(scene, players, root)
    local curtain = scene"bullet-curtain"
    local enemy_curtain = scene"enemy-curtain"
    local enemies = scene"enemies"
    for _, player in ipairs(players) do
        if not player.shouldFire then
        elseif not player.readyToFire and not player.awaiting then
            player.awaiting = true
            scene:action(player.name .. "_cooldown", coroutine.create(function(node)
                am.wait(am.delay(bulletCooldown))
                player.readyToFire = true
                player.awaiting = false
            end))
        elseif not player.awaiting then
            player.factory:fire(scene, player.position2d)
            player.readyToFire = false
        end
        -- check for collisions
        local obj = Physics.queryCollidableWithTag(splash.circle(player.position2d.x, player.position2d.y, 5), "enemyCollidable")
            if not player.invuln and obj then
                if table.search(enemies:all"enemyCollidable", obj) ~= nil then
                    obj:die(enemies)
                elseif table.search(enemy_curtain:all"enemyCollidable", obj) ~= nil then
                    obj:die(enemy_curtain)
                else
                    print("Warning: attempted to delete an enemy collidable that did not belong to a recognized scene graph node!")
                end
                if Life > 1 then
                    scene:action(am.play(hurt))
                    Life = Life - 1
                    player.invuln = true
                      scene(player.name):action(coroutine.create(function()
                           am.wait(am.delay(invulnTime))
                           player.invuln = false
                       end))
                else
                    -- Game Over!
                    root"game".paused = true
                    root:append(gameover.scene)
                end
             end
    end
end

local function build_hud()
    
    return am:group():tag"hud" ^ {
        am.translate(0, screenEdge.y) ^ {
            am.translate(-75, 0) ^ am.scale(3) ^ am.text("SCORE", "center", "top"),
            am.translate(-75, -16 * 3 - 8) ^ am.scale(3) ^ am.text(Score, "center", "top"):action(function(node) node.text = Score end),
            am.translate(75, 0) ^ am.scale(3) ^ am.text("LIFE", "center", "top"),
            am.translate(75, -16 * 3 - 8) ^ am.scale(3) ^ am.text(Life, "center", "top"):action(function(node) node.text = Life end),
        }
    }
end


function Game:new()
    Score = 0
    Life = 5 -- initial lives

    --[=[local]=] root = am.group():tag"root" ^ am.group():tag"game" ^ {
        Physics.newWorld(64), -- make cellSize a param in the future
        bg.scrolling:tag"bg",
        am.group():tag"theater" ^ {
            am.group():tag("enemy-curtain"),
            am.group():tag("bullet-curtain"),
            am.group():tag("enemies"),
            am.group():tag"continue",
        },
    }

    local game = root"game"
    
    local ava = Character:new({
        name = "ava",
        sprite = anima.te({
            file = "assets/sprite/ava.png",
            width = 104 / 2,
            height = 82,
            fps = 2.0
        }, idleAnimation),
        moveset = avaMoveset,
        position2d = vec2(-300, -250),
        bcenter = vec2(-screenEdge.x / 2, 0),
        bsize = screenEdge{ y = screenEdge.y * 2},
        curtain = game"bullet-curtain"
    })
    local finch = Character:new({
        name = "finch",
        sprite = anima.te({
            file = "assets/sprite/finch.png",
            width = 104 / 2,
            height = 82,
            fps = 2.0
        }, idleAnimation),
        moveset = finchMoveset,
        position2d = vec2(300, -250),
        bcenter = vec2(screenEdge.x / 2, 0),
        bsize = screenEdge{ y = screenEdge.y * 2},
        curtain = game"bullet-curtain"
    })

    game:append(ava)
    game:append(finch)
    game:append(am.group():tag"dialoguearea")
    game:append(build_hud())

    local reader = Reader:new(script(game))
    reader:init_stage(game)

    -- main game loop
    game:action(am.parallel({function(scene)
        update_players(scene, {ava, finch}, root)
        reader:update(scene)
    end}))

    root:action(function(scene)
        if globalWindow:key_down("p") then
            scene"game".paused = not scene"game".paused
        end
    end)

    return root
end