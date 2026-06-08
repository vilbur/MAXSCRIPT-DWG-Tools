fn sortShapeDataBySize a b = (
    if a[2] < b[2] then return 1
    if a[2] > b[2] then return -1
    return 0
)

struct SplineToObjConvertor (
    z_tolerance = 10.0,
    xy_tolerance = 0.01,
    prog_bar = undefined,
    lbl_status = undefined,
    prefix = "",
    
    fn updateProgress val msg = (
        if this.prog_bar != undefined then (
            this.prog_bar.value = val
        )
        if this.lbl_status != undefined then (
            this.lbl_status.text = this.prefix + msg
        )
        windows.processPostedMessages()
    ),
    
    fn extractSplines source_shape = (
        local extracted_shapes = #()
        local num_splines = numSplines source_shape
        
        for i = 1 to num_splines do (
            local new_shape = copy source_shape
            convertToSplineShape new_shape
            
            for j = num_splines to 1 by -1 do (
                if j != i then (
                    deleteSpline new_shape j
                )
            )
            updateShape new_shape
            append extracted_shapes new_shape
            
            local prog_val = (i as float / num_splines) * 100.0
            local prog_msg = "Extracting splines: " + (i as string) + " / " + (num_splines as string)
            this.updateProgress prog_val prog_msg
        )
        return extracted_shapes
    ),
    
    fn groupAndMerge extracted_shapes = (
        local shape_data = #()
        local num_extracted = extracted_shapes.count
        
        for i = 1 to num_extracted do (
            local s = extracted_shapes[i]
            centerPivot s
            
            local l_bounds = nodeLocalBoundingBox s
            local dims = l_bounds[2] - l_bounds[1]
            local diag_len = length dims
            
            append shape_data #(s, diag_len, l_bounds[1], l_bounds[2], inverse s.transform)
            
            local prog_val = (i as float / num_extracted) * 100.0
            local prog_msg = "Analyzing bounds: " + (i as string) + " / " + (num_extracted as string)
            this.updateProgress prog_val prog_msg
        )
        
        -- Sort largest to smallest
        qsort shape_data sortShapeDataBySize
        
        local groups = #()
        local processed_indices = #()
        local total_shapes = shape_data.count
        
        for i = 1 to total_shapes do (
            local prog_val = (i as float / total_shapes) * 100.0
            local prog_msg = "Grouping shapes: " + (i as string) + " / " + (total_shapes as string)
            this.updateProgress prog_val prog_msg

            if (findItem processed_indices i) == 0 then (
                local current_group = #(shape_data[i][1])
                local parent_min = shape_data[i][3]
                local parent_max = shape_data[i][4]
                local parent_inv_tm = shape_data[i][5]
                
                append processed_indices i
                
                for j = i + 1 to total_shapes do (
                    if (findItem processed_indices j) == 0 then (
                        local child_pos = shape_data[j][1].pos
                        local local_p = child_pos * parent_inv_tm
                        
                        local in_x = false
                        if local_p.x >= (parent_min.x - xy_tolerance) and local_p.x <= (parent_max.x + xy_tolerance) then ( in_x = true )
                        
                        local in_y = false
                        if local_p.y >= (parent_min.y - xy_tolerance) and local_p.y <= (parent_max.y + xy_tolerance) then ( in_y = true )
                        
                        local in_z = false
                        if local_p.z >= (parent_min.z - z_tolerance) and local_p.z <= (parent_max.z + z_tolerance) then ( in_z = true )
                        
                        if in_x and in_y and in_z then (
                            append current_group shape_data[j][1]
                            append processed_indices j
                        )
                    )
                )
                append groups current_group
            )
        )
        
        local final_merged_shapes = #()
        local num_groups = groups.count
        
        for g = 1 to num_groups do (
            local base_shape = groups[g][1]
            if groups[g].count > 1 then (
                for s = 2 to groups[g].count do (
                    addAndWeld base_shape groups[g][s] 0.0
                )
            )
            updateShape base_shape
            base_shape.name = uniqueName "Reinstated_Window_"
            append final_merged_shapes base_shape
            
            local prog_val = (g as float / num_groups) * 100.0
            local prog_msg = "Merging groups: " + (g as string) + " / " + (num_groups as string)
            this.updateProgress prog_val prog_msg
        )
        
        return final_merged_shapes
    ),
    
    fn processShape source_shape = (
        if (classOf source_shape == SplineShape or classOf source_shape == line) then (
            local extracted = this.extractSplines source_shape
            local merged = this.groupAndMerge extracted
            return merged
        ) else (
            print "Selected object is not a valid spline shape."
            return undefined
        )
    )
)

struct SplineInstancer (
    dim_tolerance = 0.05,
    prog_bar = undefined,
    lbl_status = undefined,
    prefix = "",
    
    fn updateProgress val msg = (
        if this.prog_bar != undefined then (
            this.prog_bar.value = val
        )
        if this.lbl_status != undefined then (
            this.lbl_status.text = this.prefix + msg
        )
        windows.processPostedMessages()
    ),

    fn getDimensions target_shape = (
        local local_bounds = nodeLocalBoundingBox target_shape
        local s_min = local_bounds[1]
        local s_max = local_bounds[2]
        return (s_max - s_min)
    ),

    fn reinstanceShapes merged_shapes = (
        if merged_shapes == undefined then (
            print "Error: Input shapes array is undefined. Aborting instancing."
            return #()
        )

        local master_shapes = #()
        local instanced_results = #()
        local num_shapes = merged_shapes.count

        for i = 1 to num_shapes do (
            local prog_val = (i as float / num_shapes) * 100.0
            local prog_msg = "Instancing shapes: " + (i as string) + " / " + (num_shapes as string)
            this.updateProgress prog_val prog_msg
            
            local current_shape = merged_shapes[i]
            
            centerPivot current_shape

            local current_dim = this.getDimensions current_shape
            local found_master = undefined

            for m = 1 to master_shapes.count do (
                local master = master_shapes[m]
                local master_dim = this.getDimensions master

                local x_match = false
                if (abs (current_dim.x - master_dim.x) <= dim_tolerance) then ( 
                    x_match = true 
                )

                local y_match = false
                if (abs (current_dim.y - master_dim.y) <= dim_tolerance) then ( 
                    y_match = true 
                )

                local z_match = false
                if (abs (current_dim.z - master_dim.z) <= dim_tolerance) then ( 
                    z_match = true 
                )

                if (x_match and y_match and z_match) then (
                    found_master = master
                    exit
                )
            )

            if found_master != undefined then (
                local new_instance = instance found_master
                
                new_instance.transform = current_shape.transform
                new_instance.name = uniqueName (found_master.name + "_Instance_")
                new_instance.wirecolor = found_master.wirecolor

                delete current_shape
                append instanced_results new_instance
            ) else (
                append master_shapes current_shape
                append instanced_results current_shape
            )
        )

        return instanced_results
    )
)

-- UI Setup and Execution
try (destroyDialog spline_obj_rollout) catch()

rollout spline_obj_rollout "Spline Convertor" width:200 (
    local ini_file = (getDir #plugcfg) + @"\spline_to_obj_settings.ini"
    local original_shapes = #()
    local splitted_shapes = #()
    
    -- UI Controls
    label lbl_sel_count "Selected: 0" color:(color 0 255 0) align:#left offset:[0,5]
    
    spinner spn_depth_threshold "Threshold (Units): " range:[0.0, 1000.0, 10.0] type:#float align:#left width:145 across:2 offset:[0,5]
    button btn_load_depth "L" width:20 height:20 align:#right tooltip:"Load min depth from selection bounds" offset:[0,3]
    
    checkbox chk_weld_before "Weld before splitting" checked:true align:#left offset:[0,5]
    checkbox chk_corner_knots "Make corner knots" checked:true align:#left
    
    button btn_execute "Execute Convertor" width:180 height:30 align:#center offset:[0,10]
    
    label lbl_status "Status: Idle" align:#left offset:[0,5] width:180
    progressbar pb_progress color:(color 0 255 0) height:10 width:180 align:#center offset:[0,5]
    
    group "Select Sets (LMB: Sel | RMB: Isolate)" (
        button btn_sel_original "Original" width:160 height:25 align:#center
        button btn_sel_splitted "Splitted" width:160 height:25 align:#center
    )
    
    timer tck_update interval:200 active:true
    
    -- Functions
    fn saveSettings = (
        setINISetting ini_file "Settings" "depth_threshold" (spn_depth_threshold.value as string)
        setINISetting ini_file "Settings" "weld_before" (chk_weld_before.checked as string)
        setINISetting ini_file "Settings" "corner_knots" (chk_corner_knots.checked as string)
    )
    
    fn loadSettings = (
        local val
        val = getINISetting ini_file "Settings" "depth_threshold"
        if val != "" then ( spn_depth_threshold.value = val as float )
        
        val = getINISetting ini_file "Settings" "weld_before"
        if val != "" then ( chk_weld_before.checked = (val == "true") )
        
        val = getINISetting ini_file "Settings" "corner_knots"
        if val != "" then ( chk_corner_knots.checked = (val == "true") )
    )
    
    fn makeCornerKnots target_shape = (
        for s = 1 to (numSplines target_shape) do (
            for k = 1 to (numKnots target_shape s) do (
                setKnotType target_shape s k #corner
            )
            for seg = 1 to (numSegments target_shape s) do (
                setSegmentType target_shape s seg #line
            )
        )
        updateShape target_shape
    )
    
    fn weldSplineKnots target_shape = (
        local old_mode = getCommandPanelTaskMode()
        
        setCommandPanelTaskMode #modify
        select target_shape
        subObjectLevel = 1
        max select all
        splineOps.weld target_shape
        subObjectLevel = 0
        
        setCommandPanelTaskMode old_mode
    )
    
    fn handleSelection target_array isolate_mode = (
        local valid_nodes = #()
        
        for obj in target_array do (
            if isValidNode obj then (
                append valid_nodes obj
            )
        )
        
        if valid_nodes.count > 0 then (
            clearSelection()
            select valid_nodes
            
            if isolate_mode then (
                IsolateSelection.EnterIsolateSelectionMode()
            )
        ) else (
            print "No valid objects in this set."
        )
    )
    
    -- Event Handlers
    on spline_obj_rollout open do (
        loadSettings()
    )
    
    on spline_obj_rollout close do (
        saveSettings()
    )
    
    on tck_update tick do (
        lbl_sel_count.text = "Selected: " + (selection.count as string)
    )
    
    on btn_load_depth pressed do (
        local max_depth = 0.0
        
        if selection.count > 0 then (
            for obj in selection do (
                local local_bounds = nodeLocalBoundingBox obj
                local s_min = local_bounds[1]
                local s_max = local_bounds[2]
                
                local dim_x = abs (s_max.x - s_min.x)
                local dim_y = abs (s_max.y - s_min.y)
                local dim_z = abs (s_max.z - s_min.z)
                
                local current_depth = amin #(dim_x, dim_y, dim_z)
                
                if current_depth > max_depth then (
                    max_depth = current_depth
                )
            )
            
            if max_depth > 0.0 then (
                spn_depth_threshold.value = max_depth
            ) else (
                spn_depth_threshold.value = 10.0
            )
        ) else (
            print "Please select shapes to calculate the bounding box depth."
        )
    )
    
    on btn_sel_original pressed do (
        handleSelection original_shapes false
    )
    
    on btn_sel_original rightclick do (
        handleSelection original_shapes true
    )
    
    on btn_sel_splitted pressed do (
        handleSelection splitted_shapes false
    )
    
    on btn_sel_splitted rightclick do (
        handleSelection splitted_shapes true
    )
    
    on btn_execute pressed do (
        if selection.count == 0 then (
            print "Please select shapes to process."
            return false
        )
        
        original_shapes = #()
        splitted_shapes = #()
        
        for obj in selection do (
            append original_shapes obj
        )
        
        for i = 1 to original_shapes.count do (
            local source_shape = original_shapes[i]
            local shape_prefix = "[Shape " + (i as string) + "/" + (original_shapes.count as string) + "] "
            
            lbl_status.text = shape_prefix + "Preparing..."
            pb_progress.value = 0
            windows.processPostedMessages()
            
            local working_copy = copy source_shape
            convertToSplineShape working_copy
            
            if chk_weld_before.checked then (
                weldSplineKnots working_copy
            )
            
            if chk_corner_knots.checked then (
                makeCornerKnots working_copy
            )
            
            local window_manager = SplineToObjConvertor z_tolerance:spn_depth_threshold.value prog_bar:pb_progress lbl_status:lbl_status prefix:shape_prefix
            local final_merged_shapes = window_manager.processShape working_copy
            
            if final_merged_shapes != undefined then (
                local instancer = SplineInstancer dim_tolerance:0.1 prog_bar:pb_progress lbl_status:lbl_status prefix:shape_prefix
                local reinstanced_windows = instancer.reinstanceShapes final_merged_shapes
                
                for rw in reinstanced_windows do (
                    append splitted_shapes rw
                )
            )
            
            if isValidNode working_copy then (
                delete working_copy
            )
        )
        
        lbl_status.text = "Extraction Complete."
        pb_progress.value = 100
        print "Extraction and Reinstatement Complete."
    )
)

createDialog spline_obj_rollout
