repeat task.wait() until game:IsLoaded()
local Players,RunService,UIS,TS,Lighting,HS = game:GetService("Players"),game:GetService("RunService"),game:GetService("UserInputService"),game:GetService("TweenService"),game:GetService("Lighting"),game:GetService("HttpService")
local LP = Players.LocalPlayer

local NS,CS,LS,DAS,DAD = 60,30,120,150,0.2

local speedMode,antiRagdollEnabled,infJumpEnabled = false,false,false
local medusaCounterEnabled,brainrotLeftEnabled,brainrotRightEnabled = false,false,false
local tpMode = "Manuel"
local medusaMode = false
local unwalkEnabled = false
local unwalkAnimations = {}
local floatEnabled = false
local floatHeight = 9.5
local floatJumping = false
local lastHealth,medusaDebounce,medusaLastUsed,dropActive = 100,false,0,false
local stretchRezEnabled = false
local autoLeftEnabled,autoRightEnabled = false,false
local autoLeftSetVisual,autoRightSetVisual = nil,nil
local speedLabel = nil
local medusaConns = {}
local autoBatEnabled = false
local autoBatSetVisual = nil
local _anyKeyListening = false

local KB = {
	DropBrainrot={kb=Enum.KeyCode.X,gp=nil},
	AutoLeft    ={kb=Enum.KeyCode.Z,gp=nil},
	AutoRight   ={kb=Enum.KeyCode.C,gp=nil},
	AutoBat     ={kb=Enum.KeyCode.E,gp=nil},
	TPLeft      ={kb=Enum.KeyCode.V,gp=nil},
	TPRight     ={kb=Enum.KeyCode.B,gp=nil},
	TPFloor     ={kb=Enum.KeyCode.F,gp=nil},
	GuiHide     ={kb=Enum.KeyCode.LeftControl,gp=nil},
	Float       ={kb=Enum.KeyCode.J,gp=nil},
	SpeedToggle ={kb=Enum.KeyCode.Q,gp=nil},
}

local AP_L1,AP_L2 = Vector3.new(-476.48,-6.28,92.73),Vector3.new(-483.12,-4.95,94.80)
local AP_L_FACE = Vector3.new(-482.25,-4.96,92.09)
local AP_R1,AP_R2 = Vector3.new(-476.16,-6.52,25.62),Vector3.new(-483.06,-5.03,25.48)
local AP_R_FACE = Vector3.new(-482.06,-6.93,35.47)
local BR_L1,BR_L2,BR_L3 = Vector3.new(-469,-6,78),Vector3.new(-471,-6,96),Vector3.new(-484,-4,99)
local BR_R1,BR_R2,BR_R3 = Vector3.new(-468,-6,41),Vector3.new(-473,-6,24),Vector3.new(-484,-4,20)
local SEMI_L1,SEMI_L2,SEMI_L3 = Vector3.new(-474.9,-7.0,94.9),Vector3.new(-481.7,-5.1,97.7),Vector3.new(-465.7,-7.0,83.2)
local SEMI_R1,SEMI_R2,SEMI_R3 = Vector3.new(-474.9,-7.0,24.1),Vector3.new(-482.64,-5.20,21.06),Vector3.new(-466.78,-7.10,40.83)

local Steal = {
	AutoStealEnabled=false,StealRadius=20,StealDuration=0.25,
	Data={},plotCache={},plotCacheTime={},cachedPrompts={},promptCacheTime=0,
}
local isStealing=false
local stealStartTime=nil
local lastStealTick=0
local Conns = {autoSteal=nil,antiRag=nil,float=nil,anchor={},progress=nil}
local PLOT_CACHE_DURATION = 2
local PROMPT_CACHE_REFRESH = 0.15
local STEAL_COOLDOWN = 0.1
local MEDUSA_COOLDOWN = 25

local progressRadLbl,progressFill,progressPct
local setFloat,modeValLbl

local function resetProgressBar()
	progressPct.Text="0%";progressFill.Size=UDim2.new(0,0,1,0)
end

local function isMyPlotByName(plotName)
	local ct = tick()
	if Steal.plotCache[plotName] and (ct-(Steal.plotCacheTime[plotName] or 0))<PLOT_CACHE_DURATION then return Steal.plotCache[plotName] end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then Steal.plotCache[plotName]=false;Steal.plotCacheTime[plotName]=ct;return false end
	local plot = plots:FindFirstChild(plotName)
	if not plot then Steal.plotCache[plotName]=false;Steal.plotCacheTime[plotName]=ct;return false end
	local sign = plot:FindFirstChild("PlotSign")
	if sign then
		local yb = sign:FindFirstChild("YourBase")
		if yb and yb:IsA("BillboardGui") then
			local r = yb.Enabled==true;Steal.plotCache[plotName]=r;Steal.plotCacheTime[plotName]=ct;return r
		end
	end
	Steal.plotCache[plotName]=false;Steal.plotCacheTime[plotName]=ct;return false
end

local function findNearestPrompt()
	local char = LP.Character;if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart");if not root then return nil end
	local ct = tick()
	if ct-Steal.promptCacheTime<PROMPT_CACHE_REFRESH and #Steal.cachedPrompts>0 then
		local np,nd = nil,math.huge
		for _,data in ipairs(Steal.cachedPrompts) do
			if data.spawn then
				local dist = (data.spawn.Position-root.Position).Magnitude
				if dist<=Steal.StealRadius and dist<nd then np=data.prompt;nd=dist end
			end
		end
		if np then return np end
	end
	Steal.cachedPrompts={};Steal.promptCacheTime=ct
	local plots = workspace:FindFirstChild("Plots");if not plots then return nil end
	local np,nd = nil,math.huge
	for _,plot in ipairs(plots:GetChildren()) do
		if isMyPlotByName(plot.Name) then continue end
		local pods = plot:FindFirstChild("AnimalPodiums");if not pods then continue end
		for _,pod in ipairs(pods:GetChildren()) do
			pcall(function()
				local base = pod:FindFirstChild("Base");local sp = base and base:FindFirstChild("Spawn")
				if sp then
					local att = sp:FindFirstChild("PromptAttachment")
					if att then
						for _,child in ipairs(att:GetChildren()) do
							if child:IsA("ProximityPrompt") then
								local dist = (sp.Position-root.Position).Magnitude
								table.insert(Steal.cachedPrompts,{prompt=child,spawn=sp,name=pod.Name})
								if dist<=Steal.StealRadius and dist<nd then np=child;nd=dist end
								break
							end
						end
					end
				end
			end)
		end
	end
	return np
end

-- ===== VYSE-STYLE INSTA STEAL =====
local function executeSteal(prompt)
	local ct = tick()
	if ct-lastStealTick<STEAL_COOLDOWN then return end
	if isStealing then return end
	if not Steal.Data[prompt] then
		Steal.Data[prompt]={hold={},trigger={},ready=true}
		pcall(function()
			if getconnections then
				for _,c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do if c.Function then table.insert(Steal.Data[prompt].hold,c.Function) end end
				for _,c in ipairs(getconnections(prompt.Triggered)) do if c.Function then table.insert(Steal.Data[prompt].trigger,c.Function) end end
			else Steal.Data[prompt].useFallback=true end
		end)
	end
	local data = Steal.Data[prompt];if not data.ready then return end
	data.ready=false;isStealing=true;stealStartTime=ct;lastStealTick=ct
	if Conns.progress then Conns.progress:Disconnect() end
	Conns.progress = RunService.Heartbeat:Connect(function()
		if not isStealing then Conns.progress:Disconnect();return end
		local prog = math.clamp((tick()-stealStartTime)/Steal.StealDuration,0,1)
		progressFill.Size=UDim2.new(prog,0,1,0);progressPct.Text=math.floor(prog*100).."%"
	end)
	task.spawn(function()
		local ok = false
		pcall(function()
			if not data.useFallback then
				for _,fn in ipairs(data.hold) do task.spawn(fn) end
				task.wait(Steal.StealDuration)
				for _,fn in ipairs(data.trigger) do task.spawn(fn) end
				ok=true
			end
		end)
		if not ok and fireproximityprompt then pcall(function() fireproximityprompt(prompt);ok=true end) end
		if not ok then pcall(function() prompt:InputHoldBegin();task.wait(Steal.StealDuration);prompt:InputHoldEnd() end) end
		task.wait(Steal.StealDuration*0.3)
		if Conns.progress then Conns.progress:Disconnect() end
		resetProgressBar();task.wait(0.05);data.ready=true;isStealing=false
	end)
end

local function startAutoSteal()
	if Conns.autoSteal then return end
	Conns.autoSteal = RunService.Heartbeat:Connect(function()
		if not Steal.AutoStealEnabled or isStealing then return end
		local p = findNearestPrompt();if p then executeSteal(p) end
	end)
end

local function stopAutoSteal()
	if Conns.autoSteal then Conns.autoSteal:Disconnect();Conns.autoSteal=nil end
	isStealing=false;lastStealTick=0
	Steal.plotCache={};Steal.plotCacheTime={};Steal.cachedPrompts={};resetProgressBar()
end
-- ===== END INSTA STEAL =====

RunService.Stepped:Connect(function()
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LP and p.Character then
			for _,part in ipairs(p.Character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide=false end
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local char=LP.Character; if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid")
	local hrp=char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end
	local md=hum.MoveDirection
	local spd=speedMode and CS or (stretchRezEnabled and LS or NS)
	if md.Magnitude>0 and not autoLeftEnabled and not autoRightEnabled then
		hrp.AssemblyLinearVelocity=Vector3.new(md.X*spd,hrp.AssemblyLinearVelocity.Y,md.Z*spd)
	end
	if speedLabel then speedLabel.Text=string.format("Speed: %.1f",Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z).Magnitude) end
end)

local alConn,arConn = nil,nil
local alPhase,arPhase = 1,1

local function stopAutoLeft()
	if alConn then alConn:Disconnect();alConn=nil end;alPhase=1
	local char = LP.Character;if char then local h=char:FindFirstChildOfClass("Humanoid");if h then h:Move(Vector3.zero,false) end end
end

local function stopAutoRight()
	if arConn then arConn:Disconnect();arConn=nil end;arPhase=1
	local char = LP.Character;if char then local h=char:FindFirstChildOfClass("Humanoid");if h then h:Move(Vector3.zero,false) end end
end

local function startAutoLeft()
	if alConn then alConn:Disconnect() end;alPhase=1
	alConn=RunService.Heartbeat:Connect(function()
		if not autoLeftEnabled then return end
		local char=LP.Character;if not char then return end
		local hrp=char:FindFirstChild("HumanoidRootPart")
		local hum=char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local spd=NS
		if alPhase==1 then
			local tgt=Vector3.new(AP_L1.X,hrp.Position.Y,AP_L1.Z)
			if (tgt-hrp.Position).Magnitude<1 then
				alPhase=2
				local d=AP_L2-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
				hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd);return
			end
			local d=AP_L1-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
			hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
		elseif alPhase==2 then
			local tgt=Vector3.new(AP_L2.X,hrp.Position.Y,AP_L2.Z)
			if (tgt-hrp.Position).Magnitude<1 then
				hum:Move(Vector3.zero,false);hrp.AssemblyLinearVelocity=Vector3.zero
				autoLeftEnabled=false;if alConn then alConn:Disconnect();alConn=nil end
				alPhase=1;if autoLeftSetVisual then autoLeftSetVisual(false) end
				if (AP_L_FACE-hrp.Position).Magnitude>0.01 then hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(AP_L_FACE.X,hrp.Position.Y,AP_L_FACE.Z)) end
				return
			end
			local d=AP_L2-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
			hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
		end
	end)
end

local function startAutoRight()
	if arConn then arConn:Disconnect() end;arPhase=1
	arConn=RunService.Heartbeat:Connect(function()
		if not autoRightEnabled then return end
		local char=LP.Character;if not char then return end
		local hrp=char:FindFirstChild("HumanoidRootPart")
		local hum=char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local spd=NS
		if arPhase==1 then
			local tgt=Vector3.new(AP_R1.X,hrp.Position.Y,AP_R1.Z)
			if (tgt-hrp.Position).Magnitude<1 then
				arPhase=2
				local d=AP_R2-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
				hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd);return
			end
			local d=AP_R1-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
			hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
		elseif arPhase==2 then
			local tgt=Vector3.new(AP_R2.X,hrp.Position.Y,AP_R2.Z)
			if (tgt-hrp.Position).Magnitude<1 then
				hum:Move(Vector3.zero,false);hrp.AssemblyLinearVelocity=Vector3.zero
				autoRightEnabled=false;if arConn then arConn:Disconnect();arConn=nil end
				arPhase=1;if autoRightSetVisual then autoRightSetVisual(false) end
				if (AP_R_FACE-hrp.Position).Magnitude>0.01 then hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(AP_R_FACE.X,hrp.Position.Y,AP_R_FACE.Z)) end
				return
			end
			local d=AP_R2-hrp.Position;local mv=Vector3.new(d.X,0,d.Z).Unit
			hum:Move(mv,false);hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
		end
	end)
end

local function setupSpeedIndicator(char)
	local head = char:WaitForChild("Head",5);if not head then return end
	local bb = Instance.new("BillboardGui",head)
	bb.Size=UDim2.new(0,140,0,25);bb.StudsOffset=Vector3.new(0,3,0);bb.AlwaysOnTop=true
	speedLabel = Instance.new("TextLabel",bb)
	speedLabel.Size=UDim2.new(1,0,1,0);speedLabel.BackgroundTransparency=1
	speedLabel.Text="Speed: 0";speedLabel.TextColor3=Color3.fromRGB(180,20,40)
	speedLabel.Font=Enum.Font.GothamBold;speedLabel.TextScaled=true
	speedLabel.TextStrokeTransparency=0;speedLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
end

local function startAntiRagdoll()
	if Conns.antiRag then return end
	Conns.antiRag = RunService.Heartbeat:Connect(function()
		local char = LP.Character;if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid");local root=char:FindFirstChild("HumanoidRootPart")
		if hum then
			local st = hum:GetState()
			if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				workspace.CurrentCamera.CameraSubject=hum
				pcall(function() local pm=LP.PlayerScripts:FindFirstChild("PlayerModule");if pm then require(pm:FindFirstChild("ControlModule")):Enable() end end)
				if root then root.Velocity=Vector3.zero;root.RotVelocity=Vector3.zero end
			end
		end
		for _,obj in ipairs(char:GetDescendants()) do if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled=true end end
	end)
end

local function stopAntiRagdoll()
	if Conns.antiRag then Conns.antiRag:Disconnect();Conns.antiRag=nil end
end

local IJ_JumpConn,IJ_FallConn = nil,nil

local function startInfiniteJump()
	if IJ_JumpConn then IJ_JumpConn:Disconnect() end
	if IJ_FallConn then IJ_FallConn:Disconnect() end
	IJ_JumpConn = UIS.JumpRequest:Connect(function()
		if not infJumpEnabled then return end
		local char = LP.Character;if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.Velocity=Vector3.new(root.Velocity.X,55,root.Velocity.Z) end
	end)
	IJ_FallConn = RunService.Heartbeat:Connect(function()
		if not infJumpEnabled then return end
		local char = LP.Character;if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root and root.Velocity.Y<-120 then root.Velocity=Vector3.new(root.Velocity.X,-120,root.Velocity.Z) end
	end)
end

local function stopInfiniteJump()
	if IJ_JumpConn then IJ_JumpConn:Disconnect();IJ_JumpConn=nil end
	if IJ_FallConn then IJ_FallConn:Disconnect();IJ_FallConn=nil end
end

local function disableAnimations()
	local char = LP.Character;if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid");if not hum then return end
	for _,track in pairs(unwalkAnimations) do pcall(function() track:Stop() end) end
	unwalkAnimations={}
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _,track in pairs(animator:GetPlayingAnimationTracks()) do
			track:Stop();table.insert(unwalkAnimations,track)
		end
	end
end

local function enableAnimations() unwalkAnimations={} end

RunService.Heartbeat:Connect(function()
	if not unwalkEnabled then return end
	disableAnimations()
end)

local brainrotReturnCooldown = false
local RAGDOLL_STATES = {[Enum.HumanoidStateType.Ragdoll]=true,[Enum.HumanoidStateType.FallingDown]=true,[Enum.HumanoidStateType.Physics]=true}

local function isRagdolledCheck()
	local c = LP.Character;if not c then return false end
	local hum = c:FindFirstChildOfClass("Humanoid");if not hum then return false end
	if RAGDOLL_STATES[hum:GetState()] then return true end
	for _,obj in ipairs(c:GetDescendants()) do
		if obj:IsA("Motor6D") and obj.Enabled==false then return true end
	end
	return false
end

local function doReturnTeleport(side)
	if brainrotReturnCooldown then return end
	brainrotReturnCooldown=true
	task.spawn(function()
		local char = LP.Character;if not char then brainrotReturnCooldown=false;return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not(hrp and hum) then brainrotReturnCooldown=false;return end
		local s1,s2,s3
		if tpMode=="Semi" then
			s1=side=="left" and SEMI_L1 or SEMI_R1
			s2=side=="left" and SEMI_L2 or SEMI_R2
			s3=side=="left" and SEMI_L3 or SEMI_R3
		else
			s1=side=="left" and BR_L1 or BR_R1
			s2=side=="left" and BR_L2 or BR_R2
			s3=side=="left" and BR_L3 or BR_R3
		end
		if tpMode=="Semi" then
			pcall(function()
				for _,obj in ipairs(char:GetDescendants()) do if obj:IsA("Motor6D") then obj.Enabled=true end end
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				task.wait(0.20)
				hrp.AssemblyLinearVelocity=Vector3.zero;hrp.AssemblyAngularVelocity=Vector3.zero
				hrp.CFrame=CFrame.new(s1+Vector3.new(0,3,0))
				task.wait(0.20)
				hrp.AssemblyLinearVelocity=Vector3.zero
				hrp.CFrame=CFrame.new(s2+Vector3.new(0,3,0))
				task.wait(0.20)
				hrp.AssemblyLinearVelocity=Vector3.zero
				hrp.CFrame=CFrame.new(s3+Vector3.new(0,3,0))
				hum:ChangeState(Enum.HumanoidStateType.Running)
				hum:Move(Vector3.zero,false)
				for _,obj in ipairs(char:GetDescendants()) do if obj:IsA("Motor6D") then obj.Enabled=true end end
			end)
			task.wait(0.6)
		else
			hrp.AssemblyLinearVelocity=Vector3.zero
			hrp.CFrame=CFrame.new(s1+Vector3.new(0,3,0))
			hum:ChangeState(Enum.HumanoidStateType.Running)
			task.wait(0.1)
			hrp.AssemblyLinearVelocity=Vector3.zero
			hrp.CFrame=CFrame.new(s2+Vector3.new(0,3,0))
			hum:ChangeState(Enum.HumanoidStateType.Running)
			task.wait(0.1)
			hrp.AssemblyLinearVelocity=Vector3.zero
			hrp.CFrame=CFrame.new(s3+Vector3.new(0,3,0))
			hum:ChangeState(Enum.HumanoidStateType.Running)
			task.wait(0.6)
		end
		brainrotReturnCooldown=false
	end)
end

RunService.Heartbeat:Connect(function()
	if not(brainrotLeftEnabled or brainrotRightEnabled) or brainrotReturnCooldown then return end
	local char = LP.Character;if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid");if not hum then return end
	local hp = hum.Health
	local hit = hp<lastHealth-1
	local rag = RAGDOLL_STATES[hum:GetState()] or isRagdolledCheck()
	lastHealth=hp
	if not(hit or rag) then return end
	if brainrotLeftEnabled then doReturnTeleport("left")
	elseif brainrotRightEnabled then doReturnTeleport("right") end
end)

UIS.JumpRequest:Connect(function()
	if floatEnabled then floatJumping=true end
end)

local function startFloat()
	if Conns.float then Conns.float:Disconnect() end
	Conns.float = RunService.Heartbeat:Connect(function()
		if not floatEnabled then return end
		if dropActive then return end
		local char = LP.Character;if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart");if not root then return end
		local rp = RaycastParams.new();rp.FilterDescendantsInstances={char};rp.FilterType=Enum.RaycastFilterType.Exclude
		local rr = workspace:Raycast(root.Position,Vector3.new(0,-200,0),rp)
		if rr then
			local diff = (rr.Position.Y+floatHeight)-root.Position.Y
			if floatJumping then
				if root.AssemblyLinearVelocity.Y<=0 and diff>=-2 then
					floatJumping=false
				else
					return
				end
			end
			if math.abs(diff)>0.3 then
				root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,diff*15,root.AssemblyLinearVelocity.Z)
			else
				root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
			end
		end
	end)
end

local function stopFloat()
	if Conns.float then Conns.float:Disconnect();Conns.float=nil end
	floatJumping=false
	local char = LP.Character;if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end
	end
end

local function runDrop()
	if dropActive then return end
	local char = LP.Character;if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart");if not hrp then return end
	local floatWasEnabled = floatEnabled
	if floatWasEnabled then floatEnabled=false;if setFloat then setFloat(false) end end
	dropActive=true;local t0=tick();local conn
	conn = RunService.Heartbeat:Connect(function()
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if not r then conn:Disconnect();dropActive=false;return end
		if tick()-t0>=DAD then
			conn:Disconnect()
			local rp = RaycastParams.new();rp.FilterDescendantsInstances={char};rp.FilterType=Enum.RaycastFilterType.Exclude
			local rr = workspace:Raycast(r.Position,Vector3.new(0,-2000,0),rp)
			if rr then
				local hum2 = char:FindFirstChildOfClass("Humanoid")
				local off = (hum2 and hum2.HipHeight or 2)+(r.Size.Y/2)
				r.CFrame=CFrame.new(r.Position.X,rr.Position.Y+off,r.Position.Z);r.AssemblyLinearVelocity=Vector3.zero
			end
			dropActive=false
			if floatWasEnabled then floatEnabled=true;if setFloat then setFloat(true) end;startFloat() end
			return
		end
		r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,DAS,r.AssemblyLinearVelocity.Z)
	end)
end

local function runTPFloor()
	pcall(function()
		local char = LP.Character;if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart");if not hrp then return end
		local rp = RaycastParams.new();rp.FilterDescendantsInstances={char};rp.FilterType=Enum.RaycastFilterType.Exclude
		local rs = workspace:Raycast(hrp.Position,Vector3.new(0,-500,0),rp)
		if rs then
			hrp.CFrame=CFrame.new(hrp.Position.X,rs.Position.Y+hrp.Size.Y/2+0.1,hrp.Position.Z)
			hrp.AssemblyLinearVelocity=Vector3.zero
		end
	end)
end

local stretchRezConn = nil
local function enableStretchRez()
	stretchRezEnabled=true
	workspace.CurrentCamera.FieldOfView=120
	if stretchRezConn then stretchRezConn:Disconnect() end
	stretchRezConn=RunService.RenderStepped:Connect(function()
		if not stretchRezEnabled then stretchRezConn:Disconnect();stretchRezConn=nil;return end
		workspace.CurrentCamera.FieldOfView=120
	end)
end

local function disableStretchRez()
	stretchRezEnabled=false
	if stretchRezConn then stretchRezConn:Disconnect();stretchRezConn=nil end
	workspace.CurrentCamera.FieldOfView=70
end

local function findMedusa()
	local char = LP.Character;if not char then return nil end
	for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("medusa") then return t end end
	local bp = LP:FindFirstChild("Backpack")
	if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("medusa") then return t end end end
end

local function useMedusa()
	if medusaDebounce or tick()-medusaLastUsed<MEDUSA_COOLDOWN then return end
	local char = LP.Character;if not char then return end
	medusaDebounce=true
	local med = findMedusa()
	if med then
		if med.Parent~=char then local h=char:FindFirstChildOfClass("Humanoid");if h then h:EquipTool(med) end end
		pcall(function() med:Activate() end);medusaLastUsed=tick()
	end
	medusaDebounce=false
end

local function onAnchorChanged(part)
	return part:GetPropertyChangedSignal("Anchored"):Connect(function()
		if part.Anchored and part.Transparency==1 and medusaCounterEnabled then useMedusa() end
	end)
end

local function setupMedusa(char)
	for _,c in pairs(medusaConns) do pcall(function() c:Disconnect() end) end;medusaConns={}
	if not char then return end
	for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then table.insert(medusaConns,onAnchorChanged(part)) end end
	table.insert(medusaConns,char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then table.insert(medusaConns,onAnchorChanged(part)) end
	end))
end

local function getClosestPlayer()
	local char = LP.Character;if not char then return nil,math.huge end
	local hrp = char:FindFirstChild("HumanoidRootPart");if not hrp then return nil,math.huge end
	local cp,cd = nil,math.huge
	for _,p in pairs(Players:GetPlayers()) do
		if p~=LP and p.Character then
			local tr = p.Character:FindFirstChild("HumanoidRootPart")
			if tr then local d=(hrp.Position-tr.Position).Magnitude;if d<cd then cd=d;cp=p end end
		end
	end
	return cp,cd
end

RunService.Heartbeat:Connect(function()
	if not autoBatEnabled then return end
	local char=LP.Character;if not char then return end
	local hrp=char:FindFirstChild("HumanoidRootPart");if not hrp then return end
	if not char:FindFirstChildOfClass("Tool") then
		local hum=char:FindFirstChildOfClass("Humanoid")
		local bp=LP:FindFirstChild("Backpack")
		local bat=(bp and bp:FindFirstChild("Bat")) or char:FindFirstChild("Bat")
		if bat and hum then hum:EquipTool(bat) end
	end
	local target,_=getClosestPlayer()
	if target and target.Character then
		local tr=target.Character:FindFirstChild("HumanoidRootPart")
		if tr then
			local fp=tr.Position+tr.CFrame.LookVector*1.5
			local dir=(fp-hrp.Position).Unit
			hrp.AssemblyLinearVelocity=Vector3.new(dir.X*56.5,dir.Y*56.5,dir.Z*56.5)
		end
	end
end)

LP.CharacterAdded:Connect(function(char)
	lastHealth=100;task.wait(0.5)
	setupSpeedIndicator(char)
	if medusaCounterEnabled then setupMedusa(char) end
	unwalkAnimations={}
	if unwalkEnabled then task.wait(0.5);disableAnimations() end
end)
if LP.Character then setupSpeedIndicator(LP.Character) end

local function saveConfig()
	local function ks(e) return {kb=e.kb and e.kb.Name or nil,gp=e.gp and e.gp.Name or nil} end
	local cfg = {
		normalSpeed=NS,carrySpeed=CS,laggerSpeed=LS,
		dropBrainrotKey=ks(KB.DropBrainrot),autoLeftKey=ks(KB.AutoLeft),autoRightKey=ks(KB.AutoRight),
		autoBatKey=ks(KB.AutoBat),tpLeftKey=ks(KB.TPLeft),tpRightKey=ks(KB.TPRight),
		tpFloorKey=ks(KB.TPFloor),guiHideKey=ks(KB.GuiHide),floatKey=ks(KB.Float),
		speedToggleKey=ks(KB.SpeedToggle),
		grabRadius=Steal.StealRadius,stealDuration=Steal.StealDuration,
		antiRagdoll=antiRagdollEnabled,autoStealEnabled=Steal.AutoStealEnabled,
		infiniteJump=infJumpEnabled,medusaCounter=medusaCounterEnabled,
		brainrotReturnLeft=brainrotLeftEnabled,brainrotReturnRight=brainrotRightEnabled,
		carryMode=speedMode,autoBat=autoBatEnabled,
		unwalkEnabled=unwalkEnabled,
		floatHeight=floatHeight,floatEnabled=floatEnabled,
		stretchRez=stretchRezEnabled,
		tpMode=tpMode,
	}
	if writefile then pcall(function() writefile("CursedHubPC.json",HS:JSONEncode(cfg)) end) end
end
task.spawn(function() while task.wait(5) do saveConfig() end end)

local setInstaGrab
local setInfJumpVisual,setAntiRagVisual,setMedusaVisual
local setUnwalkVisual,setTPLeftVisual,setTPRightVisual
local durationInput,normalBox,carryBox,laggerBox,radInput
local floatHeightBox

local function buildGui()
	local C_BG=Color3.fromRGB(6,6,6)
	local C_ROW=Color3.fromRGB(16,16,16)
	local C_ROW_HOV=Color3.fromRGB(24,24,24)
	local C_BORDER=Color3.fromRGB(45,45,45)
	local C_HEADER=Color3.fromRGB(8,8,8)
	local C_ACCENT2=Color3.fromRGB(160,160,160)
	local C_DIM=Color3.fromRGB(90,90,90)
	local C_WHITE=Color3.fromRGB(255,255,255)
	local C_ON_BG=Color3.fromRGB(160,18,35)
	local C_OFF_BG=Color3.fromRGB(38,38,38)
	local C_RED_ACC=Color3.fromRGB(180,20,40)

	local old = game:GetService("CoreGui"):FindFirstChild("CursedHub");if old then old:Destroy() end
	local pg = LP:FindFirstChild("PlayerGui");if pg then local o2=pg:FindFirstChild("CursedHub");if o2 then o2:Destroy() end end

	local gui = Instance.new("ScreenGui")
	gui.Name="CursedHub";gui.ResetOnSpawn=false;gui.DisplayOrder=10;gui.IgnoreGuiInset=true
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	if not pcall(function() gui.Parent=game:GetService("CoreGui") end) then gui.Parent=LP:WaitForChild("PlayerGui") end

	local main = Instance.new("Frame",gui)
	main.Name="Main";main.Size=UDim2.new(0,300,0,426);main.Position=UDim2.new(0,38,0,38)
	main.BackgroundColor3=C_BG;main.BorderSizePixel=0;main.Active=true;main.ClipsDescendants=true
	Instance.new("UICorner",main).CornerRadius=UDim.new(0,12)

	local function makeDraggable(frame)
		local dragging,dragInput,dragStart,startPos = false,nil,nil,nil
		frame.InputBegan:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
				dragging=true;dragStart=inp.Position;startPos=frame.Position
				inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
			end
		end)
		frame.InputChanged:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dragInput=inp end
		end)
		UIS.InputChanged:Connect(function(inp)
			if inp==dragInput and dragging then
				local dx=inp.Position.X-dragStart.X;local dy=inp.Position.Y-dragStart.Y
				frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+dx,startPos.Y.Scale,startPos.Y.Offset+dy)
			end
		end)
	end
	makeDraggable(main)

	local header = Instance.new("Frame",main)
	header.Size=UDim2.new(1,0,0,50);header.BackgroundColor3=C_HEADER;header.BorderSizePixel=0;header.ZIndex=5
	Instance.new("UICorner",header).CornerRadius=UDim.new(0,12)
	local hDiv = Instance.new("Frame",header)
	hDiv.Size=UDim2.new(1,0,0,1);hDiv.Position=UDim2.new(0,0,1,-1);hDiv.BackgroundColor3=C_BORDER;hDiv.BorderSizePixel=0;hDiv.ZIndex=6
	local titleLbl = Instance.new("TextLabel",header)
	titleLbl.Size=UDim2.new(0,220,1,0);titleLbl.Position=UDim2.new(0,14,0,0);titleLbl.BackgroundTransparency=1
	titleLbl.Text="CURSED HUB";titleLbl.TextColor3=C_RED_ACC;titleLbl.Font=Enum.Font.GothamBlack;titleLbl.TextSize=15
	titleLbl.TextXAlignment=Enum.TextXAlignment.Left;titleLbl.ZIndex=6
	local closeBtn = Instance.new("TextButton",header)
	closeBtn.Size=UDim2.new(0,26,0,26);closeBtn.Position=UDim2.new(1,-34,0.5,-13);closeBtn.BackgroundTransparency=1
	closeBtn.BorderSizePixel=0;closeBtn.Text="--";closeBtn.TextColor3=C_WHITE
	closeBtn.Font=Enum.Font.GothamBlack;closeBtn.TextSize=20;closeBtn.ZIndex=50;closeBtn.AutoButtonColor=false

	local miniToggleBtn
	local guiVisible = true
	local function showGui() guiVisible=true;main.Visible=true;if miniToggleBtn then miniToggleBtn.Visible=false end end
	local function hideGui() guiVisible=false;main.Visible=false;if miniToggleBtn then miniToggleBtn.Visible=true end end
	local function toggleGuiVis() if guiVisible then hideGui() else showGui() end end

	closeBtn.MouseEnter:Connect(function() TS:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=C_ACCENT2}):Play() end)
	closeBtn.MouseLeave:Connect(function() TS:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=C_WHITE}):Play() end)
	closeBtn.MouseButton1Click:Connect(hideGui)

	local TAB_NAMES = {"Main","Move","Config"}
	local tabBtns = {};local activeTab = nil
	local tabBar = Instance.new("Frame",main)
	tabBar.Size=UDim2.new(1,0,0,30);tabBar.Position=UDim2.new(0,0,0,50);tabBar.BackgroundColor3=C_HEADER;tabBar.BorderSizePixel=0
	local tabDiv = Instance.new("Frame",main)
	tabDiv.Size=UDim2.new(1,0,0,1);tabDiv.Position=UDim2.new(0,0,0,80);tabDiv.BackgroundColor3=C_BORDER;tabDiv.BorderSizePixel=0
	local tabLL = Instance.new("UIListLayout",tabBar)
	tabLL.FillDirection=Enum.FillDirection.Horizontal;tabLL.SortOrder=Enum.SortOrder.LayoutOrder;tabLL.HorizontalAlignment=Enum.HorizontalAlignment.Left
	local pageHost = Instance.new("Frame",main)
	pageHost.Size=UDim2.new(1,0,1,-81);pageHost.Position=UDim2.new(0,0,0,81)
	pageHost.BackgroundTransparency=1;pageHost.BorderSizePixel=0;pageHost.ClipsDescendants=true
	local pages = {}
	for _,n in ipairs(TAB_NAMES) do
		local sf = Instance.new("ScrollingFrame",pageHost)
		sf.Size=UDim2.new(1,0,1,0);sf.BackgroundTransparency=1;sf.BorderSizePixel=0
		sf.ScrollBarThickness=2;sf.ScrollBarImageColor3=C_BORDER
		sf.AutomaticCanvasSize=Enum.AutomaticSize.Y;sf.CanvasSize=UDim2.new(0,0,0,0);sf.Visible=false
		local ll = Instance.new("UIListLayout",sf);ll.SortOrder=Enum.SortOrder.LayoutOrder;ll.Padding=UDim.new(0,2)
		local pp = Instance.new("UIPadding",sf)
		pp.PaddingLeft=UDim.new(0,10);pp.PaddingRight=UDim.new(0,10);pp.PaddingTop=UDim.new(0,8);pp.PaddingBottom=UDim.new(0,10)
		pages[n]=sf
	end
	local function switchTab(name)
		if activeTab then activeTab.Visible=false end
		activeTab=pages[name];activeTab.Visible=true
		for n2,d in pairs(tabBtns) do
			local ia = (n2==name)
			TS:Create(d.btn,TweenInfo.new(0.15),{TextColor3=ia and C_WHITE or C_DIM}):Play()
			d.underline.Visible=ia
		end
	end
	for i,name in ipairs(TAB_NAMES) do
		local btn = Instance.new("TextButton",tabBar)
		btn.Size=UDim2.new(0,80,1,0);btn.BackgroundColor3=C_HEADER;btn.BorderSizePixel=0;btn.LayoutOrder=i
		btn.Text=name;btn.TextColor3=name=="Main" and C_WHITE or C_DIM;btn.Font=Enum.Font.GothamBold;btn.TextSize=11;btn.AutoButtonColor=false
		local underline = Instance.new("Frame",btn)
		underline.Size=UDim2.new(0.7,0,0,2);underline.Position=UDim2.new(0.15,0,1,-2)
		underline.BackgroundColor3=C_RED_ACC;underline.BorderSizePixel=0;underline.Visible=(name=="Main")
		tabBtns[name]={btn=btn,underline=underline}
		btn.MouseButton1Click:Connect(function() switchTab(name) end)
	end
	activeTab=pages["Main"];activeTab.Visible=true

	local rowCounts = {Main=0,Move=0,Config=0}
	local function LO(pg) rowCounts[pg]=rowCounts[pg]+1;return rowCounts[pg] end

	local function sect(pg,text)
		local row = Instance.new("Frame",pages[pg]);row.Size=UDim2.new(1,0,0,20)
		row.BackgroundTransparency=1;row.BorderSizePixel=0;row.LayoutOrder=LO(pg)
		local t2 = Instance.new("Frame",row);t2.Size=UDim2.new(0,3,0,12);t2.Position=UDim2.new(0,0,0.5,-6)
		t2.BackgroundColor3=C_RED_ACC;t2.BorderSizePixel=0;Instance.new("UICorner",t2).CornerRadius=UDim.new(0,2)
		local lbl = Instance.new("TextLabel",row);lbl.Size=UDim2.new(1,-8,1,0);lbl.Position=UDim2.new(0,8,0,0)
		lbl.BackgroundTransparency=1;lbl.Text=text:upper();lbl.TextColor3=C_RED_ACC
		lbl.Font=Enum.Font.GothamBlack;lbl.TextSize=9;lbl.TextXAlignment=Enum.TextXAlignment.Left
	end

	local function mkRow(pg,h)
		local f = Instance.new("Frame",pages[pg]);f.Size=UDim2.new(1,0,0,h or 38)
		f.BackgroundColor3=C_ROW;f.BorderSizePixel=0;f.LayoutOrder=LO(pg)
		Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
		f.MouseEnter:Connect(function() TS:Create(f,TweenInfo.new(0.1),{BackgroundColor3=C_ROW_HOV}):Play() end)
		f.MouseLeave:Connect(function() TS:Create(f,TweenInfo.new(0.1),{BackgroundColor3=C_ROW}):Play() end)
		return f
	end

	local function mkLbl(row,txt)
		local l = Instance.new("TextLabel",row);l.Size=UDim2.new(0.55,0,1,0);l.Position=UDim2.new(0,12,0,0)
		l.BackgroundTransparency=1;l.Text=txt;l.TextColor3=C_WHITE;l.Font=Enum.Font.GothamBold
		l.TextSize=12;l.TextXAlignment=Enum.TextXAlignment.Left;return l
	end

	local function mkInput(pg,label,default,onChange)
		local row=Instance.new("Frame",pages[pg]);row.Size=UDim2.new(1,0,0,38)
		row.BackgroundTransparency=1;row.BorderSizePixel=0;row.LayoutOrder=LO(pg)
		mkLbl(row,label)
		local box=Instance.new("TextBox",row);box.Size=UDim2.new(0,82,0,26);box.Position=UDim2.new(1,-88,0.5,-13)
		box.BackgroundTransparency=1;box.BorderSizePixel=0;box.Text=tostring(default);box.TextColor3=C_WHITE
		box.Font=Enum.Font.GothamBlack;box.TextSize=12;box.ClearTextOnFocus=false;box.ZIndex=10
		box.FocusLost:Connect(function()
			if onChange then local n=tonumber(box.Text);if n then onChange(n) else box.Text=tostring(default) end end
		end)
		return box
	end

	local function mkStatus(pg,label,val)
		local row=Instance.new("Frame",pages[pg]);row.Size=UDim2.new(1,0,0,36)
		row.BackgroundTransparency=1;row.BorderSizePixel=0;row.LayoutOrder=LO(pg)
		mkLbl(row,label)
		local v=Instance.new("TextLabel",row);v.Size=UDim2.new(0.45,-10,1,0);v.Position=UDim2.new(0.52,0,0,0)
		v.BackgroundTransparency=1;v.Text=val;v.TextColor3=C_ACCENT2
		v.Font=Enum.Font.GothamBlack;v.TextSize=12;v.TextXAlignment=Enum.TextXAlignment.Right;return v
	end

	local function mkToggle(pg,label,defKey,defOn,onToggle,onKeyChanged)
		local row=mkRow(pg,38)
		local lbl=Instance.new("TextLabel",row);lbl.Size=UDim2.new(0,130,1,0);lbl.Position=UDim2.new(0,12,0,0)
