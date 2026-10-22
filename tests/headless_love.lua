-- Read-only filesystem and no-op graphics for model/registry tests. Rendering
-- assertions belong in native LÖVE battle tests, not this fixture.
local function read(path)
  local file=io.open(path,'rb');if not file then return nil end
  local data=file:read('*a');file:close();return data
end
local function noop()end
return {
  filesystem={
    read=read,
    load=function(path)local source=assert(read(path));return assert(load(source,'@'..path))end,
    getInfo=function(path)local data=read(path);if data then return {type='file',size=#data}end end,
    getDirectoryItems=function()return {}end,
  },
  timer={getTime=function()return 0 end},
  graphics={newQuad=function()return {}end,newImage=function()return {setFilter=noop,getWidth=function()return 8 end,getHeight=function()return 8 end}end},
}
