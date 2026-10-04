-- Called only by the fixed Inspector button on the clicked Pen Mask group.
local root = assert(tool, '未找到当前蒙版实例')
local choice = tonumber(root:GetInput('PresetChoice', comp.CurrentTime))
if not choice or choice < 1 or choice > 8 or choice ~= math.floor(choice) then return end

local children = assert(root:GetChildrenList(), '无法读取当前蒙版节点')
local pen
for _, child in pairs(children) do
  if child:GetAttrs().TOOLS_RegID == 'PolylineMask' then
    assert(not pen, '蒙版实例包含多个钢笔节点')
    pen = child
  end
end
assert(pen and pen.Polyline:GetConnectedOutput(), '钢笔路径未连接')
local curve = assert(pen.Polyline:GetConnectedOutput():GetTool(), '钢笔动画不存在')
assert(curve:GetAttrs().TOOLS_RegID == 'BezierSpline', '钢笔动画类型已改变')

local width = tonumber(comp:GetPrefs('Comp.FrameFormat.Width'))
local height = tonumber(comp:GetPrefs('Comp.FrameFormat.Height'))
assert(width and height and width > 0 and height > 0, '当前画幅无效')
local aspect = width / height
local radiusY = math.min(.24, .44 * aspect)
local radiusX = radiusY / aspect
local pi = math.pi
local k = 4 * (math.sqrt(2) - 1) / 3
local function point(x, y, lx, ly, rx, ry)
  return {X=x, Y=y, LX=lx, LY=ly, RX=rx, RY=ry}
end
local function regular(count)
  local points = {}
  for i=0,count-1 do
    local angle = pi/2 - i*2*pi/count
    points[#points+1] = point(radiusX*math.cos(angle), radiusY*math.sin(angle))
  end
  return points
end
local shapes = {
  function() return {
    point(0,radiusY,-k*radiusX,0,k*radiusX,0),
    point(radiusX,0,0,k*radiusY,0,-k*radiusY),
    point(0,-radiusY,k*radiusX,0,-k*radiusX,0),
    point(-radiusX,0,0,-k*radiusY,0,k*radiusY),
  } end,
  function() return {point(-.28,.22),point(.28,.22),point(.28,-.22),point(-.28,-.22)} end,
  function()
    local hx,hy,ry=.28,.22,.065
    local rx=ry/aspect
    return {
      point(-hx+rx,hy,-k*rx,0,0,0), point(hx-rx,hy,0,0,k*rx,0),
      point(hx,hy-ry,0,k*ry,0,0), point(hx,-hy+ry,0,0,0,-k*ry),
      point(hx-rx,-hy,k*rx,0,0,0), point(-hx+rx,-hy,0,0,-k*rx,0),
      point(-hx,-hy+ry,0,-k*ry,0,0), point(-hx,hy-ry,0,0,0,k*ry),
    }
  end,
  function() return regular(3) end,
  function() return {point(0,radiusY),point(radiusX,0),point(0,-radiusY),point(-radiusX,0)} end,
  function()
    local points={}
    for i=0,9 do
      local angle=pi/2-i*pi/5
      local scale=i%2==0 and 1 or .44
      points[#points+1]=point(scale*radiusX*math.cos(angle),scale*radiusY*math.sin(angle))
    end
    return points
  end,
  function() return regular(5) end,
  function() return regular(6) end,
}
local labels={'圆形','矩形','圆角矩形','三角形','菱形','五角星','五边形','六边形'}
local points=shapes[choice]()

-- Only numeric geometry produced above is parsed; no user text becomes Lua code.
local function num(value)
  assert(type(value)=='number' and value==value and math.abs(value)<2, '预设坐标无效')
  return string.format('%.9f', value):gsub(',', '.')
end
local vertices={}
for _, p in ipairs(points) do
  local fields={'X='..num(p.X),'Y='..num(p.Y)}
  if p.LX then
    for _, key in ipairs({'LX','LY','RX','RY'}) do fields[#fields+1]=key..'='..num(p[key]) end
  else fields[#fields+1]='Linear=true' end
  vertices[#vertices+1]='{'..table.concat(fields,',')..'}'
end
local data='{Tools={PresetShape=BezierSpline{KeyFrames={[0]={0,Value=Polyline{Closed=true,Points={'..table.concat(vertices,',')..'}}}}}}}'
local parsed=assert(bmd.readstring(data), '无法生成原生钢笔路径')
local shape=assert(parsed.Tools.PresetShape.KeyFrames[0].Value, '预设路径无效')
assert(shape.Points and #shape.Points==#points, '预设顶点构造失败')

local name=curve:GetAttrs().TOOLS_Name
local before=assert(curve:SaveSettings(), '无法保存原始动画')
local draft=assert(curve:SaveSettings(), '无法复制原始动画')
local saved=assert(draft.Tools and draft.Tools[name], '动画节点设置无效')
local keys=assert(saved.KeyFrames, '动画关键帧不存在')
local frame=math.floor(tonumber(comp.CurrentTime) or 0)
local count, blankFrame = 0, nil
for key, value in pairs(keys) do
  count=count+1
  if not value.Value or not value.Value.Points or not next(value.Value.Points) then blankFrame=key end
end
if count==1 and blankFrame then frame=blankFrame end
local oldPreview=root:GetInput('PreviewOriginal', comp.CurrentTime)

comp:StartUndo('钢笔蒙版：'..labels[choice]..'预设')
local ok,err=pcall(function()
  local key=keys[frame] or {frame, Flags={Linear=true,LockedY=true}}
  key.Value=shape
  keys[frame]=key
  assert(curve:LoadSettings(draft), '原生钢笔动画拒绝写入')
  root:SetInput('PreviewOriginal', 0)
end)
if not ok then
  pcall(function() curve:LoadSettings(before); root:SetInput('PreviewOriginal', oldPreview) end)
  print('钢笔蒙版预设失败：'..tostring(err))
end
comp:EndUndo(ok)
