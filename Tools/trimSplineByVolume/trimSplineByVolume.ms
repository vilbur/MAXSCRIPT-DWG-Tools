--clearListener(); print("Cleared in: "+getSourceFileName())

/* version 3.9 - Refactored Modules */

global TrimApp_Core
global TrimApp_Ops
global TrimApp_UI

filein( getFilenamePath(getSourceFileName()) + "/Lib/TrimCore.ms" )	--"./Lib/TrimCore.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/TrimOperations.ms" )	--"./Lib/TrimOperations.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/TrimUI.ms" )	--"./Lib/TrimUI.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/bboxDataTools.ms" )	--"./Lib/bboxDataTools.ms"

function trimGetNextDummy cur_name =
(
    local rx = dotNetClass "System.Text.RegularExpressions.Regex"
    local m_num = rx.Match cur_name "^(.*?)(\\d+)$"
    if (m_num.Success) then
    (
        local pref = m_num.Groups.Item[1].Value, n_str = m_num.Groups.Item[2].Value
        local p_len = n_str.count, n_val = (n_str as integer) + 1
        local next_str = n_val as string
        while (next_str.count < p_len) do next_str = "0" + next_str
        return pref + next_str
    )
    local m_let = rx.Match cur_name "^(.*[^a-zA-Z])([a-zA-Z])$|^([a-zA-Z])$"
    if (m_let.Success) then
    (
        local pref = "", c_str = ""
        if (m_let.Groups.Item[1].Success) then ( pref = m_let.Groups.Item[1].Value; c_str = m_let.Groups.Item[2].Value ) else ( c_str = m_let.Groups.Item[3].Value )
        local c_code = bit.charAsInt c_str
        if (c_code == 90) then c_code = 65 else if (c_code == 122) then c_code = 97 else c_code += 1
        return pref + (bit.intAsChar c_code)
    )
    return cur_name + "_01"
)

function trimGetUniqueDummy s_name =
(
    local c_name = trimGetNextDummy s_name
    local m_iters = 1000, c_iter = 0
    while ((isValidNode (getNodeByName c_name)) and c_iter < m_iters) do ( c_name = trimGetNextDummy c_name; c_iter += 1 )
    return c_name
)

function trimHandleCloned =
(
    local cb_p = callbacks.notificationParam()
    if (cb_p != undefined and cb_p.count >= 2) then
    (
        local o_n = cb_p[1], n_n = cb_p[2]
        local rx = dotNetClass "System.Text.RegularExpressions.Regex"
        
        for i = 1 to n_n.count do
        (
            local n = n_n[i]
            if (isValidNode n and ::TrimApp_Core.isVolumeDummy n) then
            (
                if (isValidNode o_n[i]) then
                (
                    -- Strip trailing numbers to compare base names
                    local base_orig = rx.Replace o_n[i].name "[0-9]+$" ""
                    local base_new = rx.Replace n.name "[0-9]+$" ""
                    
                    -- If base names match, user accepted Max's default clone name. Apply custom rename.
                    -- If they don't match, user typed a custom name in the clone dialog, so leave it alone.
                    if (base_orig == base_new) then
                    (
                        n.name = trimGetUniqueDummy o_n[i].name
                    )
                )
            )
        )
    )
)
/** Open canvas trim splines tool
 */
function openCanvasTrimSplinesTool =
(
	--format "\n"; print ".openCanvasTrimSplinesTool()"
	
	
	TrimApp_Core = TrimCore()
	TrimApp_Ops = TrimOperations core:TrimApp_Core
	TrimApp_UI = TrimUI core:TrimApp_Core ops:TrimApp_Ops
	
	TrimApp_UI.showUI "v3.9"
	
	
	callbacks.removeScripts id:#trimSplineVolumeClone
	callbacks.addScript #postNodesCloned "trimHandleCloned()" id:#trimSplineVolumeClone
)
/*

	format "DEV OPENING OF openCanvasTrimSplinesTool(): %\n" (openCanvasTrimSplinesTool())

*/ 
