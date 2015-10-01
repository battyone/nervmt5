local utils = {}

-- Helper method to compare all type of values:
utils.compare = function(lhs,rhs)
	if type(lhs) ~= type(rhs) then
		return false;
	end

	if type(lhs) ~= "table" or lhs.__eq then
		return (lhs == rhs)
	end

	if #lhs ~= #rhs then
		return false
	end

	for k,v in pairs(lhs) do
		if not utils.compare(lhs[k],rhs[k]) then
			return false
		end
	end

	return true
end

string.toHex = function(msg)
	local hex = {}
	for i=1,#msg do
		table.insert(hex,bit.tohex(string.byte(msg:sub(i,i)), -2))
	end
	
	return table.concat(hex)
end

return utils
