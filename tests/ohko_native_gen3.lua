-- Actual native Gen3 State/Adapter/Engine/Hit pipeline, singles and doubles.
local root,version,source=arg[1],arg[2],arg[3] or arg[1]
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
love={math={random=math.random},filesystem={getInfo=function()return nil end}}
local Runtime=require('src.mods.Runtime')
local State=require('src.core.game3.battle.state')
local Adapter=require('src.core.game3.battle.adapter')
local Engine=require('src.core.game3.battle.engine')
local P=require('src.core.game3.pokemon')
local Moves=require('src.core.game3.battle.moves')
local setup=read(root..'/tests/cheat_regression.lua')
setup=setup:sub(1,assert(setup:find('-- Every catalog code',1,true))-1)
arg[1]=source
local f=assert(load(setup..'\nreturn {api=api,hooks=Hooks,mod=mod,game=game}','@fixture'))()
Runtime.hooks=f.hooks;package.loaded['src.mods.Runtime']=Runtime
package.loaded['src.core.game3.pokemon']=P
package.loaded['src.core.game3.battle.engine']=Engine
-- Isolated decoded-ROM records; no caches, player saves or assets are changed.
P._types={[1]={0,0}};P._names={[1]='BULBASAUR'};P._byName={BULBASAUR=1}
P._stats={};P._speciesMeta={[1]={genderRatio=127}};P._abilities={[1]={0,0}}
P._moveNames={[33]='TACKLE',[45]='GROWL'};P._battleMoves={[33]={power=40,type=0,accuracy=100,pp=35,effect=0,target=0,priority=0,flags=3},[45]={power=0,type=0,accuracy=100,pp=40,effect=18,target=0,priority=0,flags=3}}
Moves._rom=P._battleMoves;Moves._romLoaded=true;Moves.BY_NUM={[33]='TACKLE',[45]='GROWL'};Moves._numByName={TACKLE=33,GROWL=45}
-- Text painting is outside this headless damage test.
local RT=require('src.core.game3.rom_text');RT.plain=function(key)return tostring(key)end;RT.at=RT.plain
local BT=require('src.core.game3.battle.battle_text');BT.get=function(key)return tostring(key)end;BT.key=BT.get
local count=0
local function eq(a,b,label)count=count+1;assert(a==b,version..' '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function truth(v,label)count=count+1;assert(v,version..' '..label)end
local function mon()return{species=1,level=20,hp=100,maxHp=100,attack=40,defense=40,spAtk=40,spDef=40,speed=40,moves={33},pp={35}}end
local function setupBattle(double)
 local st=State.new{playerParty={mon(),mon()},foeParty={mon(),mon()},double=double,wild=true,rng=function(lo)return lo end}
 st.version=version
 return st,Adapter.new(st)
end
f.api.setEnabled('enemy_hp',true)
for _,double in ipairs({false,true})do
 for _,pair in ipairs(double and {{0,1},{0,3},{2,1},{2,3}} or {{0,1}})do
  local st,ad=setupBattle(double)
  local u,t=State.battler(st,pair[1]),State.battler(st,pair[2])
  local out=Engine.resolveMove(u,t,33,1,ad,st,{},{})
  eq(t.mon.hp,0,'native OHKO '..pair[1]..'->'..pair[2]);eq(u.mon.pp[1],34,'native PP once')
  truth(out._anim and #out._anim.hits>0,'native hit animation')
 end
end
local function run(st,ad,uid,tid,id)
 return Engine.resolveMove(State.battler(st,uid),State.battler(st,tid),id or 33,1,ad,st,{},{noRetarget=true})
end
-- A terminal replacement formula is allowed to stop the native calculation.
-- OHKO must still wrap it. Use the real native Damage.calc as its formula.
local D=require('src.core.game3.battle.damage')
f.hooks:wrap('battle.damage',function(_,ctx)
 return D.calc(ctx.user,ctx.target,Moves.get(ctx.moveNum),ctx.opts)
end,1000,'terminal-native-formula')
for _,pair in ipairs({{0,1},{0,3},{2,1},{2,3}})do
 local st,ad=setupBattle(true);run(st,ad,pair[1],pair[2])
 eq(State.battler(st,pair[2]).mon.hp,0,'native terminal OHKO '..pair[1]..'->'..pair[2])
end
f.api.setEnabled('enemy_hp',false)
do local st,ad=setupBattle(false);run(st,ad,0,1);truth(st.enemy.mon.hp>0 and st.enemy.mon.hp<100,'disabled native damage')end
f.api.setEnabled('enemy_hp',true)
do local st,ad=setupBattle(true);run(st,ad,1,0);truth(st.player.mon.hp>0 and st.player.mon.hp<100,'enemy attack unchanged')end
do local st,ad=setupBattle(true);run(st,ad,0,2);truth(st.battlers[2].mon.hp>0,'ally target never OHKO')end
f.api.setEnabled('party_hp',true)
for _,pair in ipairs({{1,0},{3,2}})do
 local st,ad=setupBattle(true);run(st,ad,pair[1],pair[2]);eq(State.battler(st,pair[2]).mon.hp,100,'native infinite HP partner')
end
f.api.setEnabled('party_hp',false)
do local st,ad=setupBattle(false);st.player.mon.moves={45};st.player.mon.pp={40};run(st,ad,0,1,45);eq(st.enemy.mon.hp,100,'native status move remains nondamaging')end
for _,enabled in ipairs({false,true})do
 f.api.setEnabled('enemy_hp',enabled)
 do local st,ad=setupBattle(false);st.enemy.type1=7;run(st,ad,0,1);eq(st.enemy.mon.hp,100,'native Ghost immunity OHKO='..tostring(enabled))end
 do local st,ad=setupBattle(false);st.enemy.expProtected=true;run(st,ad,0,1);eq(st.enemy.mon.hp,100,'native Protect OHKO='..tostring(enabled))end
 do
  Moves._rom[33].accuracy=1
  local st,ad=setupBattle(false);st.rng=function(lo,hi)return hi or lo end
  run(st,ad,0,1);eq(st.enemy.mon.hp,100,'native accuracy miss OHKO='..tostring(enabled))
  Moves._rom[33].accuracy=100
 end
end
print('PASS '..version..': '..count..' native Gen3 OHKO checks')
return count
