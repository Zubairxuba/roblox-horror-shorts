-- AI CAST PREP (2026-11-24). Run in Edit (fetch it through the bridge into a temp ModuleScript and require it).
-- generate_avatar(textPrompt, pipelineName="npc", dynamicHead=true) gives an R15+ actor with a moving face (FaceControls),
-- but: a far-away WorldPivot, facing -Z and adult height. prep() fixes those. Its A-pose rest is FINE: catalog idles/emotes
-- play correctly (2026-11-24: the odd poses in the first test were K.fidget, not the rig). Never rewrite its RigAttachments.
local M = {}

-- name, pack ("cartoony"...), scale (kids ~0.8 of the 6-stud AI adult), pos (Vector3 on the ground), faceTo (Vector3)
function M.prep(m, name, pack, scale, pos, faceTo)
	m.WorldPivot = m.HumanoidRootPart.CFrame
	if scale and math.abs(m:GetScale() - scale) > 0.01 then m:ScaleTo(scale) end
	m.Name = name; m:SetAttribute("Pack", pack)
	local p = pos or m:GetPivot().Position
	m:PivotTo(CFrame.lookAt(p, faceTo and Vector3.new(faceTo.X, p.Y, faceTo.Z) or p + Vector3.new(0, 0, 1)))
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, 0.5 + sz.Y / 2 - cf.Position.Y, 0))   -- feet on the 0.5 ground
	m.Parent = workspace.Cast
	return name .. string.format(": h=%.2f", sz.Y)
end

return M
