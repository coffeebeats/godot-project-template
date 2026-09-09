-- tools/testdata/make_sprite_fixture.lua
--
-- Regenerates `sprite.aseprite`, the fixture `tools/aseprite.sh` is verified against.
-- It has four 16x16 frames, two tags, and a distinct duration per frame, so a manifest
-- that loses tags or timing is visibly wrong.
--
--   aseprite -b --script tools/testdata/make_sprite_fixture.lua
--
-- Run from the repository root; the output path is relative to the working directory.

local COLORS = {
  Color { r = 220, g = 60, b = 60 },
  Color { r = 60, g = 220, b = 60 },
  Color { r = 60, g = 60, b = 220 },
  Color { r = 220, g = 220, b = 60 },
}

local DURATIONS = { 0.1, 0.2, 0.05, 0.15 }

local sprite = Sprite(16, 16, ColorMode.RGB)
sprite.filename = "sprite.aseprite"

for _ = 2, #COLORS do
  sprite:newEmptyFrame()
end

for index = 1, #COLORS do
  local image = Image(16, 16)
  image:clear(COLORS[index])

  sprite:newCel(sprite.layers[1], sprite.frames[index], image, Point(0, 0))
  sprite.frames[index].duration = DURATIONS[index]
end

local idle = sprite:newTag(1, 2)
idle.name = "idle"
idle.aniDir = AniDir.FORWARD

local walk = sprite:newTag(3, 4)
walk.name = "walk"
walk.aniDir = AniDir.PING_PONG

sprite:saveAs("tools/testdata/sprite.aseprite")
