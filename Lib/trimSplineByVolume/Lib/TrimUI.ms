struct TrimUI
(
    core = undefined,
    ops = undefined,
    
    function getSceneVolumes =
    (
        local v_vols = #()
        local t_sel = getNodeByName "TRIM_SELECTION"
        if (isValidNode t_sel) then appendIfUnique v_vols t_sel
        for n in selection where (isValidNode n and core.isVolumeDummy n) do appendIfUnique v_vols n
        for i = 0 to LayerManager.count - 1 do
        (
            local lay = LayerManager.getLayer i
            local l_nodes = #(); lay.nodes &l_nodes
            for n in l_nodes where (isValidNode n and core.isVolumeDummy n) do appendIfUnique v_vols n
        )
        v_vols
    ),

    function showUI script_version =
    (
        try(destroyDialog ::ro_trimSplineByVolume)catch()
        global ro_trimSplineByVolume
        ::TrimGlobalApp = #(core, ops, script_version, getSceneVolumes)
        
        rollout ro_trimSplineByVolume "Trim Splines" width:220
        (
            local c_vol = undefined
            local ini_f = getDir #plugcfg + "\\trimSplineByVolume.ini"
            local l_tol = 0.001 
            local l_text = ""
            
            group "Level 1: Trim Canvas"
            (
                button btn_c "CLEAN UP CANVAS" width:190 height:30 tooltip:"Centers at [0,0,0], ignores grouped objects and scales to tightly wrap 90% of the core spline density."
                button btn_rc "TRIM CANVAS (DELETE OUTSIDE)" width:190 height:30 tooltip:"Deletes all objects whose bounding box is completely outside the Canvas volume."
            )
            group "Level 2: Trim View"
            (
                dotNetControl lbl_v "System.Windows.Forms.Label" width:190 height:24 align:#center tooltip:"Auto-detected layer volume status"
                timer tmr_v "Vol Ticker" interval:500 active:true
                button btn_g "Generate Volumes" width:190 height:30 tooltip:"Left-Click: Single Volume in Current/Selected Layer\nRight-Click: Auto-gen Volumes for all Visible Layers"
                button btn_r "TRIM SPLINES (SINGLE)" width:190 height:30 tooltip:"Trim all valid splines using the active volume"
                button btn_m "MASS MODE (ALL LAYERS)" width:190 height:30 tooltip:"Iterate layers, isolating volumes for processing. Deletes original trees if multiple dummies exist."
            )
            group "Settings"
            (
                spinner spn_t "Tolerance: " range:[0.00001, 1000.0, 0.001] scale:0.00001 type:#float align:#center tooltip:"Threshold for Knot bounding & Auto-Weld"
                checkbox chk_d "Delete Empty Splines" checked:true align:#center tooltip:"Delete completely empty remaining splines"
                checkbox chk_f "Ignore Frozen Objects" checked:true align:#center tooltip:"Skip processing frozen objects"
            )
            
            function updateVolumeLabel =
            (
                local a_vols = ::TrimGlobalApp[4]()
                local t_count = a_vols.count
                if (t_count == 0) then
                (
                    c_vol = undefined
                    if (l_text != "None Selected") then ( lbl_v.Text = "None Selected"; lbl_v.ForeColor = (dotNetClass "System.Drawing.Color").Red; l_text = "None Selected" )
                )
                else
                (
                    local a_vol = undefined
                    local s_vols = for n in selection where (isValidNode n and ::TrimGlobalApp[1].isVolumeDummy n) collect n
                    if (s_vols.count > 0) then a_vol = s_vols[1]
                    if (a_vol == undefined) then ( a_vol = a_vols[1] )
                    c_vol = a_vol
                    local n_txt = if (t_count > 1) then ("Volumes in scene: " + (t_count as string)) else a_vol.name
                    if (l_text != n_txt) then ( lbl_v.Text = n_txt; lbl_v.ForeColor = (dotNetClass "System.Drawing.Color").LimeGreen; l_text = n_txt )
                )
            )
            
            function saveSet =
            (
                setINISetting ini_f "Set" "Tol" (spn_t.value as string); setINISetting ini_f "Set" "Del" (chk_d.checked as string); setINISetting ini_f "Set" "Frz" (chk_f.checked as string)
                local p = getDialogPos ::ro_trimSplineByVolume
                setINISetting ini_f "Set" "PX" (p.x as string); setINISetting ini_f "Set" "PY" (p.y as string)
            )
            
            function loadSet =
            (
                local t = getINISetting ini_f "Set" "Tol"; if (t != "") then ( spn_t.value = amax 0.00001 (t as float); l_tol = spn_t.value )
                local d = getINISetting ini_f "Set" "Del"; if (d != "") then chk_d.checked = (d == "true")
                local f = getINISetting ini_f "Set" "Frz"; if (f != "") then chk_f.checked = (f == "true")
            )
            
            on tmr_v tick do updateVolumeLabel()
            
            on ro_trimSplineByVolume open do
            (
                ro_trimSplineByVolume.title = "Trim Splines " + ::TrimGlobalApp[3]
                lbl_v.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter; lbl_v.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
                lbl_v.Font = dotNetObject "System.Drawing.Font" "Arial" 8 (dotNetClass "System.Drawing.FontStyle").Bold; lbl_v.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
                loadSet(); updateVolumeLabel()
            )
            
            on ro_trimSplineByVolume close do saveSet()
            
            on btn_c pressed do ::TrimGlobalApp[2].generateCanvasVolume()
            
            on btn_rc pressed do ( saveSet(); ::TrimGlobalApp[2].trimCanvas quiet:false ignore_frz:chk_f.checked )
            
            on btn_g pressed do ( tmr_v.active = false; ::TrimGlobalApp[2].generateSingleVolumeInCurrentLayer(); tmr_v.active = true; updateVolumeLabel() )
            
            on btn_g rightClick do ( tmr_v.active = false; ::TrimGlobalApp[2].generateVolumes(); tmr_v.active = true; updateVolumeLabel() )
            
            on spn_t changed val do
            (
                spn_t.value = if val > l_tol then l_tol * 10.0 else l_tol / 10.0
                if (spn_t.value > 1000.0) then spn_t.value = 1000.0
                if (spn_t.value < 0.00001) then spn_t.value = 0.00001
                l_tol = spn_t.value
            )
            
            on btn_r pressed do
            (
                saveSet(); tmr_v.active = false
                if (isValidNode c_vol) then ::TrimGlobalApp[1].run c_vol quiet:false tol_val:spn_t.value del_empty:chk_d.checked ignore_frz:chk_f.checked
                else messageBox "Select a valid volume first." title:"Trim Splines"
                tmr_v.active = true; updateVolumeLabel()
            )
            
            on btn_m pressed do
            (
                saveSet(); tmr_v.active = false
                ::TrimGlobalApp[2].runMassMode quiet:false tol_val:spn_t.value del_empty:chk_d.checked ignore_frz:chk_f.checked
                tmr_v.active = true; updateVolumeLabel()
            )
        )
        local px = getINISetting (getDir #plugcfg + "\\trimSplineByVolume.ini") "Set" "PX"
        local py = getINISetting (getDir #plugcfg + "\\trimSplineByVolume.ini") "Set" "PY"
        if (px != "" and py != "") then createDialog ::ro_trimSplineByVolume pos:[px as float, py as float] else createDialog ::ro_trimSplineByVolume
    )
)