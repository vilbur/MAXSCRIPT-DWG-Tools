clearListener(); print("Cleared in: "+getSourceFileName())


/* version 2.6
    Trim splines by selected volume
    Fix: Implemented 3-knot sliding window evaluation to accurately preserve boundary-crossing segments
         while aggressively removing exterior spikes and excess bulk geometry. 
         Pre-calculates knot states to prevent shifting index deletion bugs.
*/

struct trimSplineByVolume_v
(
    script_version = "v2.6",

    function isNodeUnhidden node_value = (isValidNode node_value and node_value.isHidden == false),
    function isNodeLayerVisible node_value = (isValidNode node_value and (node_value.layer == undefined or node_value.layer.on)),
    
    function isNodeProcessable node_value ignore_frozen:true =
    (
        if (isValidNode node_value and isNodeUnhidden node_value and isNodeLayerVisible node_value) then
            if (not (ignore_frozen == true and node_value.isFrozen == true)) then return true
        
        return false
    ),

    function isSplineShapeNode node_value = (isValidNode node_value and superClassOf node_value == Shape),

    function openParentGroups node_value =
    (
        local opened_count = 0
        if (isValidNode node_value) then
        (
            local p_node = node_value.parent
            while (p_node != undefined) do
            (
                if (isGroupHead p_node) then try ( setGroupOpen p_node true; opened_count += 1 ) catch()
                p_node = p_node.parent
            )
        )
        opened_count
    ),

    function openGroupsOfUnhiddenObjects ignore_frozen:true =
    (
        local opened_count = 0
        for n in objects where (isNodeProcessable n ignore_frozen:ignore_frozen) do opened_count += openParentGroups n
        opened_count
    ),

    function getSelectedVolumeNodeAndCount =
    (
        local found_node = undefined
        local total_count = 0
        
        local valid_sel = for n in selection where (isValidNode n and superClassOf n != Shape and not isGroupHead n) collect n
        if (valid_sel.count > 0) then
        (
            found_node = valid_sel[1]
            total_count = valid_sel.count
        )
        else
        (
            local valid_objs = for n in objects where (isNodeProcessable n ignore_frozen:false and superClassOf n != Shape and not isGroupHead n) collect n
            if (valid_objs.count > 0) then
            (
                found_node = valid_objs[1]
                total_count = valid_objs.count
            )
        )
        #(found_node, total_count)
    ),

    function getVolumeBoundsData volume_node_value =
    (
        local vol_tm = volume_node_value.objectTransform
        #(nodeGetBoundingBox volume_node_value vol_tm, inverse vol_tm)
    ),

    function isWorldPointInsideVolume world_point bounds_data tolerance_value:0.001 =
    (
        local min_p = bounds_data[1][1], max_p = bounds_data[1][2], vol_inv = bounds_data[2]
        local p = world_point * vol_inv
        (p.x >= (min_p.x - tolerance_value) and p.x <= (max_p.x + tolerance_value) and \
         p.y >= (min_p.y - tolerance_value) and p.y <= (max_p.y + tolerance_value) and \
         p.z >= (min_p.z - tolerance_value) and p.z <= (max_p.z + tolerance_value))
    ),

    function deleteEmptySplines shape_node =
    (
        local deleted_count = 0
        for sp_idx = (numSplines shape_node) to 1 by -1 where (numSegments shape_node sp_idx) < 1 do
        (
            deleteSpline shape_node sp_idx
            deleted_count += 1
        )
        deleted_count
    ),
    
    function batchPrepareShapes shapes_array threshold_value =
    (
        if (shapes_array.count > 0) then
        (
            local prev_cmd_mode = getCommandPanelTaskMode()
            setCommandPanelTaskMode #modify
            
            for s in shapes_array do
            (
                if (classOf s != SplineShape) then convertToSplineShape s
                
                select s
                subObjectLevel = 1
                
                for sp_idx = 1 to (numSplines s) do
                (
                    local knot_count = numKnots s sp_idx
                    local k_array = for k = 1 to knot_count collect k
                    setKnotSelection s sp_idx k_array keep:true
                )
                
                try (
                    s.weldThreshold = threshold_value
                    splineOps.weld s
                ) catch (
                    format "WARNING: splineOps.weld failed on %\n" s.name
                )
                
                subObjectLevel = 0
            )
            clearSelection()
            if (prev_cmd_mode != undefined) then setCommandPanelTaskMode prev_cmd_mode
        )
    ),

    function trimShapeByVolume shape_node bounds_data tolerance_value:0.001 delete_empty:true =
    (
        local del_k = 0, del_sp = 0
        if (isValidNode shape_node and isSplineShapeNode shape_node) then
        (
            for sp_idx = (numSplines shape_node) to 1 by -1 do
            (
                local k_count = numKnots shape_node sp_idx
                local is_closed = isClosed shape_node sp_idx
                
                -- Pre-calculate OUT states to avoid shifting index bugs during reverse deletion
                local out_states = for k = 1 to k_count collect (not (isWorldPointInsideVolume (getKnotPoint shape_node sp_idx k) bounds_data tolerance_value:tolerance_value))
                
                for k_idx = k_count to 1 by -1 do
                (
                    if (out_states[k_idx]) then
                    (
                        local should_delete = false
                        
                        if (k_count > 2) then
                        (
                            local prev_idx, next_idx
                            if (is_closed) then
                            (
                                prev_idx = if (k_idx == 1) then k_count else (k_idx - 1)
                                next_idx = if (k_idx == k_count) then 1 else (k_idx + 1)
                            )
                            else
                            (
                                prev_idx = k_idx - 1
                                next_idx = k_idx + 1
                            )
                            
                            local has_prev = (prev_idx >= 1 and prev_idx <= k_count)
                            local has_next = (next_idx >= 1 and next_idx <= k_count)
                            
                            if (has_prev and has_next) then
                            (
                                local prev_out = out_states[prev_idx]
                                local next_out = out_states[next_idx]
                                
                                -- 3-Knot Logic: Delete if neighbors are both inside (spike removal) OR both outside (excess removal)
                                if (prev_out == next_out) then should_delete = true
                            )
                            else if (has_prev and not has_next) then
                            (
                                if (out_states[prev_idx]) then should_delete = true
                            )
                            else if (not has_prev and has_next) then
                            (
                                if (out_states[next_idx]) then should_delete = true
                            )
                        )
                        else if (k_count == 2) then
                        (
                            -- Fallback for 2-knot segments to ensure isolated outside points are swept
                            local other_idx = if (k_idx == 1) then 2 else 1
                            if (out_states[other_idx]) then should_delete = true
                        )
                        else if (k_count == 1) then
                        (
                            should_delete = true
                        )
                        
                        if (should_delete) then
                        (
                            deleteKnot shape_node sp_idx k_idx
                            del_k += 1
                        )
                    )
                )
            )
            del_sp = deleteEmptySplines shape_node
            updateShape shape_node
            if (delete_empty and (numSplines shape_node) < 1) then delete shape_node
        )
        #(del_k, del_sp)
    ),

    function collectProcessShapes volume_node_value ignore_frozen:true =
    (
        for n in objects where (isSplineShapeNode n and n != volume_node_value and isNodeProcessable n ignore_frozen:ignore_frozen) collect n
    ),

    function turnOnLayerChain lay =
    (
        if (lay != undefined) then
        (
            lay.on = true
            local p_lay = undefined
            try ( p_lay = lay.getParent() ) catch()
            if (p_lay != undefined) then turnOnLayerChain p_lay
        )
    ),

    function unhideLayerHierarchy lay =
    (
        lay.on = true
        local l_nodes = #()
        lay.nodes &l_nodes
        for n in l_nodes where isValidNode n do n.isHidden = false
        try ( for c = 1 to lay.getNumChildren() do unhideLayerHierarchy (lay.getChild c) ) catch()
    ),
    
    function collectNodesFromLayer lay &nodeList =
    (
        local l_nodes = #()
        lay.nodes &l_nodes
        for n in l_nodes do append nodeList n
        try ( for c = 1 to lay.getNumChildren() do collectNodesFromLayer (lay.getChild c) &nodeList ) catch()
    ),

    function generateLayerVolumes include_nested:false =
    (
        undo "Generate Layer Volumes" on
        (
            local gen_count = 0
            for i = 0 to LayerManager.count - 1 do
            (
                local lay = LayerManager.getLayer i
                if (lay.on) then
                (
                    local is_top = true
                    try ( if (lay.getParent() != undefined) then is_top = false ) catch()
                    
                    if (include_nested == true or is_top == true) then
                    (
                        local lay_name = lay.name
                        local all_nodes = #()
                        collectNodesFromLayer lay &all_nodes
                        
                        local min_p = [1e9, 1e9, 1e9]
                        local max_p = [-1e9, -1e9, -1e9]
                        local valid_bbox = false
                        
                        for n in all_nodes where isValidNode n and n.name != lay_name do
                        (
                            local bb = nodeGetBoundingBox n (matrix3 1)
                            if (bb[1].x < min_p.x) then min_p.x = bb[1].x
                            if (bb[1].y < min_p.y) then min_p.y = bb[1].y
                            if (bb[1].z < min_p.z) then min_p.z = bb[1].z
                            if (bb[2].x > max_p.x) then max_p.x = bb[2].x
                            if (bb[2].y > max_p.y) then max_p.y = bb[2].y
                            if (bb[2].z > max_p.z) then max_p.z = bb[2].z
                            valid_bbox = true
                        )
                        
                        if (valid_bbox) then
                        (
                            local existing = getNodeByName lay_name
                            if (isValidNode existing) then delete existing
                            
                            local center = (min_p + max_p) / 2.0
                            local bb_sz = max_p - min_p
                            local avg_xy = (bb_sz.x + bb_sz.y) / 2.0
                            local h_size = avg_xy / 2.0
                            if (h_size <= 0) then h_size = 1.0
                            
                            local l_color = color 255 255 255
                            try (l_color = lay.wireColor) catch()
                            
                            try (
                                local d = VolumeHelper name:lay_name pos:center size:h_size color:l_color
                                lay.addNode d
                                gen_count += 1
                            ) catch (
                                format "VolumeHelper class missing. Ensure plugin is loaded.\n"
                            )
                        )
                    )
                )
            )
            messageBox ("Generated " + gen_count as string + " layer volume helpers.") title:"Generate Volumes"
        )
    ),

    function run explicit_volume quiet:false tolerance_value:0.001 delete_empty:true ignore_frozen:true =
    (
        if (explicit_volume == undefined or not isValidNode explicit_volume) then 
        (
            if (not quiet) then messageBox "Select a valid helper volume." title:"Trim Splines"
            return undefined
        )
        
        local opened_g = openGroupsOfUnhiddenObjects ignore_frozen:ignore_frozen
        local b_data = getVolumeBoundsData explicit_volume
        local s_nodes = collectProcessShapes explicit_volume ignore_frozen:ignore_frozen
        batchPrepareShapes s_nodes tolerance_value
        
        local p_count = 0, del_s = 0, del_k = 0, del_sp = 0
        for i = 1 to s_nodes.count do
        (
            if (not quiet) then (format "\rProcessing % of %..." i s_nodes.count; windows.processPostedMessages())
            if (isValidNode s_nodes[i]) then
            (
                local res = trimShapeByVolume s_nodes[i] b_data tolerance_value:tolerance_value delete_empty:delete_empty
                p_count += 1; del_k += res[1]; del_sp += res[2]
                if (not isValidNode s_nodes[i]) then del_s += 1
            )
        )
        if (not quiet) then format "\n"
        if (not quiet) then completeRedraw()
        if (not quiet) then messageBox ("Processed: " + p_count as string + "\nDeleted Knots: " + del_k as string) title:"Trim Splines By Volume"
        
        return #(p_count, del_s, del_k, del_sp)
    ),

    function runMassMode quiet:false tolerance_value:0.001 delete_empty:true ignore_frozen:true =
    (
        local mass_volumes = #()
        for i = 0 to LayerManager.count - 1 do
        (
            local lay = LayerManager.getLayer i
            local lay_nodes = #()
            lay.nodes &lay_nodes
            local found_vol = undefined
            for n in lay_nodes while found_vol == undefined where (n.name == lay.name and superClassOf n != Shape and not isGroupHead n) do found_vol = n
            if (found_vol != undefined) then append mass_volumes #(lay, found_vol)
        )

        if (mass_volumes.count == 0) then return messageBox "No valid volumes found!\nCreate volumes with 'Generate Layer Volumes' first." title:"Mass Mode"

        local total_p = 0, total_del_s = 0, total_del_k = 0, total_del_sp = 0
        local processed_layers = #()

        for v = 1 to mass_volumes.count do
        (
            local target_lay = mass_volumes[v][1]
            local vol_node = mass_volumes[v][2]
            
            if (not quiet) then (format "\rMass Mode: '%' (%/%)..." vol_node.name v mass_volumes.count; windows.processPostedMessages())
            
            for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
            
            turnOnLayerChain target_lay
            unhideLayerHierarchy target_lay
            
            appendIfUnique processed_layers target_lay
            
            local res = run vol_node quiet:true tolerance_value:tolerance_value delete_empty:delete_empty ignore_frozen:ignore_frozen
            
            if (res != undefined) then
            (
                total_p += res[1]
                total_del_s += res[2]
                total_del_k += res[3]
                total_del_sp += res[4]
            )
        )
        
        for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
        for lay in processed_layers do 
        (
            turnOnLayerChain lay
            unhideLayerHierarchy lay
        )
        
        if (not quiet) then format "\n"
        completeRedraw()
        if (not quiet) then messageBox ("Mass Mode Complete\nProcessed Pairs: " + mass_volumes.count as string + "\nProcessed Splines: " + total_p as string + "\nKnots Deleted: " + total_del_k as string) title:"Mass Mode"
    ),
    
    function showUI =
    (
        try(destroyDialog ::ro_trimSplineByVolume)catch()
        global ro_trimSplineByVolume
        rollout ro_trimSplineByVolume "Trim Splines" width:220
        (
            local current_vol = undefined
            local ini_file = getDir #plugcfg + "\\trimSplineByVolume.ini"
            local last_tol = 0.001 
            
            group "Volume Targets"
            (
                dotNetControl lbl_vol "System.Windows.Forms.Label" width:190 height:24 align:#center tooltip:"Currently assigned volume object"
                button btn_pick "Load volume from selection" width:190 height:40 tooltip:"Assigns the selected volume object"
                button btn_gen "Generate Layer Volumes" width:190 height:40 tooltip:"L-Click: Top layers only | R-Click: All nested layers"
            )
            
            group "Settings"
            (
                spinner spn_tol "Tolerance: " range:[0.00001, 1000.0, 0.001] scale:0.00001 type:#float align:#center tooltip:"Threshold for Knot bounding & Auto-Weld"
                checkbox chk_del "Delete Empty Splines" checked:true align:#center tooltip:"Delete completely empty remaining splines"
                checkbox chk_frz "Ignore Frozen Objects" checked:true align:#center tooltip:"Skip processing frozen splines"
            )
            
            button btn_run "TRIM SPLINES (SINGLE)" width:190 height:40 tooltip:"Trim all valid splines using the assigned volume"
            button btn_mass "MASS MODE (ALL LAYERS)" width:190 height:40 offset:[0,5] tooltip:"Iterate layers, using their named VolumeHelpers to isolate & trim layer geometry"
            
            function saveSettings =
            (
                setINISetting ini_file "Settings" "Tolerance" (spn_tol.value as string)
                setINISetting ini_file "Settings" "DeleteEmpty" (chk_del.checked as string)
                setINISetting ini_file "Settings" "IgnoreFrozen" (chk_frz.checked as string)
                
                local p = getDialogPos ::ro_trimSplineByVolume
                setINISetting ini_file "Settings" "PosX" (p.x as string)
                setINISetting ini_file "Settings" "PosY" (p.y as string)
            )
            
            function loadSettings =
            (
                local t = getINISetting ini_file "Settings" "Tolerance"
                if (t != "") then ( spn_tol.value = amax 0.00001 (t as float); last_tol = spn_tol.value )
                local de = getINISetting ini_file "Settings" "DeleteEmpty"
                if (de != "") then chk_del.checked = (de == "true")
                local ig = getINISetting ini_file "Settings" "IgnoreFrozen"
                if (ig != "") then chk_frz.checked = (ig == "true")
            )
            
            function updateVol node count_val =
            (
                current_vol = node
                if (isValidNode node) then 
                (
                    if (count_val > 1) then lbl_vol.Text = node.name + " (1 of " + count_val as string + " found)"
                    else lbl_vol.Text = node.name
                    
                    lbl_vol.ForeColor = (dotNetClass "System.Drawing.Color").LimeGreen 
                ) 
                else 
                (
                    lbl_vol.Text = "None Selected!"
                    lbl_vol.ForeColor = (dotNetClass "System.Drawing.Color").Red
                )
                lbl_vol.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
            )
            
            on ro_trimSplineByVolume open do
            (
                lbl_vol.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                lbl_vol.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
                lbl_vol.Font = dotNetObject "System.Drawing.Font" "Arial" 9 (dotNetClass "System.Drawing.FontStyle").Bold
                loadSettings()
                
                local v_data = ::trimSplineByVolume.getSelectedVolumeNodeAndCount()
                updateVol v_data[1] v_data[2]
            )
            on ro_trimSplineByVolume close do saveSettings()
            
            on btn_gen pressed do ::trimSplineByVolume.generateLayerVolumes include_nested:false
            on btn_gen rightclick do ::trimSplineByVolume.generateLayerVolumes include_nested:true
            
            on btn_pick pressed do
            (
                local v_data = ::trimSplineByVolume.getSelectedVolumeNodeAndCount()
                if (v_data[1] != undefined) then updateVol v_data[1] v_data[2]
                else messageBox "No valid volume selected or found." title:"Trim Splines"
            )
            
            on spn_tol changed val do
            (
                spn_tol.value = if val > last_tol then last_tol * 10.0 else last_tol / 10.0
                if (spn_tol.value > 1000.0) then spn_tol.value = 1000.0
                if (spn_tol.value < 0.00001) then spn_tol.value = 0.00001
                last_tol = spn_tol.value
            )
            
            on btn_run pressed do
            (
                saveSettings()
                if (isValidNode current_vol) then ::trimSplineByVolume.run current_vol quiet:false tolerance_value:spn_tol.value delete_empty:chk_del.checked ignore_frozen:chk_frz.checked
                else messageBox "Select a valid volume first." title:"Trim Splines"
            )

            on btn_mass pressed do
            (
                saveSettings()
                ::trimSplineByVolume.runMassMode quiet:false tolerance_value:spn_tol.value delete_empty:chk_del.checked ignore_frozen:chk_frz.checked
            )
        )
        
        local px = getINISetting (getDir #plugcfg + "\\trimSplineByVolume.ini") "Settings" "PosX"
        local py = getINISetting (getDir #plugcfg + "\\trimSplineByVolume.ini") "Settings" "PosY"
        
        if (px != "" and py != "") then
            createDialog ::ro_trimSplineByVolume pos:[px as float, py as float]
        else
            createDialog ::ro_trimSplineByVolume
    )
)

global trimSplineByVolume = trimSplineByVolume_v()
trimSplineByVolume.showUI()