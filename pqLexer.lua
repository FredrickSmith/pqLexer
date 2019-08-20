
-- while . do . end
-- repeat . until .
-- if . then . {elseif . then .} [else .] end
local _pq = {}

_pq._t= {
	comment_start         = {
		['--'] = true,
		['//'] = true, -- garry operator
	},
	comment_block_start   = {
		['--[['] = true,
		['/*'  ] = true, -- garry operator
	},
	comment_block_end     = {
		[']]'] = true,
		['*/'] = true, -- garry operator
	},
	comment_start_symbols = {
		['-'] = true,
		['['] = true,
		['/'] = true,
		['*'] = true,
		['='] = true,
	},
	comment_end_symbols   = {
		[']'] = true,
		['*'] = true,
		['/'] = true,
		['='] = true,
	},
	comment_starters      = {
		['-'] = true,
		['/'] = true,
	},
	comment_block_pairs   = {
		['--[['] = ']]',
		['/*'  ] = '*/',
	},
	inline_tokens         = {
		['='] = true,
		['~'] = true,
		['+'] = true,
		['-'] = true,
		['*'] = true,
		['/'] = true,
		['%'] = true,
		['^'] = true,
		['#'] = true,
		['!'] = true, -- garry operator
	},
	inline_comparisons    = {
		['=='] = true,
		['~='] = true,
		['!='] = true, -- garry operator
		['<='] = true,
		['>='] = true,
		['<' ] = true,
		['>' ] = true,
	},
	inline_operators      = {
		['and'] = true,
		['or' ] = true,
		['&&' ] = true, -- garry operator
		['||' ] = true, -- garry operator
	},
	whitespace            = {
		[' ' ] = true,
		['	'] = true,
		[';' ] = true,
		['\n'] = true,
	},
	scope_start           = {
		['then'  ] = true,
		['do'    ] = true,
		['repeat'] = true,
	},
	scope_end             = {
		['end']    = true,
		['untill'] = true,
	},
	string_start          = {
		['\''] = true,
		['\"'] = true,
	},
	string_end            = {
		['\''] = true,
		['\"'] = true,
	},
	string_pairs          = {
		['\''] = '\'',
		['\"'] = '\"'
	},
	string_block_start    = {
		['[['] = true,
	},
	string_block_end      = {
		[']]'] = true,
	},
	string_block_pairs    = {
		['[['] = ']]',
	},
	string_symbols        = {
		['\''] = true,
		['\"'] = true,
		['[' ] = true,
	},
	boolean               = {
		['true' ] = true,
		['false'] = true,
		['nil'  ] = true,
	},
	number                = {
		['0x'] = true,
		['0' ] = true,
		['1' ] = true,
		['2' ] = true,
		['3' ] = true,
		['4' ] = true,
		['5' ] = true,
		['6' ] = true,
		['7' ] = true,
		['8' ] = true,
		['9' ] = true,
	},
	other_symbols          = {
		['('] = true,
		[')'] = true,
		['{'] = true,
		['}'] = true,
		[':'] = true,
		['.'] = true,
	}
}

_pq.number_pattern = {
	'%d+'                   , -- 1
	'%.%d+'                 , --  .1
	'%d+%.%d+'              , -- 1.1
	'%.%d*[eE][%-%+]?%d+'   , --  .1[eE][-+]1
	'%d+%.%d*[eE][%-%+]?%d+', -- 1.1[eE][-+]1
	'0x[%x]+'               , -- 0x1
}

local pq = {
	txt    = '',
	pos    =  1,
	len    =  0,
	scope  =  0,
	buffer = {},
}

function pq:lookahead  (len) -- incorrect?
	local  pos = utf8.offset (self.txt, self.pos + len)
	local _pos = utf8.offset (self.txt, self.pos + len + 1)

	_pos = _pos and _pos - 1 or pos

	return self.txt:sub (pos, _pos)
end
function pq:lookbehind  (len) -- incorrect?
	local  pos = utf8.offset (self.txt, self.pos - len)
	local _pos = utf8.offset (self.txt, self.pos - len - 1)

	_pos = _pos and _pos + 1 or pos

	return self.txt:sub (_pos, pos)
end

function pq:lookaheaduntil (tkn, pos, cause, spos)
	tkn = {tkn}

	pos = pos

	while true do
		local c = self:lookahead (pos)

		local num = cause (c, pos)

		if num then
			if not spos then
				self.pos = self.pos + pos + num
			end

			break
		end

		tkn [#tkn + 1] = c

		pos = pos + 1
	end

	return table.concat (tkn)
end
function pq:lookbehinduntil (tkn, pos, cause, spos)
	tkn = {tkn}
	pos = pos

	while true do
		local c = self:lookbehind (-pos)

		local num = cause (c, pos)

		if num then
			if not spos then
				self.pos = self.pos + pos + num
			end

			break
		end

		tkn [#tkn + 1] = c

		pos = pos - 1
	end

	return table.concat (tkn)
end

function pq:lex (txt)
	self.txt = txt
	self.len = utf8.len (txt)
	self.pos = 1

	while true do
		if self.pos > self.len then break end

		local _c = self:lookahead (0)

		if _pq._t.whitespace       [_c] then -- whitespace
			local tkn = self:lookaheaduntil (_c, 1,
				function (c, pos) if not _pq._t.whitespace [c] then return -1 end end)

			local pp = not tkn:find ' ' and 'T' or not tkn:find '	' and 'S' or 'C'

			print (self.pos, 'WS', pp, #tkn)
			goto found
		end

		if _pq._t.comment_starters [_c] then -- comment
			local tkn = self:lookaheaduntil (_c, 1,
				function (c, pos) if pos == 2 then return -1 end end)

			if tkn == '--' then -- --, --[[]], --[=[]=]
				local blk = self:lookaheaduntil ('', 2,
						function (c, pos) if (c ~= '[') and (c ~= '=') then return 1 end end, true)

				if (self:lookahead (1) == '[') and (blk:match '.$' == '[') then -- --[[]], --[=[]=]
					local content

					if self:lookahead (2) == '=' then -- --[=[]=]
						local eq = #self:lookaheaduntil ('', 2,
							function (c, pos) if c == '[' then return -1 end end)

						content = self:lookaheaduntil ('', 2, 
							function (c, pos)
								if (c == ']') and (self:lookahead (pos + 1) == '=') then
									local eqs = self:lookaheaduntil ('', pos + 1,
										function (c, pos) if c ~= '=' then return 0 end end, true)

									if (#eqs == eq) and (self:lookahead (pos + eq + 1) == ']') then
										return eq + 1
									end
								end
							end)
					else -- --[[]]
						content = self:lookaheaduntil ('', 3, 
							function (c, pos) if c..self:lookahead (pos + 1) == ']]' then return 1 end end)
					end

					print (self.pos, 'ML-C', content)
					goto found
				else -- --
					local content = self:lookaheaduntil ('', 1,
						function (c, pos) if c == '\n' or c == '' then return -1 end end)

					print (self.pos, 'SL-C', content)
					goto found
				end
			end

			if tkn == '//' then -- //
				local content = self:lookaheaduntil ('', 1, 
					function (c, pos) if c == '\n' or c == '' then return -1 end end)

				print (self.pos, 'SL-C', content)
				goto found
			end

			if tkn == '/*' then -- /**/
				local content = self:lookaheaduntil ('', 1, 
					function (c, pos) if c..self:lookahead (pos + 1) == '*/' then return 1 end end)

				print (self.pos, 'ML-C', content)
				goto found
			end

			-- error 'comment start but no comment start' -- not comment after all
		end

		if _pq._t.string_symbols   [_c] then -- string
			if (_c == '\'') or (_c == '"') then -- '', ""
				local content = self:lookaheaduntil ('', 1,
					function (c, pos)
						if _c == c then
							if self:lookbehind (-pos + 1) == '\\' then
								local slash = self:lookbehinduntil ('\\', pos - 1,
									function (c, pos) return c ~= '\\' end, true)

								if (#slash % 2) == 1 then return 0 end

								return
							end

							return 0
						end
					end)

				print (self.pos, 'SL-S', content)
				goto found
			end

			if (_c == '[') and ((self:lookahead (1) == '=') or (self:lookahead (1) == '[')) then -- [[]], [=[]=]

				local content
				if self:lookahead (1) == '=' then -- [=[]=]
					local eq = #self:lookaheaduntil ('', 1,
						function (c, pos) if c == '[' then return -1 end end)

					content = self:lookaheaduntil ('', 2, 
						function (c, pos)
							if (c == ']') and (self:lookahead (pos + 1) == '=') then
								local eqs = self:lookaheaduntil ('', pos + 1,
									function (c, pos) if c ~= '=' then return 0 end end, true)

								if (#eqs == eq) and (self:lookahead (pos + eq + 1) == ']') then
									return eq + 1
								end
							end
						end)
				else -- [[]]
					content = self:lookaheaduntil ('', 2, 
						function (c, pos) if c..self:lookahead (pos + 1) == ']]' then return 1 end end)
				end

				print (self.pos, 'ML-S', content)
				goto found
			end

			-- error 'string start but no string start' -- not string after all
		end

		if  not _pq._t.inline_tokens         [_c] and
			not _pq._t.inline_comparisons    [_c] and
			not _pq._t.comment_start_symbols [_c] and
			not _pq._t.comment_end_symbols   [_c] and
			not _pq._t.string_symbols        [_c] and
			not _pq._t.whitespace            [_c] and
			not _pq._t.other_symbols         [_c] and _c ~= ',' then

			local tkn = self:lookaheaduntil (_c, 1,
				function (c, pos)
					-- if (c == '.') or (c == ':') or (c == '(') or (c == ')') or (c == '[') or (c == ']') or (c == ' ') then return end
					if  _pq._t.inline_tokens         [c] or
						_pq._t.inline_comparisons    [c] or
						_pq._t.comment_start_symbols [c] or
						_pq._t.comment_end_symbols   [c] or
						_pq._t.string_symbols        [c] or
						_pq._t.whitespace            [c] or
						_pq._t.other_symbols         [c] or c == '' or c == ',' then -- eof, fk commas
						return -1
					end
				end)

			-- print ('token', tkn, string.byte (tkn))
			print (self.pos, 'TK', tkn)
			goto found
		end

		print (self.pos, 'NH', _c)

		::found::
		self.pos = self.pos + 1
		::skip::
	end

	return self.buffer
end

function pq:pretty (buffer)

end

--[= []]

-- pq:lex 'local a = \'a\' --[= [=wtf]]--a'
-- pq:lex 'local a = \'a\' --[= []=]'
-- pq:lex 'local a = [[wtflol]]--[[wtf]]--lol\n--lol\n--[[]]--okay'
-- pq:lex 'local a = [[wtflol]]/*wtf*///lol\n//lol\n/**///okay'
-- pq:lex 'local a = [[txt]=] ]]--lol\n'
-- pq:lex 'local a = [==[txt]===]] ==]]==]--lol'
-- pq:lex 'local a = \'a\' --[==[[==[[[[sasaa]===]]== ]]==]--a'
-- pq:lex 'local a = \'a\' /*/**** /sasaa* / /* /*///a'
-- pq:lex 'local a = \'a\' --[==[wtf!]===]]====] ]]==]-- a'
-- pq:lex 'local a = \'a\' --[=====[wtf!]===]]====] ]]========]]]]]]=]=====]-- a'
-- pq:lex [[local a = '\\\\' -- 'lol]] local a = '\\\\' -- 'lol
-- pq:lex [[local a = '\\\\\' --'--lol]] local a = '\\\\\' --'--lol
-- pq:lex [[local a = '\\\\\\' --'--lol]] local a = '\\\\\\' --'--lol
-- pq:lex [[local a = '\\\\\\\' --'--lol]] local a = '\\\\\\\' --'--lol
-- pq:lex [[local a = '\\\\\\\\' --'--lol]] local a = '\\\\\\\\' --'--lol
-- pq:lex 'local a = \'a\' --[[lol]] --|a|'

-- pq:lex 'local	a, b 	= \'a\', [[b]] --[[c]] -- d'

local r = function (a)
          a = assert (io.open (a, 'rb'))
	local b = a:read '*a'
	a:close ()
	return b
end

-- pq:lex (r 'lex/lex_test_1.lua')
-- pq:lex (r 'lex/lex_test_2.lua')
-- pq:lex (r 'lex/lex_test_3.lua')
