return function(mod)
 local M={}
 function M.fromNational(n,game)
  n=tonumber(n)
  if not n or n%1~=0 or n<1 or n>1025 then return nil end
  local rows=game and game.data and game.data.pokemon or {}
  if mod.find then
   local ok,dex=pcall(mod.find,'1025dex')
   local api=ok and dex and dex.exports and dex.exports.speciesNumbers
   if api and api.speciesFromNational then
    local resolved,id=pcall(api.speciesFromNational,n)
    if resolved and type(id)=='string' and (rows[id] or mod.content.pokemon:get(id)) then return id end
   end
  end
  local candidates={}
  for id,row in pairs(rows)do
   if type(id)=='string' and type(row)=='table' and not row.form and tonumber(row.dex)==n then candidates[#candidates+1]=id end
  end
  if #candidates==0 then
   for id,row in mod.content.pokemon:each()do
    if type(id)=='string' and type(row)=='table' and not row.form and tonumber(row.dex)==n then candidates[#candidates+1]=id end
   end
  end
  table.sort(candidates);return candidates[1]
 end
 return M
end
