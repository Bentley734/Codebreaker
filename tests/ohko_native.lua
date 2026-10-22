-- Native current-engine Hook bus + Gen1 computeDamage and damage application.
-- Also loads the real installed 1025Dex terminal formula, not an imitation.
local root,version,dex,source=arg[1],arg[2],arg[3],arg[4] or arg[1]
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
love={math={random=math.random},filesystem={getInfo=function()return nil end}}
local B1=require('src.battle.BattleState')
require('src.battle.TypeChart').load({type_chart={matchups={},types={NORMAL={category='physical'}}}})
local B2=require('src.battle.gen2.Battle')
local Runtime=require('src.mods.Runtime')
local setup=read(root..'/tests/cheat_regression.lua')
setup=setup:sub(1,assert(setup:find('-- Every catalog code',1,true))-1)
arg[1]=source
local fixture=assert(load(setup..'\nreturn {api=api,hooks=Hooks,mod=mod,game=game}','@fixture'))()
Runtime.hooks=fixture.hooks;package.loaded['src.mods.Runtime']=Runtime
local hooks,api=fixture.hooks,fixture.api
local count=0
local function eq(a,b,label)count=count+1;assert(a==b,version..' '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function truth(a,label)count=count+1;assert(a,version..' '..label)end
local function wrapper(isPlayer)
  local stats={hp=100,attack=40,defense=40,speed=40,special=40,spa=40,spd=40}
  return {isPlayer=isPlayer,level=20,mon={hp=100,level=20,stats=stats},
    curStats=stats,curTypes={'NORMAL'},def={},stages={}}
end
local p,e=wrapper(true),wrapper(false)
local gen=require('src.core.GameVersion').generation()
local battle=setmetatable({player=p,enemy=e,ruleset={},rng=function(lo,hi)return hi or lo or 255 end,
  queue={},nextInsert=0},B1)
local tackle={id='TACKLE',power=40,type='NORMAL',category='physical'}
local opts={forceCrit=false,rng=battle.rng}
if gen==2 then
 p,e=p.mon,e.mon;p.types={'NORMAL'};e.types={'NORMAL'}
 p.stats.specialAttack,p.stats.specialDefense=40,40;e.stats.specialAttack,e.stats.specialDefense=40,40
 battle=setmetatable({player=p,enemy=e,stages={player={},enemy={}},
  random=function(n)return n-1 end,events={},screens={player={},enemy={}},
  data={type_chart={types={NORMAL={category='physical'}},matchups={},
    battleRules={highCriticalMoves={},criticalChances={[0]=0}}}}},B2)
end
local function damage(user,target,move)
 if gen==2 then return battle:hitOnce(user,target,move or tackle,{calculateOnly=true})end
 return battle:computeDamage(user,target,move or tackle,opts)
end
local function hp(w)return w.mon and w.mon.hp or w.hp end
local function setHp(w,v)if w.mon then w.mon.hp=v else w.hp=v end end
truth(api.setEnabled('enemy_hp',true),'enable OHKO')
local d=damage(p,e);eq(d,100,'native Gen1 OHKO damage')
api.setEnabled('enemy_hp',false)
local normal=damage(p,e);truth(normal>0 and normal<100,'native damage while disabled')
-- Match real loader order: optional dependency loads its terminal formula first.
local cheat
for i,row in ipairs(hooks.chains['battle.damage'])do
 if row.owner=='firered_codebreaker'then cheat=row;table.remove(hooks.chains['battle.damage'],i);break end
end
truth(cheat~=nil,'CodeBreaker hook registered')
local category=assert(load(read(dex..'/combat/engine_move_category.lua'),'@engine_move_category.lua'))()
local modern={exports={MoveCategory=category,ModernStats={ensure=function()end}},
 hooks={wrap=function(_,name,fn,priority)return hooks:wrap(name,fn,priority,'1025dex')end},
 events={on=function()end},content={move_effects={register=function()end,override=function()end},
 moves={patch=function()end},pokemon={get=function()return nil end}},log={info=function()end}}
assert(load(read(dex..'/combat/modern_combat.lua'),'@1025dex/combat/modern_combat.lua'))()(modern)
hooks:wrap('battle.damage',cheat.callback,cheat.priority,cheat.owner)
api.setEnabled('enemy_hp',false)
normal=damage(p,e);truth(normal>0 and normal<100,'real 1025Dex normal formula reached')
api.setEnabled('enemy_hp',true)
d=damage(p,e);eq(d,100,'1025Dex terminal must not bypass OHKO')
local dealt=gen==2 and battle:dealDamage(p,e,d) or battle:applyDamage(e,d)
eq(hp(e),0,'native application faints opponent');eq(dealt,100,'native damage amount')
setHp(e,100)
eq(damage(e,p),normal,'enemy attack is unchanged')
eq(damage(p,p),normal,'self-target attack is unchanged')
api.setEnabled('party_hp',true)
eq(damage(e,p),0,'infinite HP survives 1025Dex terminal')
api.setEnabled('party_hp',false)
eq(damage(p,e,{id='GROWL',power=0,type='NORMAL',category='status'}),0,'status move remains nondamaging')
eq(damage(p,e,{id='ENDEAVOR',power=1,type='NORMAL',category='physical'}),0,'failed Endeavor remains nondamaging')
-- Reverse the load order too; equal-priority chains used to depend on order.
local modernHooks={}
for _,row in ipairs(hooks.chains['battle.damage'])do
 if row.owner=='1025dex'then modernHooks[#modernHooks+1]=row end
end
hooks.chains['battle.damage']=nil
hooks:wrap('battle.damage',cheat.callback,cheat.priority,cheat.owner)
for _,row in ipairs(modernHooks)do hooks:wrap('battle.damage',row.callback,row.priority,row.owner)end
eq(damage(p,e),100,'OHKO when CodeBreaker loads before terminal')
api.setEnabled('party_hp',true)
eq(damage(e,p),0,'infinite HP when CodeBreaker loads before terminal')
api.setEnabled('party_hp',false)
-- A no-effect result must not be turned into a successful hit by the cheat.
hooks:wrap('battle.damage',function()return 0,{crit=false,typeMult=0}end,500,'immune-probe')
eq(damage(p,e),0,'immune move remains zero')
api.setEnabled('enemy_hp',false)
eq(damage(p,e),0,'disabled returns terminal result')
print('PASS '..version..': '..count..' native/real-1025Dex OHKO checks')
return count
