-- Full production entrypoint, real current-engine Sandbox, Hooks, GameVersion.
-- In-memory API fixtures isolate side effects; assertions inspect effects and
-- off/unload paths, not implementation substrings. Engine-specific battle
-- damage and native battle integration have separate coverage.
local root, version = arg[1], arg[2]
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, version .. ': ' .. message)
end
local function equal(a,b,message) check(a==b,message..' ('..tostring(a)..' ~= '..tostring(b)..')') end
local function read(path)
  local f=assert(io.open(root..'/'..path,'rb'));local s=f:read('*a');f:close();return s
end
local warnings={}
package.loaded['src.core.Logger']={warn=function(...)warnings[#warnings+1]={...}end}
local Version=require('src.core.GameVersion');Version.set(version)
local gen=Version.generation()
local Hooks=require('src.mods.Hooks').new()
package.loaded['src.mods.Runtime']={hooks=Hooks}
local events={}
local function emit(name,ev)for _,fn in ipairs(events[name] or {})do fn(ev)end end
local session={version=version,money=1,coins=2,party={},bag={},safari={balls=1,steps=2}}
local native={}
local function install(name,tableValue)package.loaded[name]=tableValue;return tableValue end
local Player=install('src.core.game3.player',{
  cellX=3,cellY=3,progress=0,stepFrames=16,moving=false,
  tick=function()native.tick=(native.tick or 0)+1;return 'tick' end,
  tryMove=function()return 'blocked','wall' end,
  scriptStep=function(dir)native.step=dir;return true end,
})
local Collision=install('src.core.game3.collision',{
  canEnter=function(_,_,_,opts)return false,(opts and opts.reason) or 'wall' end,
  inBounds=function(x,y)return x>=0 and x<10 and y>=0 and y<10 end,
})
local dc={stepCounter=0}
local Daycare=require('src.core.game3.daycare')
local nativeDaycareStep=Daycare.step
Daycare.stateOf=function()return dc end
Daycare.route5Of=function()return {steps=0}end
Daycare.step=function(s)
  native.daycareStep=(native.daycareStep or 0)+1
  if native.realDaycare then return nativeDaycareStep(s)end
  return 'step'
end
local Breeding=install('src.core.game3.breeding',{
  compatibility=function(v)return v.compatibility or 0 end,
  triggerPendingEgg=function(_,v)v.pending=true;v.offspringPersonality=1 end,
  tryProduceEgg=function()return 'normal-egg' end,
})
install('src.core.game3.rng',{Random=function()return 65535 end})
local Exp=install('src.core.game3.battle.experience',{awardFoe=function(st,foe,opts)return opts end})
local BattleEngine=install('src.core.game3.battle.engine',{
  isTradedMon=function()return true end,
  canRun=function()return false end,tryFlee=function()return false,'blocked' end,
  actionRunnable=function()return true end,
})
-- Lua locals are not visible inside their own initializer closures.
package.loaded['src.core.game3.battle.engine'].resolveMove=function(user,target,move,slot,adapter,st,out,opts)
  native.obey=not BattleEngine.isTradedMon();native.fateful=st.playerParty[1].fatefulEncounter
  if opts and opts.fail then error('intentional native move failure')end
  return 'move-result','second'
end
local Battle=install('src.core.game3.battle',{
  getState=function()return native.battle end,
  update=function()native.updateWild=native.battle and native.battle.wild;return 'battle-update' end,
})
local Secondary=install('src.core.game3.battle.effects.secondary',{set=function()return 'native-secondary' end})
local Frontier=install('src.core.game3.rse.frontier.util',{
  isBanned=function()return true end,
  frontier=function(s)s.frontier=s.frontier or {};return s.frontier end,
})
local VsSeeker=install('src.core.game3.vs_seeker',{
  MAX_CHARGE=100,setBattery=function(s,value)s.battery=value end,
})
local ItemUse=install('src.core.game3.item_use',{useBike=function()return false,'indoors' end})
local Bike=install('src.core.game3.bike',{rse=function()return nil end})
install('src.core.game3.audio',{bikeMusic=function(value)native.bikeMusic=value end})
install('src.core.game3.runtime',{getSession=function()return session end})
install('src.core.game3.scripting.space',{getStore=function()return session end})
local Flags=install('src.core.game3.scripting.flags',{
  setFlag=function(s,_,id,value)s.flags=s.flags or {};s.flags[id]=value end,
  trainerFlagId=function(id)return id+10000 end,
  getFlag=function(_,_,id)return id==10042 or id==10043 end,
})
local Pokemon=install('src.core.game3.pokemon',{
  battleMove=function(id)return {pp=id==1 and 35 or 25}end,
  speciesFromNational=function(id)return id end,speciesFromName=function()return 25 end,
  keyName=function(id)return id==25 and 'PIKACHU' or 'OTHER' end,
  national=function(id)return id end,speciesMeta=function()return {genderRatio=127}end,
})
local game={save={generation=gen,money=3,coins=4,player={money=5,coins=6},party={},inventory={},safari={balls=2,steps=3}},
  stack={states={}},data={moves={TACKLE={id='TACKLE',name='Tackle',pp=35,index=1},GROWL={id='GROWL',name='Growl',pp=40,index=2}},
  items={POTION={name='Potion',index=1,pocket='ITEM'},BICYCLE={name='Bicycle',index=2,pocket='KEY_ITEM'}},
  pokemon={PIKACHU={name='Pikachu',dex=25,genderRatio=127}}}}
if gen==3 then game.data.moves={[1]={name='Tackle',pp=35},[2]={name='Growl',pp=40}} end
if version=='yellow' then game.save.pikachuHappiness=90 end
local pokemonContent={get=function(_,id)return game.data.pokemon[id]end,
  each=function()return pairs(game.data.pokemon)end}
local mod={id='firered_codebreaker',game=game,generation=gen,exports={},save={},
  hooks={wrap=function(_,name,fn,priority)return Hooks:wrap(name,fn,priority,'firered_codebreaker')end},
  events={on=function(_,name,fn)events[name]=events[name] or {};table.insert(events[name],fn)end},
  content={pokemon=pokemonContent,screens={register=function()end}},
  ui={ListMenu={new=function(_,title,items,opts)return {title=title,items=items,opts=opts}end},
    insertBefore=function(items,label,row)items[#items+1]=row;return items end},
  read=function(_,path)return read(path)end,
}
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId=mod.id,permissions={engine_internals=true}})
check(env.package==nil and env.io==nil,'native mod sandbox restrictions active')
assert(Sandbox.compile(read('main.lua'),'@CodeBreaker/main.lua',env))()(mod)
local api=mod.exports
local function toggle(effect,value)check(api.setEnabled(effect,value),'toggle '..effect..'='..tostring(value))end
local function call(name,vanilla,...)return Hooks:call(name,vanilla,...)end
local function input(nextFn)return call('input.step',nextFn or function()return 'input' end,game,1/60)end
local function active(effect)
  for _,row in ipairs(api.list(game))do if row.effect==effect then return row.enabled end end
end
-- Every catalog code has support checks, functional toggles and persistence.
local rows=api.list(game);equal(#rows,29,'catalog count')
local supported=0
for _,row in ipairs(rows)do
  check(not row.enabled,'initially disabled '..row.effect)
  if row.supported then
    supported=supported+1;toggle(row.effect,true);check(active(row.effect),'enabled '..row.effect)
    toggle(row.effect,false);check(not active(row.effect),'disabled '..row.effect)
  else
    local ok=api.setEnabled(row.effect,true);check(not ok,'unavailable code rejected '..row.effect)
  end
end
check(not api.setEnabled('unknown_cheat',true),'unknown code rejected')
check(not api.parse('0100'),'short code rejected');check(not api.parse('FF00E7CF'),'unsupported code rejected')
equal(api.parse('01 00 E7 CF').addressHex,'CFE7','code address parses')
check(api.setEnabled('0100E7CF',true),'legacy OHKO code alias');toggle('enemy_hp',false)
toggle('always_catch',true)
local yes,rate=call('catch.rate',function()return false,7 end,'POKE_BALL',{}, {},{})
check(yes,'easy catch on');equal(rate,gen==3 and 4 or gen==2 and 255 or 3,'catch result format')
toggle('catch_easy',false);yes,rate=call('catch.rate',function()return false,7 end)
check(not yes and rate==7,'catch off pass-through')
-- Walk modes preserve boundaries and restore native behavior.
local ctx={reason='wall'}
equal(call('movement.collision',function()return false end,false,ctx),false,'wall off')
toggle('walk','safe');check(call('movement.collision',function()return false end,false,ctx),'wall safe')
equal(ctx.reason,'codebreaker','safe reason');ctx.reason='bounds'
check(not call('movement.collision',function()return false end,false,ctx),'safe boundary')
toggle('walk','unsafe');ctx.reason='wall';check(call('movement.collision',function()return false end,false,ctx),'wall unsafe')
equal(ctx.reason,'gameshark','unsafe reason');toggle('walk',false)
-- No-battles never constructs an encounter. Wild overrides keep native AUTO levels.
local called=0
local function encounter()called=called+1;return {species=1,level=7}end
toggle('no_encounters',true);equal(call('encounter.roll',encounter,{},{}),nil,'no encounters')
equal(called,0,'no encounter vanilla side effect');toggle('no_encounters',false)
check(api.setSelectedSpecies('PIKACHU'),'select species');toggle('wild_pick',true)
local encounterRow=call('encounter.roll',encounter,{},{});equal(encounterRow.species,gen==3 and 25 or 'PIKACHU','wild species')
equal(encounterRow.level,7,'wild AUTO level');check(api.setWildLevel(55),'set wild level')
equal(call('encounter.roll',encounter,{},{}).level,55,'wild manual level')
check(not api.setWildLevel(101),'invalid wild level');check(api.setWildLevel('auto'),'AUTO level')
toggle('wild_pick',false);equal(call('encounter.roll',encounter,{},{}).species,1,'wild override off')
if gen==2 then
  check(api.setWildGender('female'),'set wild gender');check(api.setWildShiny('yes'),'set shiny yes')
  toggle('wild_pick',true);call('encounter.roll',encounter,{},{})
  local dvs={attack=15,defense=1,speed=1,special=1}
  check(call('shiny.roll',function()return false end,{species='PIKACHU',level=7,dvs=dvs,def={genderRatio=127}}),'forced Gen2 shiny')
  equal(dvs.defense,10,'shiny defense DV');equal(dvs.speed,10,'shiny speed DV');equal(dvs.special,10,'shiny special DV')
  check(dvs.attack<7 and (dvs.attack%4==2 or dvs.attack%4==3),'gender and shiny compatible attack DV')
  equal(call('gender.roll',function()return 'male' end,{species='PIKACHU',level=7,ratio=127}),'female','forced Gen2 gender')
  equal(call('gender.roll',function()return 'male' end,{species='PIKACHU',level=7,ratio=255}),'unknown','genderless stays genderless')
  check(api.setWildShiny('no'),'set shiny no');call('encounter.roll',encounter,{},{})
  check(not call('shiny.roll',function()return true end,{species='PIKACHU',level=7,dvs=dvs,def={genderRatio=127}}),'forced non-shiny')
  check(dvs.speed~=10,'non-shiny DVs agree')
  check(api.setWildGender('random') and api.setWildShiny('random'),'wild identity reset');toggle('wild_pick',false)
end
-- Move/item/friendship tools, including invalid input and caps.
local moveId=gen==3 and 1 or 'TACKLE'
local mon={moves={},hp=1,maxHp=50,isEgg=false}
check(api.teachMove(mon,moveId,game),'teach move');equal(#mon.moves,1,'one move taught')
check(api.teachMove(mon,moveId,game),'refill known move');equal(#mon.moves,1,'known move not duplicated')
check(not api.setMoveSlot(mon,5,moveId,game),'invalid move slot rejected')
check(not api.teachMove(mon,'DOES_NOT_EXIST',game),'unknown move rejected')
local movePp=gen==3 and mon.pp[1] or mon.moves[1].pp;equal(movePp,35,'taught move PP')
if gen<3 then
  check(api.giveItem('POTION',150,game),'give item');equal(game.save.inventory.POTION,99,'item stack cap')
  check(api.giveItem('BICYCLE',5,game),'give key item');equal(game.save.inventory.BICYCLE,1,'key item unique')
  equal(#game.save.bagOrder,2,'bag order no duplicates')
end
if gen==2 or gen==3 then
  check(api.setFriendship(mon,999,game),'set friendship');equal(api.getFriendship(mon,game),255,'friendship cap')
  mon.isEgg=true;check(not api.setFriendship(mon,100,game),'egg friendship rejected');mon.isEgg=false
elseif version=='yellow' then
  check(api.setFriendship(mon,999,game),'Yellow friendship');equal(game.save.pikachuHappiness,255,'Yellow friendship cap')
else check(not api.setFriendship(mon,100,game),'Gen1 friendship unsupported')end
-- Continuous cheats are tested before AND after a native update mutates state.
local partyMon={hp=3,maxHp=50,moves=gen==3 and {1} or {{id='TACKLE',pp=1,ppUps=2,maxPp=49}},
  pp={1},maxPp={49}}
game.save.party={partyMon};session.party={partyMon}
local foe={hp=30,maxHp=30,moves={}}
local player=gen==1 and {mon=partyMon,isPlayer=true,curMoves={{id='TACKLE',pp=1,ppUps=2}}} or partyMon
local enemy=gen==1 and {mon=foe,isPlayer=false} or foe
local battle={player=player,enemy=enemy,wild=true,battlers={}}
if gen==1 then game.stack.states={battle}
elseif gen==2 then game.stack.states={{battle=battle,throwBallAtTrainer=function()end}}
else
  player={mon=partyMon,side='player',hp=3,maxHp=50};enemy={mon=foe,side='enemy',hp=30,maxHp=30}
  battle.player=player;battle.enemy=enemy;battle.battlers={[0]=player,[1]=enemy};native.battle=battle
end
emit('battle.started',{kind='trainer',battle=battle})
for _,effect in ipairs({'cash','coins','party_hp','infinite_pp','badges','enemy_burn'})do toggle(effect,true)end
if gen~=2 then toggle('safari_balls',true);toggle('safari_time',true)end
input(function()
  partyMon.hp=2
  if gen==3 then session.money=0;session.coins=0;session.safari.balls=0;session.safari.steps=0;partyMon.pp[1]=0
  elseif gen==1 then game.save.safari.balls=0;game.save.safari.steps=0 end
  return 'native-input'
end)
equal(partyMon.hp,50,'post-step HP restored')
local purse=gen==3 and session or gen==2 and game.save.player or game.save
equal(purse.money,999999,'cash refill');equal(purse.coins,9999,'coin refill')
equal(gen==3 and partyMon.pp[1] or partyMon.moves[1].pp,49,'PP refill honors PP Ups')
equal(foe.status,gen==2 and 'burn' or 'BRN','enemy burn status schema')
if gen==1 then
  equal(game.save.inventory.EARTHBADGE,1,'Gen1 badges');equal(game.save.safari.balls,99,'Safari balls after decrement');equal(game.save.safari.steps,500,'Safari time after decrement')
elseif gen==2 then
  check(game.save.player.badges.RISING and game.save.player.kantoBadges.EARTH,'Gen2 badge regions')
else
  equal(session.badges,255,'Gen3 badges');equal(session.safari.balls,99,'Gen3 Safari balls');equal(session.safari.steps,600,'Gen3 Safari time')
end
for _,effect in ipairs({'cash','coins','party_hp','infinite_pp','badges','enemy_burn'})do toggle(effect,false)end
if gen~=2 then toggle('safari_balls',false);toggle('safari_time',false)end
partyMon.hp=2;purse.money=1;purse.coins=2;foe.status=nil
input();equal(partyMon.hp,2,'HP off');equal(purse.money,1,'cash off');equal(purse.coins,2,'coin off');equal(foe.status,nil,'burn off')
-- Trainer captures preserve the native capture path and trainer completion.
if gen==1 then
  local base={
    catchAttempt=function()return false,0 end,
    throwBall=function(self,ball)
      equal(self.kind,'wild','trainer ball uses native catchable path')
      local caught,shakes=self:catchAttempt(ball)
      check(caught and shakes==3,'trainer catch is three shakes')
      return 'throw-result'
    end,
    storeCaughtMon=function(self)native.stored=(native.stored or 0)+1;self.result='caught';return 'stored' end,
    playVictoryMusic=function()native.victory=true end,
  }
  local trainer=setmetatable({kind='trainer',player=player,enemy=enemy},{__index=base})
  game.stack.states={trainer};toggle('steal_trainer',true)
  emit('battle.started',{kind='trainer',battle=trainer})
  equal(trainer:throwBall('POKE_BALL'),'throw-result','trainer throw return preserved')
  equal(trainer:storeCaughtMon(),'stored','native capture return preserved')
  equal(native.stored,1,'native capture executes once');equal(trainer.kind,'trainer','trainer kind restored')
  equal(trainer.result,'win','trainer marked defeated');equal(trainer.afterQueue,'finish','trainer catch finishes');check(native.victory,'trainer victory music')
  toggle('steal_trainer',false);input()
  equal(trainer.throwBall,base.throwBall,'trainer throw unpatched');equal(trainer.catchAttempt,base.catchAttempt,'trainer catch unpatched')
elseif gen==2 then
  local screen={battle={player=player,enemy=enemy,wild=false}}
  local original=function()return 'blocked-trainer' end
  screen.throwBallAtTrainer=original
  screen.useItem=function(self)
    check(self.battle.wild,'Gen2 trainer temporarily wild')
    local caught,shakes=call('catch.rate',function()return false,0 end)
    check(caught and shakes==255,'Gen2 trainer forced catch')
    return 'captured'
  end
  game.stack.states={screen};toggle('steal_trainer',true);input()
  equal(screen:throwBallAtTrainer('POKE_BALL'),'captured','Gen2 capture continuation')
  check(not screen.battle.wild,'Gen2 trainer kind restored')
  screen.useItem=function()error('expected capture failure')end
  check(not pcall(screen.throwBallAtTrainer,screen,'POKE_BALL'),'Gen2 native capture error propagated')
  check(not screen.battle.wild,'Gen2 trainer restored on error')
  toggle('steal_trainer',false);input();equal(screen.throwBallAtTrainer,original,'Gen2 trainer capture unpatched')
  local caught=call('catch.rate',function()return false,0 end);check(not caught,'Gen2 capture scope restored')
end
if gen==3 then
  -- Wrappers are installed by the first input step, and use the same public
  -- method signatures as the current engine. Native callees are instrumented.
  local egg={isEgg=true,eggCycles=9,friendship=70};local bad={isEgg=true,isBadEgg=true,eggCycles=9}
  session.party={egg,bad};toggle('fast_hatch',true);equal(Daycare.step(session),'step','hatch native continuation')
  equal(egg.eggCycles,0,'egg cycles cleared');equal(bad.eggCycles,9,'bad egg untouched');equal(dc.stepCounter,254,'hatch cycle imminent')
  toggle('fast_hatch',false);dc.stepCounter=5;Daycare.step(session);equal(dc.stepCounter,5,'hatch off')
  toggle('quick_egg',true);dc.compatibility=1;dc.pending=nil
  check(Breeding.tryProduceEgg(session,dc,2)==true and dc.pending,'compatible quick egg')
  dc.pending=nil;dc.compatibility=0;equal(Breeding.tryProduceEgg(session,dc,2),'normal-egg','incompatible pair stays native')
  dc.compatibility=1;equal(Breeding.tryProduceEgg(session,dc,1),'normal-egg','one parent stays native');toggle('quick_egg',false)
  -- The actual Ruby/Sapphire policy bypasses Breeding.tryProduceEgg. Exercise
  -- the real public Daycare.step -> profile.daycare.step -> rs/daycare path.
  dc={steps={0,0},stepCounter=0,compatibility=70,[1]={species=25},[2]={species=25}}
  session.party={};native.realDaycare=true;toggle('quick_egg',true)
  local parentCount=Daycare.step(session)
  equal(parentCount,2,'native daycare counts parents')
  check(Daycare.isEggPending(dc),'quick egg through native title daycare dispatch')
  toggle('quick_egg',false);dc.pending=nil;dc.offspringPersonality=0;dc.steps={0,0};dc.stepCounter=0
  Daycare.step(session);check(not Daycare.isEggPending(dc),'native quick egg off')
  native.realDaycare=false
  local st={playerParty={{hp=10},{hp=10,isEgg=true},{hp=0},{hp=7}},link=false}
  local opts={marker='preserved',partyIndices={1}}
  toggle('party_exp',true);local awarded=Exp.awardFoe(st,{},opts)
  equal(#awarded.partyIndices,2,'party EXP eligible count');equal(awarded.partyIndices[2],4,'party EXP living non-egg slot')
  equal(awarded.marker,'preserved','party EXP opts preserved');equal(#opts.partyIndices,1,'caller opts not mutated')
  st.link=true;equal(Exp.awardFoe(st,{},opts),opts,'party EXP link bypass');st.link=false;toggle('party_exp',false)
  equal(Exp.awardFoe(st,{},opts),opts,'party EXP off')
  toggle('always_obey',true);local traded=BattleEngine.isTradedMon
  local first,second=BattleEngine.resolveMove({}, {}, {},1,{},st,{},{});equal(first,'move-result','obey return');equal(second,'second','obey multiple returns')
  check(native.obey and native.fateful,'obey applies temporary override');equal(st.playerParty[1].fatefulEncounter,nil,'obey restores mon')
  equal(BattleEngine.isTradedMon,traded,'obey restores function')
  check(not pcall(BattleEngine.resolveMove,{}, {}, {},1,{},st,{}, {fail=true}),'obey rethrows native failure')
  equal(BattleEngine.isTradedMon,traded,'obey restores on failure');equal(st.playerParty[1].fatefulEncounter,nil,'obey restores mon on failure')
  toggle('always_obey',false)
  toggle('escape_any',true);check(BattleEngine.canRun(st,{},{}),'escape trainer on');check(BattleEngine.tryFlee(st,{},{}),'flee trainer on')
  st.link=true;check(not BattleEngine.canRun(st,{},{}),'escape link bypass');st.link=false;toggle('escape_any',false)
  check(not BattleEngine.canRun(st,{},{}),'escape off')
  toggle('always_turn',true)
  for id=0,3 do equal(BattleEngine.actionRunnable(st,{battler=id}),id%2==0,'always turn doubles slot '..id)end
  st.link=true;check(BattleEngine.actionRunnable(st,{battler=1}),'always turn link bypass');st.link=false;toggle('always_turn',false)
  Player.biking=true;toggle('bike_water',true)
  check(Collision.canEnter(game,4,3,{reason='water'}),'bike on water');check(not Collision.canEnter(game,4,3,{reason='wall'}),'bike water keeps walls')
  toggle('bike_water',false);check(not Collision.canEnter(game,4,3,{reason='water'}),'bike water off')
  Player.biking=false;Player.moving=true;toggle('fast_walk',true);Player.tick(game);equal(Player.progress,1,'fast walk advance')
  Player.jumping=true;Player.tick(game);equal(Player.progress,1,'jump speed preserved');Player.jumping=false;Player.moving=false;toggle('fast_walk',false)
  toggle('bike_anywhere',true);check(ItemUse.useBike(session,1),'bike indoors on');check(Player.biking,'mounted bike')
  toggle('bike_anywhere',false);check(not ItemUse.useBike(session,1),'bike indoors off')
  toggle('no_recharge',true);equal(Secondary.set({user={side='player'}},'RECHARGE'),false,'player recharge suppressed')
  equal(Secondary.set({user={side='enemy'}},'RECHARGE'),'native-secondary','enemy recharge preserved');toggle('no_recharge',false)
  equal(Secondary.set({user={side='player'}},'RECHARGE'),'native-secondary','recharge off')
  toggle('steal_trainer',true);battle.wild=false;Battle._phase='action';equal(Battle.update(),'battle-update','trainer catch native return')
  check(native.updateWild and not battle.wild,'trainer catch restores kind');toggle('steal_trainer',false);Battle.update();check(not native.updateWild,'trainer catch off')
  if version=='emerald' then
    toggle('max_bp',true);input();equal(session.frontier.battlePoints,9999,'max battle points');toggle('max_bp',false)
    toggle('frontier_legends',true);check(not Frontier.isBanned(150),'frontier legends on');toggle('frontier_legends',false);check(Frontier.isBanned(150),'frontier legends off')
    toggle('rebattle_trainers',true)
    local row={trainer=42,type=5,marker='preserved'};local originalGet=Flags.getFlag
    local result=call('script.command',function(ctx,op,patched)
      equal(op,'trainerbattle','rematch opcode');equal(patched.type,0,'Match Call ready-wait removed')
      equal(patched.marker,'preserved','trainer row fields preserved')
      check(not Flags.getFlag({},session,10042),'target defeated flag temporarily clear')
      check(Flags.getFlag({},session,10043),'other defeated flag preserved')
      return 'rematch'
    end,{},'trainerbattle',row)
    equal(result,'rematch','rematch continuation');equal(row.type,5,'caller trainer row unchanged')
    equal(Flags.getFlag,originalGet,'flag getter restored')
    check(not pcall(function()call('script.command',function()error('expected script failure')end,{},'trainerbattle',row)end),'native script error propagated')
    equal(Flags.getFlag,originalGet,'flag getter restored on failure')
    toggle('rebattle_trainers',false)
  elseif version=='firered' or version=='leafgreen' then
    toggle('vs_seeker_charge',true);input(function()session.battery=0 end);equal(session.battery,100,'VS Seeker recharge post-step');toggle('vs_seeker_charge',false)
  end
  -- Battle-state Pokemon are cloned separately from the live save session.
  -- Partners occupy slot 2, foes slots 1/3 in the current doubles model.
  local function cloneMon()return {hp=2,maxHp=70,moves={1},pp={1},maxPp={49}}end
  local lead,partner,bench=cloneMon(),cloneMon(),cloneMon()
  local foeA,foeB=cloneMon(),cloneMon()
  local leadBattler={id=0,side='player',mon=lead}
  local partnerBattler={id=2,side='player',mon=partner}
  local foeBattlerA={id=1,side='enemy',mon=foeA}
  local foeBattlerB={id=3,side='enemy',mon=foeB}
  local State=require('src.core.game3.battle.state')
  State.ensureBattleMoves(leadBattler);State.ensureBattleMoves(partnerBattler)
  check(leadBattler.mon.pp~=lead.pp and partnerBattler.mon.pp~=partner.pp,'native active PP arrays are separate')
  local doubles={player=leadBattler,enemy=foeBattlerA,playerParty={lead,partner,bench},
    enemyParty={foeA,foeB},battlers={[0]=leadBattler,[1]=foeBattlerA,[2]=partnerBattler,[3]=foeBattlerB}}
  local unhatched=cloneMon();unhatched.isEgg=true
  session.party={cloneMon(),unhatched};native.battle=doubles;emit('battle.started',{kind='trainer',battle=doubles})
  toggle('party_hp',true);toggle('infinite_pp',true);toggle('enemy_burn',true);input()
  for i,m in ipairs(doubles.playerParty)do
    equal(m.hp,70,'battle clone HP restored slot '..i)
    equal(m.pp[1],49,'battle clone PP restored slot '..i)
  end
  equal(leadBattler.mon.hp,70,'lead battler HP restored');equal(partnerBattler.mon.hp,70,'partner battler HP restored')
  equal(leadBattler.mon.pp[1],49,'lead active PP proxy restored');equal(partnerBattler.mon.pp[1],49,'partner active PP proxy restored')
  equal(unhatched.hp,2,'egg HP preserved');equal(unhatched.pp[1],1,'egg PP preserved')
  equal(foeA.status,'BRN','first foe burn');equal(foeB.status,'BRN','second foe burn')
  equal(foeBattlerA.status,'BRN','first foe battler burn');equal(foeBattlerB.status,'BRN','second foe battler burn')
  foeA.status='PSN';foeBattlerA.status='PSN';foeB.status=nil;foeBattlerB.status=nil;foeB.hp=0;foeBattlerB.fainted=true
  input();equal(foeA.status,'PSN','burn preserves existing status');equal(foeB.status,nil,'fainted foe not burned')
  foeB.hp=70;foeBattlerB.fainted=false;doubles.absent={[3]=true};input();equal(foeB.status,nil,'absent foe not burned')
  toggle('party_hp',false);toggle('infinite_pp',false);toggle('enemy_burn',false)
  for _,m in ipairs(doubles.playerParty)do m.hp=1;m.pp[1]=1 end
  leadBattler.mon.pp[1]=1;partnerBattler.mon.pp[1]=1
  foeA.status=nil;foeBattlerA.status=nil;foeB.status=nil;foeBattlerB.status=nil;doubles.absent=nil
  input()
  for i,m in ipairs(doubles.playerParty)do
    equal(m.hp,1,'doubles HP off slot '..i);equal(m.pp[1],1,'doubles PP off slot '..i)
  end
  equal(leadBattler.mon.pp[1],1,'lead active PP off');equal(partnerBattler.mon.pp[1],1,'partner active PP off')
  equal(foeA.status,nil,'first foe burn off');equal(foeB.status,nil,'second foe burn off')
end
-- The final post-input fallback must obey the same egg exclusion as the
-- regular party pass, including an egg occupying the first saved-party slot.
toggle('party_hp',true)
local firstEgg={isEgg=true,hp=2,maxHp=70,moves={}}
game.save.party={firstEgg};session.party={firstEgg};input();equal(firstEgg.hp,2,'first-slot egg HP preserved')
local badEgg={isEgg=true,isBadEgg=true,hp=3,maxHp=70,moves={}}
game.save.party={badEgg};session.party={badEgg};input();equal(badEgg.hp,3,'first-slot bad egg HP preserved')
toggle('party_hp',false)
-- An unloaded mod must stop every cheat, including retained engine wrappers.
toggle('cash',true);toggle('catch_easy',true)
Hooks:removeOwner(mod.id)
local a,b=call('catch.rate',function()return false,11 end);check(not a and b==11,'unloaded hook pass-through')
check(not active('cash'),'unloaded state inactive')
if gen==3 then check(not BattleEngine.canRun({link=false},{},{}),'unloaded wrapper pass-through')end
equal(#warnings,0,'no swallowed hook errors')
print('PASS '..version..': '..checks..' checks, '..supported..' supported codes')
