love=testLove
local GV=require('src.core.GameVersion');GV.set('emerald')
local Rse=require('src.core.game3.rse.init')
Rse.var=function(key,sess)return sess.vars[key] or 0 end
local D=require('src.core.game3.rse.frontier.trainers')
local C=require('src.core.game3.constants').of('emerald')
local banned={};for _,name in ipairs({'MEWTWO','MEW','LUGIA','HO_OH','CELEBI','KYOGRE','GROUDON','RAYQUAZA','JIRACHI','DEOXYS'})do banned[#banned+1]=assert(C.species.byName['SPECIES_'..name])end
D.pack=function(key)assert(key=='banned');return {species=banned}end
package.loaded['src.core.game3.pokemon']={SPECIES_EGG=412,name=tostring}
package.loaded['src.core.game3.dex']={isCaught=function()return false end}
local Text=require('src.core.game3.rom_text');Text.plain=function(key)return key end
local Util=require('src.core.game3.rse.frontier.util')
local on=false
assert(load(cheatSource,'@CodeBreaker/frontier','t',setmetatable({
 wrap=function(module,key,handler)
  local M=require(module);local original=M[key]
  M[key]=function(...)return handler(original,...)end
 end,
 isEmerald=function()return GV.get()=='emerald'end,
 enabled=function(key)assert(key=='frontier_legends');return on end,
},{__index=_G})))()
for facility=0,6 do
 for _,lvlMode in ipairs({D.LVL.L50,D.LVL.OPEN})do
  local sess={vars={VAR_FRONTIER_FACILITY=facility},party={}}
  local f=Util.frontier(sess);f.lvlMode=lvlMode
  for i=1,3 do sess.party[i]={species=banned[i],level=50}end
  on=false
  assert(Util.checkPartyIneligibility(sess,lvlMode)==true,'native banned party accepted')
  for _,mon in ipairs(sess.party)do assert(not Util.entryEligible(sess,mon))end
  on=true
  assert(Util.checkPartyIneligibility(sess,lvlMode)==false,'reception still rejects legends')
  for _,mon in ipairs(sess.party)do assert(Util.entryEligible(sess,mon),'picker still rejects legends')end
  assert(not Util.entryEligible(sess,{species=banned[1],level=50,isEgg=true}))
  assert(not Util.entryEligible(sess,{species=0,level=50}))
  if lvlMode==D.LVL.L50 then assert(not Util.entryEligible(sess,{species=banned[1],level=51}))end
  if facility==D.FACILITY.PYRAMID then assert(not Util.entryEligible(sess,{species=banned[1],level=50,item=13}))end
  assert(Util.checkBattleEntries(sess,{sess.party[1],sess.party[1],sess.party[3]},{1,2,3},3)=='gText_MonsCantBeSame')
  assert(Util.checkBattleEntries(sess,{{species=banned[1],item=13},{species=banned[2],item=13},sess.party[3]},{1,2,3},3)=='gText_NoIdenticalHoldItems')
  on=false;assert(Util.checkPartyIneligibility(sess,lvlMode)==true)
 end
end
on=true
for _,species in ipairs(banned)do assert(not Util.isBanned(species))end
for _,version in ipairs({'red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen'})do
 GV.set(version);for _,species in ipairs(banned)do assert(Util.isBanned(species),'unsupported title bypassed ban')end
end
print('PASS Frontier legends: 10 restricted species, both entry paths, 7 facilities, 2 level modes, OFF restoration and other rules retained')
