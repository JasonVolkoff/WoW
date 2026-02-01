function ToggleNodes()
	-- Get Language for button
	local text_on = "GM2 on";
	local text_off = "GM2 off";
    local gameLocale = GetLocale()
	
	if gameLocale == "enGB" then	gameLocale = "enUS"	end	
	if gameLocale == "esMX" then	gameLocale = "esES" end
	if gameLocale == "zhTW" then	gameLocale = "zhCN" end	
	
	if gameLocale == "frFR" then
		text_on = "Afficher GM2"
		text_off = "Masquer GM2"
	end	
	if gameLocale == "enUS" then
		text_on = "Show GM2 nodes"
		text_off = "Hide GM2 nodes"
	end
	if gameLocale == "esES" then
		text_on = "Mostrar GM2"
		text_off = "Ocultar GM2"
	end
	if gameLocale == "deDE" then
		text_on = "Zeige GM2"
		text_off = "Verstecke GM2"
	end
	if gameLocale == "ruRU" then
		text_on = "показывать GM2"
		text_off = "Спрятать GM2"
	end
	if gameLocale == "zhCN" then
		text_on = "以显示 GM2"
		text_off = "隐藏 GM2"
	end	
	if gameLocale == "koKR" then
		text_on = "보여주다 GM2"
		text_off = "숨는 장소 GM2"
	end
	
	-- Update the show/hide state
	GatherMate2.db.profile["showWorldMap"] = not GatherMate2.db.profile["showWorldMap"]
	GatherMate2:GetModule("Config"):UpdateConfig()
	
	-- Update the text on the map show/hide button
    if GatherMate2.db.profile["showWorldMap"] then
        GatherMate2_Toggle:SetText(text_off);
    else
        GatherMate2_Toggle:SetText(text_on);
    end
end
