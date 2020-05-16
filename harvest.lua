#!/usr/bin/env luajit

-- Copyright (C) 2014-2020 Dyne.org Foundation

-- Harvest is designed, written and maintained by Denis "Jaromil" Roio

-- This source code is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This source code is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Please refer
-- to the GNU Public License for more details.
--
-- You should have received a copy of the GNU Public License along with
-- this source code; if not, write to: Free Software Foundation, Inc.,
-- 675 Mass Ave, Cambridge, MA 02139, USA.

local lfs = require'lfs'

-- for cli args
-- package.path = package.path ..";"..lfs.currentdir().."/lua_cliargs/src/?.lua"
-- local cli = require'lua_cliargs/src/cliargs'

-- debug
DEBUG=0
local inspect = require'inspect'
function I(o) print( inspect.inspect(o) ) end
function D(s) if DEBUG > 0 then print(s) end end

-- # fuzzy thresholds
-- #
-- # this is the most important section to tune the selection: the higher
-- # the values the more file of that type need to be present in a
-- # directory to classify it with their own type. In other words a lower
-- # number makes the type "dominant".
local fuzzy = {
   video=1,  --  minimum video files to increase the video factor
   audio=3,  --  minimum audio files to increase the audio factor
   text=10,   --  minimum text  files to increase the text factor
   image=10, --  minimum image files to increase the image factor
   other=25, --  minimum other files to increase the other factor
   code=5,   --  minimum code  files to increase the code factor
   web=10,
   slide=2,
   sheet=3,
   archiv=10
}
local totals = { }
local scores = { }
for k, v in pairs(fuzzy) do
   totals[k] = 0
   scores[k] = { }
end

-- https://github.com/dyne/file-extension-list
local file_extension_list = { ["3dm"] = "image", ["3ds"] = "image", ["3g2"] = "video", ["3gp"] = "video", ["7z"] = "archiv", a = "archiv", aac = "audio", aaf = "video", ai = "image", aiff = "audio", ape = "audio", apk = "archiv", ar = "archiv", asf = "video", au = "audio", avchd = "video", avi = "video", azw = "book", azw1 = "book", azw3 = "book", azw4 = "book", azw6 = "book", bat = "exec", bin = "exec", bmp = "image", bz2 = "archiv", c = "code", cab = "archiv", cbr = "book", cbz = "book", cc = "code", class = "code", clj = "code", command = "exec", cpio = "archiv", cpp = "code", crx = "exec", cs = "code", css = "web", csv = "sheet", cxx = "code", dds = "image", deb = "archiv", diff = "code", dmg = "archiv", doc = "text", docx = "text", drc = "video", dwg = "image", dxf = "image", ebook = "text", egg = "archiv", el = "code", eot = "font", eps = "image", epub = "book", exe = "exec", flac = "audio", flv = "video", gif = "image", go = "code", gpx = "image", gsm = "audio", gz = "archiv", h = "code", html = "code", ics = "sheet", iso = "archiv", it = "audio", jar = "archiv", java = "code", jpeg = "image", jpg = "image", js = "code", kml = "image", kmz = "image", less = "web", lha = "archiv", log = "text", lua = "code", m = "code", m2v = "video", m3u = "audio", m4 = "code", m4a = "audio", m4p = "video", m4v = "video", mar = "archiv", max = "image", md = "text", mid = "audio", mkv = "video", mng = "video", mobi = "book", mod = "audio", mov = "video", mp2 = "video", mp3 = "audio", mp4 = "video", mpa = "audio", mpe = "video", mpeg = "video", mpg = "video", mpv = "video", msg = "text", msi = "exec", mxf = "video", nsv = "video", odp = "slide", ods = "sheet", odt = "text", ogg = "video", ogm = "video", ogv = "video", org = "text", otf = "font", pages = "text", pak = "archiv", patch = "code", pdf = "text", pea = "archiv", php = "code", pl = "code", pls = "audio", png = "image", po = "code", ppt = "slide", ps = "image", psd = "image", py = "code", qt = "video", ra = "audio", rar = "archiv", rb = "code", rm = "video", rmvb = "video", roq = "video", rpm = "archiv", rs = "code", rst = "text", rtf = "text", s3m = "audio", s7z = "archiv", scss = "web", sh = "exec", shar = "archiv", sid = "audio", srt = "video", svg = "image", svi = "video", swift = "code", tar = "archiv", tbz2 = "archiv", tex = "text", tga = "image", tgz = "archiv", thm = "image", tif = "image", tiff = "image", tlz = "archiv", ttf = "font", txt = "text", vb = "code", vcf = "sheet", vcxproj = "code", vob = "video", war = "archiv", wasm = "web", wav = "audio", webm = "video", webp = "image", whl = "archiv", wma = "audio", wmv = "video", woff = "font", woff2 = "font", wpd = "text", wps = "text", xcf = "image", xcodeproj = "code", xls = "sheet", xlsx = "sheet", xm = "audio", xml = "code", xpi = "archiv", xz = "archiv", yuv = "video", zip = "archiv", zipx = "archiv" }

local PWD = arg[1] or lfs.currentdir()

function getextension(p)
   local i = p:findlast(".", true)
   if (i) then
	  return p:sub(i)
   else
	  return ""
   end
end

function extparser(arg)
   local curr = 0
   repeat
	  local n = arg:find('.',curr+1, true)
	  if n then curr = n end
   until (not n)
   if (curr == 0) then return nil end
   return(arg:sub( curr + 1 ))
end

-- recurse into directories
local function analyse_path(basedir, pathname, level)
   local target = pathname or basedir
   local curlev = level or 1
   -- D("analyse: "..target)
   local path
   for path in lfs.dir(target) do
	  if not (path == '.' or path == '..') then
		 local tarpath = target..'/'..path
		 if lfs.attributes(tarpath,"mode") == "directory" then
			D("found dir:\t"..tarpath.." ("..curlev..")")
			analyse_path(basedir, tarpath, curlev+1)
		 else
			local ftype = file_extension_list[ extparser(tarpath) ]
			if ftype then
			   if not scores[ftype] then scores[ftype] = { } end
			   table.insert(scores[ftype], tarpath)
			   -- D("found "..ftype..":\t"..tarpath)
			else
			   table.insert(scores['other'], tarpath)
			end
		 end
	  end
   end
end

analyse_path(PWD)

-- compute a very, very simple linear fuzzy logic for each
for k,v in pairs(scores) do
   totals[k] = #v / (fuzzy[k] or fuzzy['other'])
end

local max = 0
local guess = 'unknown'
for k,v in pairs(totals) do
   if v > max then
	  max = v
	  guess = k
   end
end
print''
print("Path "..PWD.." is "..string.upper(guess))
print("Fuzzy logic scores:")
I(totals)
