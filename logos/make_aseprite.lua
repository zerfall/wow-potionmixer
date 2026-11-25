-- Builds a layered .aseprite file from the layer PNGs written by make_logos.py.
-- Run by make_logos.py:
--   aseprite -b --script-param frame=F.png --script-param art=A.png
--            --script-param palette=P.gpl --script-param out=O.aseprite
--            --script make_aseprite.lua

local params = app.params
local frame = Image{ fromFile = params.frame }
local art = Image{ fromFile = params.art }

local sprite = Sprite(frame.width, frame.height, ColorMode.RGB)
sprite:setPalette(Palette{ fromFile = params.palette })

local frameLayer = sprite.layers[1]
frameLayer.name = "Frame"
sprite:newCel(frameLayer, 1, frame, Point(0, 0))

local artLayer = sprite:newLayer()
artLayer.name = "Art"
sprite:newCel(artLayer, 1, art, Point(0, 0))

sprite:saveAs(params.out)
