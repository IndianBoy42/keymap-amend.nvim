local api = vim.api

local termcodes = vim.keycode

---Returns if two key sequence are equal or not.
---@param a string
---@param b string
---@return boolean
local function keymap_equals(a, b)
	return termcodes(a) == termcodes(b)
end

---Returns the function constructed from the passed keymap object on call of
---which the original keymapping will be executed.
---@param map table keymap object
---@return function
local function get_original(map)
	local keys, fmode
	fmode = map.noremap and "in" or "im"
	if map.expr then
		if map.callback then
			return function()
				keys = map.callback()
				keys = termcodes(keys)
				api.nvim_feedkeys(keys, fmode, false)
			end
		else
			return function()
				keys = api.nvim_eval(map.rhs)
				keys = termcodes(keys)
				api.nvim_feedkeys(keys, fmode, false)
			end
		end
	elseif map.callback then
		return map.callback
	else
		keys = map.rhs
		keys = termcodes(keys)
		return function()
			api.nvim_feedkeys(keys, fmode, false)
		end
	end
end

---Get map
---@param mode string
---@param lhs string
---@return table
local function get_map_if_exists(mode, lhs)
	local res

	for _, map in ipairs(api.nvim_buf_get_keymap(0, mode)) do
		if keymap_equals(map.lhs, lhs) then
			res = {
				lhs = map.lhs,
				rhs = map.rhs or "",
				expr = map.expr == 1,
				callback = map.callback,
				noremap = map.noremap == 1,
				script = map.script == 1,
				silent = map.silent == 1,
				nowait = map.nowait == 1,
				buffer = true,
			}
		end
	end

	if not res then
		for _, map in ipairs(api.nvim_get_keymap(mode)) do
			if keymap_equals(map.lhs, lhs) then
				res = {
					lhs = map.lhs,
					rhs = map.rhs or "",
					expr = map.expr == 1,
					callback = map.callback,
					noremap = map.noremap == 1,
					script = map.script == 1,
					silent = map.silent == 1,
					nowait = map.nowait == 1,
					buffer = false,
				}
			end
		end
	end

	return res
end
local function get_map(mode, lhs)
	local res = get_map_if_exists(mode, lhs)

	if not res then
		res = {
			lhs = lhs,
			rhs = lhs,
			expr = false,
			callback = nil,
			noremap = true,
			script = false,
			silent = true,
			nowait = false,
			buffer = false,
		}
	end

	res.original = get_original

	return res
end

local function amend_map(mode, map, rhs, opts)
	local original = map:original()
	opts = opts or {}
	opts.desc = table.concat({
		"[keymap-amend.nvim",
		(opts.desc and ": " .. opts.desc or ""),
		"] ",
		map.desc or "",
	})
	vim.keymap.set(mode, lhs, function()
		rhs(original)
	end, opts)
end

---@param mode string
---@param lhs string
---@param rhs string | function
---@param opts? table
local function amend_if_exists(mode, lhs, rhs, opts)
	local map = get_map_if_exists(mode, lhs)
	if map == nil then
		return
	end
	return amend_map(mode, map, rhs, opts)
end
local function amend(mode, lhs, rhs, opts)
	local map = get_map(mode, lhs)
	return amend_map(mode, map, rhs, opts)
end

---Amend the existing keymap.
---@param mode string | string[]
---@param lhs string
---@param rhs string | function
---@param opts? table
local function modes_amend_if_exists(mode, lhs, rhs, opts)
	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			amend_if_exists(m, lhs, rhs, opts)
		end
	else
		amend_if_exists(mode, lhs, rhs, opts)
	end
end
local function modes_amend(mode, lhs, rhs, opts)
	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			amend(m, lhs, rhs, opts)
		end
	else
		amend(mode, lhs, rhs, opts)
	end
end

return setmetatable({
	get = get_map,
	get_if = get_map_if_exists,
	original = get_original,
	amend = modes_amend,
	amend_of = modes_amend_if_exists,
}, {
	__call = function(t, ...)
		modes_amend(...)
	end,
})
