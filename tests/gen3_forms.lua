local root,version=arg[1],arg[2]
local function read(path)local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end
love=testLove
require('src.core.GameVersion').set(version)
local C=require('src.core.game3.constants').of(version)
package.loaded['src.core.game3.items_data']={toNumericId=function(key)return C.items.byName['ITEM_'..key]end}
local P=require('src.core.game3.pokemon')
P._names={};P._byName={};P._types={};P._stats={};P._speciesMeta={};P._abilities={}
P._abilityNames={};P._learnsets={};P._eggMoves={};P._evolutions={};P._dex={}
P._battleMoves={}
P._moveNames={};P._tmhm={machines={},learnsets={}}
P._national={toSpecies={},toNational={}}
local function norm(s)return s:upper():gsub('[^A-Z0-9]','')end
for name,slot in pairs(C.species.byName) do
  if name:match('^SPECIES_') and slot>0 and slot<=450 then
    local id=name:sub(9)
    P._names[slot]=id;P._byName[norm(id)]=slot
    P._speciesMeta[slot]={genderRatio=127,growthRate=0,catchRate=45,expYield=50}
    P._stats[slot]={hp=50,atk=50,def=50,spe=50,spa=50,spd=50}
    P._abilities[slot]={0,0};P._types[slot]={0,0}
  end
end
for name,id in pairs(C.moves.byName)do if name:match('^MOVE_') and id<=354 then P._moveNames[id]=name:sub(6) end end
local roster=assert(load(read('encounters/roster.lua')))()
for _,row in ipairs(roster)do
  if row.id<=386 then
    local slot=assert(P.speciesFromName(row.name),row.name)
    P._national.toSpecies[row.id]=slot;P._national.toNational[slot]=row.id
  end
end
local national=assert(load(read('dex/data/species/generated/national.lua')))()
local mod={path=root..'/dex',exports={},read=function(_,path)return read('dex/'..path)end,
  log={info=function()end},events={on=function()end},hooks={wrap=function()end}}
-- Current 1025Dex builds derive native TM/HM permissions through their public
-- sharded stats API. Install the real API over an in-memory content registry.
local registry={}
for _,row in ipairs(roster)do registry[row.name]={name=row.name,dex=row.id}end
for id,row in pairs(national.register or {})do registry[id]=row end
for id,row in pairs(national.patch or {})do
  local record=registry[id] or {};registry[id]=record
  for key,value in pairs(row)do record[key]=value end
end
mod.content={pokemon={get=function(_,id)return registry[id]end,each=function()
  local key
  return function()key=next(registry,key);if key then return key,registry[key]end end
end}}
local DexApi=assert(load(read('dex/src/api.lua')))()
assert(DexApi.install(mod),'1025Dex public API install')
-- Form learnsets now contain canonical post-Gen3 moves. Populate this test's
-- synthetic move pack from the real installed registry, without installing
-- combat models (this suite validates species identities/menu dispatch).
local NativeMoves=require('src.core.game3.battle.moves')
local ModernMoves=assert(load(read('gen3-mechanics/registry.lua')))()(mod.exports,NativeMoves)
for number,row in pairs(ModernMoves.byNumber)do
  P._moveNames[number]=row.id
  P._battleMoves[number]=row
end
local nativeMoveNumber=NativeMoves.numForName
NativeMoves.numForName=function(id)return ModernMoves.numberFor(id) or nativeMoveNumber(id)end
local Adapter=assert(load(read('dex/src/gen3shape.lua')))()
Adapter.install(mod,national)
local Learnsets=assert(load(read('gen3-mechanics/learnsets.lua')))()({
  read=function(_,path)return read(path)end,exports=mod.exports,
},ModernMoves)
local count,emptyLearnsets=0,0
local Party=require('src.core.game3.party')
for id,row in pairs(national.register) do if row.form then
  local slot=assert(P.speciesFromName(id),id)
  assert(slot==row.dex+64 and slot>1089,'stable form slot '..id)
  local base=assert(P.speciesFromName(row.baseSpecies),row.baseSpecies)
  assert(P.national(slot)==P.national(base),'base cry/dex mapping '..id)
  assert(P.speciesFromNational(P.national(slot))==base,'base lookup overwritten '..id)
  assert(P.__completeDexForms[slot].id==id)
  assert(P.stats(slot).atk==row.baseStats.attack,'form stats '..id)
  assert(P.stats(slot).spa==row.spAttack,'split Special '..id)
  assert(P.speciesMeta(slot).genderRatio==P.speciesMeta(base).genderRatio,'form gender '..id)
  local set=P.learnset(slot);assert(type(set)=='table','form learnset type '..id)
  if #set==0 then emptyLearnsets=emptyLearnsets+1 end
  for _,move in ipairs(set)do assert(move[2]>0 and P._moveNames[move[2]],'unusable form move '..id)end
  local ok,_,mon=Party.giveMon({party={}},slot,50,nil,{fixedPersonality=0})
  assert(ok and mon.species==slot and mon.speciesId==slot and P.speciesOf(mon)==slot,'constructed form lost identity '..id)
  assert(mon.maxHp>0 and type(mon.moves)=='table','constructed form stats/moves shape '..id)
  if #set>0 then assert(#mon.moves>0,'learnable form moves '..id)end
  count=count+1
end end
assert(count>300)
-- Simulate a freshly imported pack, retaining the base ROM fixture.
for slot in pairs(P.__completeDexForms)do
  P._names[slot]=nil;P._stats[slot]=nil;P._speciesMeta[slot]=nil
  P._national.toNational[slot]=nil
end
P._runReloadHooks()
for slot,form in pairs(P.__completeDexForms)do
  assert(P.speciesFromName(form.id)==slot and P.keyName(slot) and P.stats(slot) and P.national(slot),'reload lost form')
end
for nat=1,1025 do local slot=assert(P.speciesFromNational(nat));assert(P.national(slot)==nat)end
local Anim=require('src.core.game3.mon_anim')
for slot in pairs(P.__completeDexForms)do
  -- No ROM animation table is consulted for form species.
  local sprite={tasks={}}
  Anim.doFront(sprite,slot,true,0)
  assert(Anim.done(sprite),'form animation must complete')
end

local state={selectedSpecies=P.speciesFromNational(25),selectedNational=25,wildLevel=50}
local G3Menu={mode='species',cursor=1,selectedNational=25,game={}}
local function g3Pokemon()return P end
local function g3SpeciesLimit()return 1025 end
local function persist()end
local function g3Switch(mode)G3Menu.mode=mode end
local selected,encounterHook
local function enabled(key)return key=='wild_pick' end
local function isGen3()return true end
mod.game={}
mod.hooks.wrap=function(_,key,fn)if key=='encounter.roll' then encounterHook=fn end end
package.loaded['src.core.game3.battle_bridge']={start=function(_,_,mon,opts)
  selected=mon;assert(opts.__completeDexExact and opts.wild);return true end}
-- Inject production menu/selection/encounter functions from main.lua.
assert(load(menuSource,'@CodeBreaker/menu','t',setmetatable({
  state=state,G3Menu=G3Menu,g3Pokemon=g3Pokemon,g3SpeciesLimit=g3SpeciesLimit,
  persist=persist,g3Switch=g3Switch,mod=mod,enabled=enabled,isGen3=isGen3,
  selectedGenderless=function()return false end,
  isGen2=function()return false end,
},{__index=_G})))()(function(rows,activate,start,selectedSpecies)
  local list=rows();assert(#list==1025+count,'all forms visible')
  local seen={}
  for i,row in ipairs(list)do
    assert(row.species and not seen[row.species],'duplicate/missing slot');seen[row.species]=true
    if i>1025 then
      G3Menu.mode='species';G3Menu.cursor=i;activate()
      assert(state.selectedSpecies==row.species and selectedSpecies()==row.species,'selection reduced to base')
      assert(start() and selected.species==row.species and selected.speciesId==row.species,'Battle Now lost form')
      local encounter=encounterHook(function()return {species=1,level=7}end,{}, {})
      assert(encounter.species==row.species and encounter.speciesId==row.species and encounter.level==50,'wild override lost form')
    end
  end
  -- Choosing a base after a form must clear the prior selection.
  G3Menu.mode='species';G3Menu.cursor=25;activate()
  assert(state.selectedSpecies==P.speciesFromNational(25))
  local mega=assert(P.speciesFromName('CHARIZARD_MEGA_X'))
  assert(mod.exports.setSelectedSpecies('CHARIZARD_MEGA_X'))
  assert(state.selectedSpecies==mega and selectedSpecies()==mega,'export setter lost Mega')
  assert(mod.exports.spawn(25,30))
  assert(selected.species==P.speciesFromNational(25) and selected.level==30,'numeric spawn retained prior form')
end)
print('PASS '..version..': '..count..' forms registered, reloaded, listed and dispatched through Battle Now/wild override; 1025 base identities preserved; '..emptyLearnsets..' forms have no level-up learnset in fixture')
