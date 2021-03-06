function village_at_point(minp, noise1)
	local bseed
	for xi = -2, 2 do
	for zi = -2, 0 do
		if xi~=0 or zi~=0 then
			local pi = PseudoRandom(get_bseed({x=minp.x+80*xi, z=minp.z+80*zi})) 
			if pi:next(1,400)<=28 and noise1:get2d({x=minp.x+80*xi, z=minp.z+80*zi})>-0.3 then return 0,0,0,0 end
		end
	end
	end
	local pr = PseudoRandom(get_bseed(minp))
	if pr:next(1,400)>28 then return 0,0,0,0 end
	local x = pr:next(minp.x, minp.x+79)
	local z = pr:next(minp.z, minp.z+79)
	if noise1:get2d({x=x, y=z})<-0.3 then return 0,0,0,0 end
	local size = pr:next(20, 40)
	local height = pr:next(5, 20)
	print("A village spawned at: x="..x..", z="..z)
	return x,z,size,height
end

--local function dist_center2(ax, bsizex, az, bsizez)
--	return math.max((ax+bsizex)*(ax+bsizex),ax*ax)+math.max((az+bsizez)*(az+bsizez),az*az)
--end

local function inside_village2(bx, sx, bz, sz, vx, vz, vs, vnoise)
	return inside_village(bx, bz, vx, vz, vs, vnoise) and inside_village(bx+sx, bz, vx, vz, vs, vnoise) and inside_village(bx, bz+sz, vx, vz, vs, vnoise) and inside_village(bx+sx, bz+sz, vx, vz, vs, vnoise)
end

local function choose_building(l, pr)
	::choose::
	p = pr:next(1, 3000)
	for b, i in ipairs(buildings) do
		if i.max_weight > p then
			btype = b
			break
		end
	end
	if buildings[btype].pervillage ~= nil then
		local n = 0
		for j=1, #l do
			if l[j].btype == btype then
				n = n + 1
			end
		end
		if n >= buildings[btype].pervillage then
			goto choose
		end
	end
	return btype
end

local function choose_building_rot(l, pr, orient)
	local btype = choose_building(l, pr)
	local rotation
	if buildings[btype].no_rotate then
		rotation = 0
	else
		if buildings[btype].orients == nil then
			buildings[btype].orients = {0,1,2,3}
		end
		rotation = (orient+buildings[btype].orients[pr:next(1, #buildings[btype].orients)])%4
	end
	bsizex = buildings[btype].sizex
	bsizez = buildings[btype].sizez
	if rotation%2 == 1 then
		bsizex, bsizez = bsizez, bsizex
	end
	return btype, rotation, bsizex, bsizez
end

local function placeable(bx, bz, bsizex, bsizez, l, exclude_roads)
	for _, a in ipairs(l) do
		if (a.btype ~= "road" or not exclude_roads) and math.abs(bx+bsizex/2-a.x-a.bsizex/2)<=(bsizex+a.bsizex)/2 and math.abs(bz+bsizez/2-a.z-a.bsizez/2)<=(bsizez+a.bsizez)/2 then return false end
	end
	return true
end

local function road_in_building(rx, rz, rdx, rdz, roadsize, l)
	if rdx == 0 then
		return not placeable(rx-roadsize+1, rz, 2*roadsize-2, 0, l, true)
	else
		return not placeable(rx, rz-roadsize+1, 0, 2*roadsize-2, l, true)
	end
end

local function when(a, b, c)
	if a then return b else return c end
end

local function generate_road(vx, vz, vs, vh, l, pr, roadsize, rx, rz, rdx, rdz, vnoise)
	local calls_to_do = {}
	local rxx = rx
	local rzz = rz
	local mx, m2x, mz, m2z, mmx, mmz
	mx, m2x, mz, m2z = rx, rx, rz, rz
	local orient1, orient2
	if rdx == 0 then
		orient1 = 0
		orient2 = 2
	else
		orient1 = 3
		orient2 = 1
	end
	while inside_village(rx, rz, vx, vz, vs, vnoise) and not road_in_building(rx, rz, rdx, rdz, roadsize, l) do
		if roadsize > 1 and pr:next(1, 4) == 1 then
			--generate_road(vx, vz, vs, vh, l, pr, roadsize-1, rx, rz, math.abs(rdz), math.abs(rdx))
			calls_to_do[#calls_to_do+1] = {rx=rx+(roadsize - 1)*rdx, rz=rz+(roadsize - 1)*rdz, rdx=math.abs(rdz), rdz=math.abs(rdx)}
			m2x = rx + (roadsize - 1)*rdx
			m2z = rz + (roadsize - 1)*rdz
			rx = rx + (2*roadsize - 1)*rdx
			rz = rz + (2*roadsize - 1)*rdz
		end
		--else
			::loop::
			if not inside_village(rx, rz, vx, vz, vs, vnoise) or road_in_building(rx, rz, rdx, rdz, roadsize, l) then goto exit1 end
			btype, rotation, bsizex, bsizez = choose_building_rot(l, pr, orient1)
			local bx = rx + math.abs(rdz)*(roadsize+1) - when(rdx==-1, bsizex-1, 0)
			local bz = rz + math.abs(rdx)*(roadsize+1) - when(rdz==-1, bsizez-1, 0)
			if not placeable(bx, bz, bsizex, bsizez, l) or not inside_village2(bx, bsizex, bz, bsizez, vx, vz, vs, vnoise) then--dist_center2(bx-vx, bsizex, bz-vz, bsizez)>vs*vs then
				rx = rx + rdx
				rz = rz + rdz
				goto loop
			end
			rx = rx + (bsizex+1)*rdx
			rz = rz + (bsizez+1)*rdz
			mx = rx - 2*rdx
			mz = rz - 2*rdz
			l[#l+1] = {x=bx, y=vh, z=bz, btype=btype, bsizex=bsizex, bsizez=bsizez, brotate = rotation}
		--end
	end
	::exit1::
	rx = rxx
	rz = rzz
	while inside_village(rx, rz, vx, vz, vs, vnoise) and not road_in_building(rx, rz, rdx, rdz, roadsize, l) do
		if roadsize > 1 and pr:next(1, 4) == 1 then
			--generate_road(vx, vz, vs, vh, l, pr, roadsize-1, rx, rz, -math.abs(rdz), -math.abs(rdx))
			calls_to_do[#calls_to_do+1] = {rx=rx+(roadsize - 1)*rdx, rz=rz+(roadsize - 1)*rdz, rdx=-math.abs(rdz), rdz=-math.abs(rdx)}
			m2x = rx + (roadsize - 1)*rdx
			m2z = rz + (roadsize - 1)*rdz
			rx = rx + (2*roadsize - 1)*rdx
			rz = rz + (2*roadsize - 1)*rdz
		end
		--else
			::loop::
			if not inside_village(rx, rz, vx, vz, vs, vnoise) or road_in_building(rx, rz, rdx, rdz, roadsize, l) then goto exit2 end
			btype, rotation, bsizex, bsizez = choose_building_rot(l, pr, orient2)
			local bx = rx - math.abs(rdz)*(bsizex+roadsize) - when(rdx==-1, bsizex-1, 0)
			local bz = rz - math.abs(rdx)*(bsizez+roadsize) - when(rdz==-1, bsizez-1, 0)
			if not placeable(bx, bz, bsizex, bsizez, l) or not inside_village2(bx, bsizex, bz, bsizez, vx, vz, vs, vnoise) then--dist_center2(bx-vx, bsizex, bz-vz, bsizez)>vs*vs then
				rx = rx + rdx
				rz = rz + rdz
				goto loop
			end
			rx = rx + (bsizex+1)*rdx
			rz = rz + (bsizez+1)*rdz
			m2x = rx - 2*rdx
			m2z = rz - 2*rdz
			l[#l+1] = {x=bx, y=vh, z=bz, btype=btype, bsizex=bsizex, bsizez=bsizez, brotate = rotation}
		--end
	end
	::exit2::
	if road_in_building(rx, rz, rdx, rdz, roadsize, l) then
		mmx = rx - 2*rdx
		mmz = rz - 2*rdz
	end
	mx = mmx or rdx*math.max(rdx*mx, rdx*m2x)
	mz = mmz or rdz*math.max(rdz*mz, rdz*m2z)
	if rdx == 0 then
		rxmin = rx - roadsize + 1
		rxmax = rx + roadsize - 1
		rzmin = math.min(rzz, mz)
		rzmax = math.max(rzz, mz)
	else
		rzmin = rz - roadsize + 1
		rzmax = rz + roadsize - 1
		rxmin = math.min(rxx, mx)
		rxmax = math.max(rxx, mx)
	end
	l[#l+1] = {x=rxmin, y=vh, z=rzmin, btype="road", bsizex=rxmax-rxmin+1, bsizez=rzmax-rzmin+1, brotate = 0}
	for _,i in ipairs(calls_to_do) do
		generate_road(vx, vz, vs, vh, l, pr, roadsize-1, i.rx, i.rz, i.rdx, i.rdz, vnoise)
	end
end

local function generate_bpos(vx, vz, vs, vh, pr, vnoise)
	--[=[local l={}
	local total_weight = 0
	for _, i in ipairs(buildings) do
		if i.weight == nil then i.weight = 1 end
		total_weight = total_weight+i.weight
		i.max_weight = total_weight
	end
	local multiplier = 3000/total_weight
	for _,i in ipairs(buildings) do
		i.max_weight = i.max_weight*multiplier
	end
	for i=1, 2000 do
		bx = pr:next(vx-vs, vx+vs)
		bz = pr:next(vz-vs, vz+vs)
		::choose::
		--[[btype = pr:next(1, #buildings)
		if buildings[btype].chance ~= nil then
			if pr:next(1, buildings[btype].chance) ~= 1 then
				goto choose
			end
		end]]
		p = pr:next(1, 3000)
		for b, i in ipairs(buildings) do
			if i.max_weight > p then
				btype = b
				break
			end
		end
		if buildings[btype].pervillage ~= nil then
			local n = 0
			for j=1, #l do
				if l[j].btype == btype then
					n = n + 1
				end
			end
			if n >= buildings[btype].pervillage then
				goto choose
			end
		end
		local rotation
		if buildings[btype].no_rotate then
			rotation = 0
		else
			rotation = pr:next(0, 3)
		end
		bsizex = buildings[btype].sizex
		bsizez = buildings[btype].sizez
		if rotation%2 == 1 then
			bsizex, bsizez = bsizez, bsizex
		end
		if dist_center2(bx-vx, bsizex, bz-vz, bsizez)>vs*vs then goto out end
		for _, a in ipairs(l) do
			if math.abs(bx-a.x)<=(bsizex+a.bsizex)/2+2 and math.abs(bz-a.z)<=(bsizez+a.bsizez)/2+2 then goto out end
		end
		l[#l+1] = {x=bx, y=vh, z=bz, btype=btype, bsizex=bsizex, bsizez=bsizez, brotate = rotation}
		::out::
	end
	return l]=]--
	local l={}
	local rx = vx-vs
	local rz = vz
	while inside_village(rx, rz, vx, vz, vs, vnoise) do
		rx = rx - 1
	end
	rx = rx + 5
	generate_road(vx, vz, vs, vh, l, pr, 3, rx, rz, 1, 0, vnoise)
	return l
	--[=[while rx1 < vx+vs do
		local building = choose_building(l, pr)
		local rotation
		if buildings[btype].no_rotate then
			rotation = 0
		else
			rotation = pr:next(0, 3)
		end
		bsizex = buildings[btype].sizex
		bsizez = buildings[btype].sizez
		if rotation%2 == 1 then
			bsizex, bsizez = bsizez, bsizex
		end
		local bx = rx1
		rx1 = rx1+bsizex+1
		local bz = rz - bsizez - 3
		if dist_center2(bx-vx, bsizex, bz-vz, bsizez)>vs*vs then goto out end
		l[#l+1] = {x=bx, y=vh, z=bz, btype=btype, bsizex=bsizex, bsizez=bsizez, brotate = rotation}
		::out::
	end
	while rx2 < vx+vs do
		local building = choose_building(l, pr)
		local rotation
		if buildings[btype].no_rotate then
			rotation = 0
		else
			rotation = pr:next(0, 3)
		end
		bsizex = buildings[btype].sizex
		bsizez = buildings[btype].sizez
		if rotation%2 == 1 then
			bsizex, bsizez = bsizez, bsizex
		end
		local bx = rx2
		rx2 = rx2+bsizex+1
		local bz = rz + 3
		if dist_center2(bx-vx, bsizex, bz-vz, bsizez)>vs*vs then goto out end
		l[#l+1] = {x=bx, y=vh, z=bz, btype=btype, bsizex=bsizex, bsizez=bsizez, brotate = rotation}
		::out::
	end
	return l]=]
end

local function generate_building(pos, minp, maxp, data, a, pr, extranodes)
	local binfo = buildings[pos.btype]
	local scm
	if type(binfo.scm) == "string" then
		scm = import_scm(binfo.scm)
	else
		scm = binfo.scm
	end
	scm = rotate(scm, pos.brotate)
	local t
	for x = 0, pos.bsizex-1 do
	for y = 0, binfo.ysize-1 do
	for z = 0, pos.bsizez-1 do
		ax, ay, az = pos.x+x, pos.y+y+binfo.yoff, pos.z+z
		if (ax >= minp.x and ax <= maxp.x) and (ay >= minp.y and ay <= maxp.y) and (az >= minp.z and az <= maxp.z) then
			t = scm[y+1][x+1][z+1]
			if type(t) == "table" then
				table.insert(extranodes, {node=t.node, meta=t.meta, pos={x=ax, y=ay, z=az},})
			elseif t~=c_ignore then
				data[a:index(ax, ay, az)] = t
			end
		end
	end
	end
	end
end

local MIN_DIST = 2

local function pos_far_buildings(x, z, l)
	for _,a in ipairs(l) do
		if a.x-MIN_DIST<=x and x<=a.x+a.bsizex+MIN_DIST and a.z-MIN_DIST<=z and z<=a.z+a.bsizez+MIN_DIST then
			return false
		end
	end
	return true
end

function generate_village(vx, vz, vs, vh, minp, maxp, data, a, vnoise, to_grow)
	local seed = get_bseed({x=vx, z=vz})
	local pr = PseudoRandom(seed)
	local bpos = generate_bpos(vx, vz, vs, vh, pr, vnoise)
	local extranodes = {}
	for _, pos in ipairs(bpos) do
		generate_building(pos, minp, maxp, data, a, pr, extranodes)
	end
	local pr = PseudoRandom(seed)
	for _, g in ipairs(to_grow) do
		if pos_far_buildings(g.x, g.z, bpos) then
			if g.content == c_sapling then
				add_tree(data, a, g.x, g.y, g.z, minp, maxp, c_tree, c_leaves, pr)
			elseif g.content == c_junglesapling then
				add_jungletree(data, a, g.x, g.y, g.z, minp, maxp, c_jungletree, c_jungleleaves, pr)
			elseif g.content == c_savannasapling then
				add_savannatree(data, a, g.x, g.y, g.z, minp, maxp, c_savannatree, c_savannaleaves, pr)
			elseif g.content == "savannabush" then
				add_savannabush(data, a, g.x, g.y, g.z, minp, maxp, c_savannatree, c_savannaleaves, pr)
			elseif g.content == c_pinesapling then
				add_pinetree(data, a, g.x, g.y, g.z, minp, maxp, c_pinetree, c_pineleaves, c_snow, pr)
			elseif g.content == c_cactus then
				ch = pr:next(0, 3)
				for yy = math.max(g.y, minp.y), math.min(g.y+ch, maxp.y) do
					data[a:index(x, yy, z)] = c_cactus
				end
			elseif g.content == c_papyrus then
				ch = pr:next(1, 3)
				for yy = math.max(g.y, minp.y), math.min(g.y+ch, maxp.y) do
					data[a:index(x, yy, z)] = c_papyrus
				end
			end
		end
	end
	return extranodes
end
