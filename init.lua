local DMAX = 20
local AREA_SIZE = 80

minetest.register_on_mapgen_init(function(mgparams)
        minetest.set_mapgen_params({mgname="singlenode", flags="nolight", flagmask="nolight"})
end)

local cache = {}

local function cliff(x, n)
	return 0.2*x*x - x + n*x - n*n*x*x - 0.01 * math.abs(x*x*x) + math.abs(x)*100*n*n*n*n
end

local function get_base_surface_at_point(x, z, vn, vh, noise1, noise2, noise3, noise4)
	local index = 65536*x+z
	if cache[index] ~= nil then return cache[index] end
	cache[index] = 25*(noise1:get2d({x=x, y=z})+noise2:get2d({x=x, y=z})*noise3:get2d({x=x, y=z})/3)
	if noise4:get2d({x=x, y=z}) > 0.8 then
		cache[index] = cliff(cache[index], noise4:get2d({x=x, y=z})-0.8)
	end
	if vn<40 then
		cache[index] = vh
	elseif vn<200 then
		cache[index] = (vh*(200-vn) + cache[index]*(vn-40))/160
	end
	return cache[index]
end

local function surface_at_point(x, z, ...)
	return get_base_surface_at_point(x, z, unpack({...}))
end

local SMOOTHED = AREA_SIZE+2*DMAX
local HSMOOTHED = AREA_SIZE+DMAX
local INSIDE = AREA_SIZE-DMAX

local function smooth(x, z, ...)
	local s=0
	local w=0
	for xi=-DMAX, DMAX do
	for zi=-DMAX, DMAX do
		local d2=xi*xi+zi*zi
		if d2<DMAX*DMAX then
			local w1 = 1-d2/(DMAX*DMAX)
			local w2 = 15/16*w1*w1
			w = w+w2
			s=s+w2*surface_at_point(x+xi, z+zi, unpack({...}))
		end
	end
	end
	return s/w
end

local function smooth_surface(x, z, vnoise, vx, vz, vs, vh, ...)
	local vn
	if vs ~= 0 then
		vn = (vnoise:get2d({x=x, y=z})-2)*20+(40/(vs*vs))*((x-vx)*(x-vx)+(z-vz)*(z-vz))
	else
		vn = 1000
	end
	return surface_at_point(x, z, vn, vh, unpack({...}))
end

minetest.register_on_mapgen_init(function(mgparams)
	wseed = math.floor(mgparams.seed/10000000000)
end)
function get_bseed(minp)
	return wseed + math.floor(5*minp.x/47) + math.floor(873*minp.z/91)
end

function get_bseed2(minp)
	return wseed + math.floor(87*minp.x/47) + math.floor(73*minp.z/91) + math.floor(31*minp.y/45)
end

local c_air = minetest.get_content_id("air")
local c_ignore = minetest.get_content_id("ignore")

local function add_leaves(data, vi, c_leaves)
	if data[vi]==c_air or data[vi]==c_ignore then
		data[vi] = c_leaves
	end
end

local function add_tree(data, a, x, y, z, minp, maxp, c_tree, c_leaves, pr)
	th = pr:next(3, 4)
	for yy=math.max(minp.y, y), math.min(maxp.y, y+th) do
		local vi = a:index(x, yy, z)
		data[vi] = c_tree
	end
	maxy = y+th
	for xx=math.max(minp.x, x-1), math.min(maxp.x, x+1) do
	for yy=math.max(minp.y, maxy-1), math.min(maxp.y, maxy+1) do
	for zz=math.max(minp.z, z-1), math.min(maxp.z, z+1) do
		add_leaves(data, a:index(xx, yy, zz), c_leaves)
	end
	end
	end
	for i=1,8 do
		xi = pr:next(x-2, x+1)
		yi = pr:next(maxy-1, maxy+1)
		zi = pr:next(z-1, z+1)
		for xx=math.max(minp.x, xi), math.min(maxp.x, xi+1) do
		for yy=math.max(minp.y, yi), math.min(maxp.y, yi+1) do
		for zz=math.max(minp.z, zi), math.min(maxp.z, zi+1) do
			add_leaves(data, a:index(xx, yy, zz), c_leaves)
		end
		end
		end
	end
end

local function add_jungletree(data, a, x, y, z, minp, maxp, c_tree, c_leaves, pr)
	th = pr:next(7, 11)
	for yy=math.max(minp.y, y), math.min(maxp.y, y+th) do
		local vi = a:index(x, yy, z)
		data[vi] = c_tree
	end
	maxy = y+th
	for xx=math.max(minp.x, x-1), math.min(maxp.x, x+1) do
	for yy=math.max(minp.y, maxy-1), math.min(maxp.y, maxy+1) do
	for zz=math.max(minp.z, z-1), math.min(maxp.z, z+1) do
		add_leaves(data, a:index(xx, yy, zz), c_leaves)
	end
	end
	end
	for i=1,30 do
		xi = pr:next(x-3, x+2)
		yi = pr:next(maxy-2, maxy+1)
		zi = pr:next(z-3, z+2)
		for xx=math.max(minp.x, xi), math.min(maxp.x, xi+1) do
		for yy=math.max(minp.y, yi), math.min(maxp.y, yi+1) do
		for zz=math.max(minp.z, zi), math.min(maxp.z, zi+1) do
			add_leaves(data, a:index(xx, yy, zz), c_leaves)
		end
		end
		end
	end
end

dofile(minetest.get_modpath(minetest.get_current_modname()).."/buildings.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/villages.lua")

minetest.register_on_generated(function(minp, maxp, seed)
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local a = VoxelArea:new{
		MinEdge={x=emin.x, y=emin.y, z=emin.z},
		MaxEdge={x=emax.x, y=emax.y, z=emax.z},
	}
	
	local treemin = {x=emin.x, y=minp.y, z=emin.z}
	local treemax = {x=emax.x, y=maxp.y, z=emax.z}
	
	local vx,vz,vs,vh
	for xi = -1, 1 do
	for zi = -1, 1 do
		vx,vz,vs,vh = village_at_point({x=minp.x+xi*80,z=minp.z+zi*80})
		if vs ~= 0 then goto out end
	end
	end
	::out::
	
	local pr = PseudoRandom(get_bseed(minp))
	
	local village_noise = minetest.get_perlin(7635, 6, 0.5, 256)
	local noise1 = minetest.get_perlin(12345, 6, 0.5, 256)
	local noise2 = minetest.get_perlin(56789, 6, 0.5, 256)
	local noise3 = minetest.get_perlin(42, 3, 0.5, 32)
	local noise4 = minetest.get_perlin(8954, 8, 0.5, 1024)
	
	local noise_top_layer = minetest.get_perlin(654, 6, 0.5, 256)
	local noise_second_layer = minetest.get_perlin(123, 6, 0.5, 256)
	
	local noise_temperature = minetest.get_perlin(763, 6, 0.5, 256)
	local noise_humidity = minetest.get_perlin(834, 6, 0.5, 256)
	local noise_beach = minetest.get_perlin(452, 6, 0.5, 256)
	
	local data = vm:get_data()

	local c_air  = minetest.get_content_id("air")
	local c_grass  = minetest.get_content_id("default:dirt_with_grass")
	local c_dirt_snow  = minetest.get_content_id("default:dirt_with_snow")
	local c_snow  = minetest.get_content_id("default:snow")
	local c_sapling  = minetest.get_content_id("default:sapling")
	local c_tree  = minetest.get_content_id("default:tree")
	local c_leaves  = minetest.get_content_id("default:leaves")
	local c_junglesapling  = minetest.get_content_id("default:junglesapling")
	local c_jungletree  = minetest.get_content_id("default:jungletree")
	local c_jungleleaves  = minetest.get_content_id("default:jungleleaves")
	local c_dirt  = minetest.get_content_id("default:dirt")
	local c_stone  = minetest.get_content_id("default:stone")
	local c_water  = minetest.get_content_id("default:water_source")
	local c_ice  = minetest.get_content_id("default:ice")
	local c_sand  = minetest.get_content_id("default:sand")
	local c_sandstone  = minetest.get_content_id("default:sandstone")
	local c_desert_sand  = minetest.get_content_id("default:desert_sand")
	local c_desert_stone  = minetest.get_content_id("default:desert_stone")
	local c_snow  = minetest.get_content_id("default:snow")
	local c_snowblock  = minetest.get_content_id("default:snowblock")
	local c_cactus  = minetest.get_content_id("default:cactus")
	local c_grass_1  = minetest.get_content_id("default:grass_1")
	local c_grass_2  = minetest.get_content_id("default:grass_2")
	local c_grass_3  = minetest.get_content_id("default:grass_3")
	local c_grass_4  = minetest.get_content_id("default:grass_4")
	local c_grass_5  = minetest.get_content_id("default:grass_5")
	local c_grasses = {c_grass_1, c_grass_2, c_grass_3, c_grass_4, c_grass_5}
	local c_jungle_grass  = minetest.get_content_id("default:junglegrass")
	local c_dry_shrub  = minetest.get_content_id("default:dry_shrub")

	local ni = 1
	local above_top
	local liquid_top
	local top
	local top_layer
	local second_layer
	local humidity
	local temperature
	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		local y=math.floor(smooth_surface(x, z, village_noise, vx, vz, vs, vh, noise1, noise2, noise3, noise4))
		humidity = noise_humidity:get2d({x=x,y=z})
		temperature = noise_temperature:get2d({x=x,y=z}) - math.max(y, 0)/50
		if temperature<-0.4 then
			liquid_top = c_ice
		else
			liquid_top = c_water
		end
		if y < -1 then
			above_top = c_air
			top = c_dirt
			top_layer = c_dirt
			second_layer = c_stone
		elseif y < 3 and noise_beach:get2d({x=x, y=z})<0.2 then
			above_top = c_air
			top = c_sand
			top_layer = c_sand
			second_layer = c_sandstone
		else
			above_top = c_air
			if temperature>0.4 then
				if humidity<-0.4 then
					top = c_desert_sand
					top_layer = c_desert_sand
					second_layer = c_desert_stone
					if pr:next(1, 50) == 1 then
						above_top = c_cactus
					elseif pr:next(1, 50) == 1 then
						above_top = c_dry_shrub
					end
				elseif humidity<0.4 then
					top = c_grass
					top_layer = c_dirt
					second_layer = c_stone
					if pr:next(1, 50) == 1 then
						if pr:next(1, 80) > 100*(humidity+0.4) then
							above_top = c_dry_shrub
						else
							above_top = c_grass_2
						end
					end
				else
					if pr:next(1, 14) == 1 and y>0 then
						above_top = c_sapling
					elseif pr:next(1, 16) == 1 and y>0 then
						above_top = c_junglesapling
					elseif pr:next(1, 30) == 1 then
						above_top = c_jungle_grass
					end
					top = c_grass
					top_layer = c_dirt
					second_layer = c_stone
				end
			elseif temperature<-0.4 then
				above_top = c_snow
				top = c_dirt_snow
				top_layer = c_dirt
				second_layer = c_stone
			else
				if humidity<-0.4 then
					if pr:next(1, 60) == 1 then
						above_top = c_grasses[pr:next(1,4)]
					end
				elseif humidity>0.4 then
					if pr:next(1, 20) == 1 then
						above_top = c_grasses[pr:next(3,5)]
					end
				else
					if pr:next(1, 20) == 1 and y>0 then
						above_top = c_sapling
					end
				end
				top = c_grass
				top_layer = c_dirt
				second_layer = c_stone
			end
		end
		if y>=100 then
			above_top = c_air
			top = c_snow
			top_layer = c_snowblock
		end

		if y<=maxp.y and y>=minp.y then
        		local vi = a:index(x, y, z)
        		if y >= 0 then
        			data[vi] = top
        		else
        			data[vi] = top_layer
        		end
		end
		local in_village =  (x-vx)*(x-vx)+(z-vz)*(z-vz) < vs*vs
		if above_top == c_sapling then
			if not in_village then
				add_tree(data, a, x, y+1, z, treemin, treemax, c_tree, c_leaves, pr)
			end
		elseif above_top == c_junglesapling then
			if not in_village then
				add_jungletree(data, a, x, y+1, z, treemin, treemax, c_jungletree, c_jungleleaves, pr)
			end
		elseif above_top == c_cactus then
			if not in_village then
				ch = pr:next(1, 4)
				for yy = math.max(y+1, minp.y), math.min(y+ch, maxp.y) do
					data[a:index(x, yy, z)] = c_cactus
				end
			end
		else
			if y+1<=maxp.y and y+1>=minp.y then
        			local vi = a:index(x, y+1, z)
        			data[vi] = above_top
			end
		end
		if y<0 and minp.y<=0 and maxp.y>y then
			for yy = math.max(y+1, minp.y), math.min(0, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = c_water
			end
			if maxp.y>=0 then
				data[a:index(x, 0, z)] = liquid_top
			end
		end
		local tl = math.floor((noise_top_layer:get2d({x=x,y=z})+2.5)*2)
		if y-tl-1<=maxp.y and y-1>=minp.y then
			for yy = math.max(y-tl-1, minp.y), math.min(y-1, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = top_layer
			end
		end
		local sl = math.floor((noise_second_layer:get2d({x=x,y=z})+5)*3)
		if y-sl-1<=maxp.y and y-tl-2>=minp.y then
			for yy = math.max(y-sl-1, minp.y), math.min(y-tl-2, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = second_layer
			end
		end
		if y-sl-2>=minp.y then
			for yy = minp.y, math.min(y-sl-2, maxp.y) do
				local vi = a:index(x, yy, z)
				data[vi] = c_stone
			end
		end
	end
	end
        
        to_add = generate_village(vx, vz, vs, vh, minp, maxp, data, a)
        
	vm:set_data(data)
       
	vm:calc_lighting(
		{x=minp.x-16, y=minp.y, z=minp.z-16},
		{x=maxp.x+16, y=maxp.y, z=maxp.z+16}
	)
	
	vm:write_to_map(data)
	
	local meta
	for pos, n in pairs(to_add) do
		minetest.set_node(pos, n.node)
		meta = minetest.get_meta(pos)
		meta:from_table(to_add.meta)
	end
end)