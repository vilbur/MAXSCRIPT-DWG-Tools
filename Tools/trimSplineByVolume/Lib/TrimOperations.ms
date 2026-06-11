struct TrimOperations
(
    core = undefined,

    new_dummies = #(),

    current_selection,

    function getParentLayer lay_name =
        (
            for i = 0 to LayerManager.count - 1 do
            (
                local p = LayerManager.getLayer i
                if (p != undefined) do
                (
                    try (
                        for c = 1 to p.getNumChildren() do
                        (
                            local child = p.getChild c
                            if (child != undefined and child.name == lay_name) then return p
                        )
                    ) catch()
                )
            )
            return undefined
        ),

    function isTopLayer lay_name =
        (
            return ((getParentLayer lay_name) == undefined)
        ),

    function turnOnLayerChain lay_val =
        (
            if (lay_val != undefined) then
            (
                lay_val.on = true
                local p_lay = getParentLayer lay_val.name
                if (p_lay != undefined) then turnOnLayerChain p_lay
            )
        ),

    function unhideLayerHierarchy lay_val =
        (
            lay_val.on = true
            local l_nodes = #()
            lay_val.nodes &l_nodes
            for n in l_nodes where isValidNode n do n.isHidden = false
            try ( for c = 1 to lay_val.getNumChildren() do unhideLayerHierarchy (lay_val.getChild c) ) catch()
        ),

    function getVolumesInLayerTree lay_val =
        (
            local arr = #(), n_arr = #()
            lay_val.nodes &n_arr
            for n in n_arr where (core.isVolumeDummy n) do append arr n
            for i = 1 to lay_val.getNumChildren() do
            (
                local c_vols = getVolumesInLayerTree (lay_val.getChild i)
                for v in c_vols do append arr v
            )
            arr
        ),

    function collectAllNodesInLayerTree lay_val =
        (
            local arr = #(), n_arr = #()
            lay_val.nodes &n_arr
            for n in n_arr do append arr n
            for i = 1 to lay_val.getNumChildren() do
            (
                local c_nodes = collectAllNodesInLayerTree (lay_val.getChild i)
                for cn in c_nodes do append arr cn
            )
            arr
        ),

    function deleteAllNodesInLayerTree lay_val =
        (
            if (lay_val != undefined) then
            (
                local l_nodes = #()
                lay_val.nodes &l_nodes
                for n in l_nodes where isValidNode n do delete n
                for i = 1 to lay_val.getNumChildren() do deleteAllNodesInLayerTree (lay_val.getChild i)
            )
        ),

    function deleteLayerTree lay_val =
        (
            if (lay_val != undefined and lay_val.name != "0") then
            (
                for i = lay_val.getNumChildren() to 1 by -1 do deleteLayerTree (lay_val.getChild i)
                LayerManager.deleteLayerByName lay_val.name
            )
        ),

    function getOrCreateLayer orig_lay top_name o_names n_lays =
        (
            local idx = findItem o_names orig_lay.name
            if (idx > 0) then return n_lays[idx]

            local is_top = isTopLayer orig_lay.name
            local p_lay = getParentLayer orig_lay.name

            local n_name = if (is_top) then top_name else (top_name + " - " + orig_lay.name)

            local n_lay = LayerManager.getLayerFromName n_name
            if (n_lay == undefined) then n_lay = LayerManager.newLayerFromName n_name

            append o_names orig_lay.name; append n_lays n_lay

            if (p_lay != undefined) then
            (
                local n_p_lay = getOrCreateLayer p_lay top_name o_names n_lays
                n_lay.setParent n_p_lay
            )
            n_lay
        ),

    function recreateLayerTree o_nodes c_nodes top_name =
        (
            local o_names = #(), n_layers = #()
            for i = 1 to o_nodes.count do
            (
                local o_n = o_nodes[i], c_n = c_nodes[i]
                if (isValidNode c_n and isValidNode o_n) then
                (
                    c_n.name = o_n.name
                    local n_lay = getOrCreateLayer o_n.layer top_name o_names n_layers
                    n_lay.addNode c_n
                )
            )
        ),

    function compareDist a b =
        (
            if (a[5] < b[5]) then -1
            else if (a[5] > b[5]) then 1
            else 0
        ),

    function generateCanvasVolume =
        (
            undo "Generate Canvas" on
            (
                local exist = getNodeByName "TRIM_CANVAS"
                if (isValidNode exist) then delete exist
                local d_layer = LayerManager.getLayer 0
                if (d_layer != undefined) then d_layer.on = true
                core.openGroupsOfUnhiddenObjects ignore_frozen:true
                local s_data = #(), t_knots = 0
                for n in objects where (core.isSplineShapeNode n and n.name != "TRIM_CANVAS" and not isGroupHead n and not isGroupMember n and core.isNodeProcessable n ignore_frozen:true) do
                (
                    local bb = nodeGetBoundingBox n (matrix3 1)
                    local cent = (bb[1] + bb[2]) / 2.0
                    local dist = length cent
                    local k_count = 0
                    for sp = 1 to (numSplines n) do k_count += numKnots n sp
                    if (k_count > 0) then
                    (
                        append s_data #(n, bb[1], bb[2], cent, dist, k_count)
                        t_knots += k_count
                    )
                )
                local h_size = 500.0
                if (s_data.count > 0) then
                (
                    qsort s_data compareDist
                    local min_p = [1e9, 1e9, 1e9], max_p = [-1e9, -1e9, -1e9], a_knots = 0, t_target = t_knots * 0.90
                    for d in s_data do
                    (
                        a_knots += d[6]
                        if (d[2].x < min_p.x) then min_p.x = d[2].x
                        if (d[2].y < min_p.y) then min_p.y = d[2].y
                        if (d[3].x > max_p.x) then max_p.x = d[3].x
                        if (d[3].y > max_p.y) then max_p.y = d[3].y
                        if (a_knots >= t_target) then exit
                    )
                    local m_ext = amax (abs min_p.x) (abs min_p.y) (abs max_p.x) (abs max_p.y)
                    h_size = m_ext * 2.1
                    if (h_size <= 0) then h_size = 500.0
                )
                try (
                    local d = Dummy name:"TRIM_CANVAS" pos:[0,0,0] boxsize:[h_size, h_size, 0.0] wirecolor:(color 255 128 0)
                    if (d_layer != undefined) then d_layer.addNode d
                    select d; actionMan.executeAction 0 "311"
                ) catch ()
            )
        ),

    function trimCanvas quiet:false ignore_frz:true =
        (
            local c_node = getNodeByName "TRIM_CANVAS"
            if (c_node == undefined or not isValidNode c_node) then
            (
                if (not quiet) then messageBox "TRIM_CANVAS not found." title:"Trim Canvas"
                return undefined
            )
            core.openGroupsOfUnhiddenObjects ignore_frozen:ignore_frz
            local c_data = core.getVolumeBoundsData c_node
            local d_objs = for n in objects where (n != c_node and not isGroupHead n and core.isNodeProcessable n ignore_frozen:ignore_frz) collect n
            local d_count = 0
            undo "Trim Canvas" on
            (
                for n in d_objs do
                (
                    local o_bb = nodeGetBoundingBox n (matrix3 1)
                    local is_out = core.isWorldBBoxOutsideVolume2D o_bb c_data tol_val:0.001
                    if (is_out) then ( delete n; d_count += 1 )
                )
            )
            if (not quiet) then completeRedraw()
            if (not quiet) then messageBox ("Canvas Trim Complete.\nDeleted: " + d_count as string) title:"Trim Canvas"
        ),

    /* Get top visible parent layer below layer 0.
       Returns undefined for invalid layer input. */
    function getTopLayer layer_item =
    (
        if (layer_item != undefined) then
        (
            while ((layer_item.getParent()) != undefined and (layer_item.getParent()).name != "0") do
            (
                layer_item = layer_item.getParent()
            )
        )

        layer_item
        -- return
    ),

    /* Test if layer and parent layer chain are visible.
       Prevents creating volume helpers in hidden layers. */
    function isLayerChainVisible layer_item =
    (
        visible_result = false

        if (layer_item != undefined) then
        (
            visible_result = true
            check_layer = layer_item

            while (check_layer != undefined and visible_result) do
            (
                if (check_layer.on == false) then visible_result = false
                check_layer = check_layer.getParent()
            )
        )

        visible_result
        -- return
    ),

    /* Show hidden layer warning.
       Uses different text for current layer and selected-object layer. */
    function showHiddenLayerMessage layer_item from_current_layer:false =
    (
        layer_name = if (layer_item != undefined) then layer_item.name else "undefined"
        prefix_text = if from_current_layer then "Current layer is hidden." else "Target layer is hidden."

        messageBox (prefix_text + "\n\nVolume helper was not created.\n\nLayer:\n" + layer_name) title:"Generate Volume"
        false
        -- return
    ),

    /* Force volume data to 2D XY.
       Z size is zero because trim tests treat Z as infinite. */
    function makeSafe2DVolumeData size_val center_val =
    (
        local safe_size = [abs size_val.x, abs size_val.y, 0.0]
        local safe_center = [center_val.x, center_val.y, 0.0]
        local fallback_size = amax safe_size.x safe_size.y 1.0

        if (safe_size.x < 0.001) then safe_size.x = fallback_size
        if (safe_size.y < 0.001) then safe_size.y = fallback_size

        #(safe_size, safe_center)
        -- return
    ),

    /* Saturate RGB color to maximum display strength.
       Keeps hue from source layer color when possible. */
    function getSaturatedColor source_color =
    (
        local source_r = amax 0.0 (amin 255.0 source_color.r)
        local source_g = amax 0.0 (amin 255.0 source_color.g)
        local source_b = amax 0.0 (amin 255.0 source_color.b)
        local max_value = amax source_r source_g source_b
        local min_value = amin source_r source_g source_b
        local result_color = color 255 255 255

        if ((max_value - min_value) >= 0.001) then
        (
            local scale_value = 255.0 / (max_value - min_value)
            result_color = color ((source_r - min_value) * scale_value) ((source_g - min_value) * scale_value) ((source_b - min_value) * scale_value)
        )

        result_color
        -- return
    ),

    /* Get saturated color from layer wire color.
       Falls back safely when layer color is not readable. */
    function getLayerSaturatedColor layer_val =
    (
        local layer_color = color 255 255 255

        try
        (
            if (layer_val != undefined) then layer_color = layer_val.wireColor
        )
        catch
        (
            layer_color = color 255 255 255
        )

        getSaturatedColor layer_color
        -- return
    ),

    /* Get union bbox from nodes in XY only.
       Margin percent is applied to every XY side. */
    function getNodesBBoxData2D n_arr margin_percent:0.0 =
    (
        local min_p = [1e9, 1e9, 0.0]
        local max_p = [-1e9, -1e9, 0.0]
        local found_node = false

        for node_item in n_arr where (isValidNode node_item and node_item.name != "TRIM_CANVAS" and not (core.isVolumeDummy node_item) and not isGroupHead node_item) do
        (
            try
            (
                local node_box = nodeGetBoundingBox node_item (matrix3 1)

                min_p.x = amin min_p.x node_box[1].x
                min_p.y = amin min_p.y node_box[1].y
                max_p.x = amax max_p.x node_box[2].x
                max_p.y = amax max_p.y node_box[2].y

                found_node = true
            )
            catch
            (
            )
        )

        if (found_node) then
        (
            local base_size_x = max_p.x - min_p.x
            local base_size_y = max_p.y - min_p.y
            local safe_margin_percent = abs margin_percent
            local margin_x = base_size_x * safe_margin_percent
            local margin_y = base_size_y * safe_margin_percent

            min_p.x -= margin_x
            min_p.y -= margin_y
            max_p.x += margin_x
            max_p.y += margin_y

            local bbox_size = [max_p.x - min_p.x, max_p.y - min_p.y, 0.0]
            local bbox_center = [(min_p.x + max_p.x) / 2.0, (min_p.y + max_p.y) / 2.0, 0.0]

            makeSafe2DVolumeData bbox_size bbox_center
        )
        else
        (
            undefined
        )
        -- return
    ),

    function createVolumeFromNodes n_arr vol_name is_layer:false target_layer:undefined wirecolor:undefined use_bounds:false margin_percent:0.0 from_current_layer:false =
    (
        result = false

        if (target_layer == undefined) then target_layer = this._getTargetLayer()

        if (target_layer != undefined) then
        (
            if (not (isLayerChainVisible target_layer)) then
            (
                showHiddenLayerMessage target_layer from_current_layer:from_current_layer
                return false
            )

            local top_layer = getTopLayer target_layer
            local exist_dummy = getNodeByName target_layer.name
            if (isValidNode exist_dummy and core.isVolumeDummy exist_dummy) then delete exist_dummy

            if (vol_name != undefined) then
            (
                local exist_named_dummy = getNodeByName vol_name
                if (isValidNode exist_named_dummy and core.isVolumeDummy exist_named_dummy) then delete exist_named_dummy
            )

            local volume_bbox_data = undefined
            if (use_bounds) then
            (
                volume_bbox_data = getNodesBBoxData2D n_arr margin_percent:margin_percent
            )
            else
            (
                volume_bbox_data = this._geSizeAndPosOfDummy(n_arr)
                if (volume_bbox_data != undefined) then volume_bbox_data = makeSafe2DVolumeData (volume_bbox_data[1]) (volume_bbox_data[2])
            )

            if (volume_bbox_data != undefined) then
            (
                size = volume_bbox_data[1]
                cent = volume_bbox_data[2]

                if (wirecolor == undefined) then
                (
                    wirecolor = getLayerSaturatedColor top_layer
                )
                else
                (
                    wirecolor = getSaturatedColor wirecolor
                )

                if (vol_name == undefined) then vol_name = target_layer.name

                /* CREATE DUMMY */
                local d = VolumeHelper name:vol_name pos:cent size:1 wirecolor:wirecolor color:wirecolor
                d.pos.z = 0.0

                append new_dummies d

                /* SET DUMMY SCALE */
                d.scale = size
                d.scale.z = 0.0
                d.pos.z = 0.0
                d.wirecolor = wirecolor
                d.color = wirecolor

                target_layer.addNode d

                result = true
            )
        )

        result --return
    ),

	/** Is dummy selected
	 */
	function _isDummySelected obj = 
	(
		--format "\n"; print "TrimOperations._isDummySelected()"
		selection.count == 1  and core.isVolumeDummy obj
	),
		
    function generateSingleVolumeInCurrentLayer =
        (
            new_dummies = #()

            undo "Generate Current Layer Volume" on
            (
                obj = if (selection.count > 0) then selection[1] else undefined
                source_nodes = for node_item in selection where (isValidNode node_item and node_item.name != "TRIM_CANVAS" and not (core.isVolumeDummy node_item) and not isGroupHead node_item) collect node_item

                if (source_nodes.count > 0) then
                (
                    target_layer = source_nodes[1].layer

                    if (not (isLayerChainVisible target_layer)) then
                    (
                        showHiddenLayerMessage target_layer from_current_layer:false
                    )
                    else if (not (createVolumeFromNodes source_nodes "TRIM_SELECTION" is_layer:false target_layer:target_layer use_bounds:true margin_percent:0.10)) then
                    (
                        messageBox ("No valid selected objects found to calculate volume.\n\nIn layer:\n\n" + target_layer.name) title:"Generate Volumes"
                    )
                    else
                    (
                        format "Generated selection volume in layer: %\n" target_layer.name
                    )
                )
                else
                (
                    target_layer = this._getTargetLayer()

                    if (target_layer != undefined) then
                    (
                        if (not (isLayerChainVisible target_layer)) then
                        (
                            showHiddenLayerMessage target_layer from_current_layer:true
                        )
                        else
                        (
                            local a_nodes = collectAllNodesInLayerTree target_layer

                            /* GET NAME BY SELECTED DUMMY OR BY TOP LAYER */
                            vol_name = undefined
                            wirecolor = undefined
                            if (this._isDummySelected obj) then
                            (
                                vol_name = trimGetNextDummy obj.name
                                wirecolor = obj.wirecolor
                            )

                            if (not (createVolumeFromNodes a_nodes vol_name is_layer:true target_layer:target_layer wirecolor:wirecolor from_current_layer:true)) then
                                messageBox ("No valid objects found to calculate volume.\n\nIn layer:\n\n" + target_layer.name) title:"Generate Volumes"
                            else
                                format "GENERATED VOLUME FOR CURRENT LAYER: %\n" target_layer.name
                        )
                    )
                )

                if new_dummies.count > 0 then select     new_dummies
            )
        ),

    --    function getTopLayer lay_val =
    --    (
    --        local p_lay = undefined
    --        try ( p_lay = lay_val.getParent() ) catch()
    --        if (p_lay != undefined) then return getTopLayer p_lay
    --        return lay_val
    --    ),

    function generateVolumes =
        (

            new_dummies = #()

            undo "Generate Volumes" on
            (
                current_selection = selection as Array

                local s_nodes = for n in selection where (isValidNode n and n.name != "TRIM_CANVAS" and not (core.isVolumeDummy n) and not isGroupHead n) collect n
                if (s_nodes.count > 0) then
                (
                    local t_lay = s_nodes[1].layer
                    if (not (isLayerChainVisible t_lay)) then
                    (
                        showHiddenLayerMessage t_lay from_current_layer:false
                    )
                    else if (createVolumeFromNodes s_nodes "TRIM_SELECTION" is_layer:false target_layer:t_lay use_bounds:true margin_percent:0.10) then
                    (
                        local d = getNodeByName "TRIM_SELECTION"
                        if (isValidNode d) then select d
                        messageBox "Generated single volume for selected objects." title:"Generate Volumes"
                    )
                    else
                    (
                        messageBox ("No valid selected objects found to calculate volume.\n\nIn layer:\n\n" + t_lay.name) title:"Generate Volumes"
                    )
                )
                else
                (
                    local g_count = 0
                    for i = 0 to LayerManager.count - 1 do
                    (
                        local lay = LayerManager.getLayer i
                        if (lay.on and lay.name != "0") then
                        (
                            local is_top = true
                            try ( if (lay.getParent() != undefined) then is_top = false ) catch()
                            if (is_top) then
                            (
                                local ex_vols = getVolumesInLayerTree lay
                                if (ex_vols.count == 0) then
                                (
                                    local a_nodes = collectAllNodesInLayerTree lay
                                    if (createVolumeFromNodes a_nodes lay.name is_layer:true target_layer:lay) then g_count += 1
                                )
                            )
                        )
                    )
                    messageBox ("Generated " + g_count as string + " volume helpers.") title:"Generate Volumes"
                )

                if new_dummies.count > 0 then select     new_dummies
            )
        ),

    function runMassMode quiet:false tol_val:0.001 del_empty:true ignore_frz:true =
        (
            local t_lays = #()
            for i = 0 to LayerManager.count - 1 do
            (
                local lay = LayerManager.getLayer i
                if (lay.name != "0" and findString lay.name "_TO_DELETE_" == undefined and isTopLayer lay.name) then append t_lays lay
            )

            local t_p = 0, t_dk = 0, a_vols = #()

            for t_lay in t_lays do
            (
                local v_arr = getVolumesInLayerTree t_lay
                if (v_arr.count == 1) then
                (
                    local v_n = v_arr[1]; append a_vols v_n
                    if (not quiet) then (format "\rMass Mode: '%'..." v_n.name; windows.processPostedMessages())
                    for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                    turnOnLayerChain t_lay; unhideLayerHierarchy t_lay
                    local res = core.run v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz
                    if (res != undefined) then ( t_p += res[1]; t_dk += res[3] )
                )
                else if (v_arr.count > 1) then
                (
                    local o_n = t_lay.name
                    t_lay.setname (o_n + "_TO_DELETE_" + (timestamp() as string))
                    local a_nodes = collectAllNodesInLayerTree t_lay
                    local c_nodes = for n in a_nodes where (findItem v_arr n == 0) collect n

                    for v_idx = 1 to v_arr.count do
                    (
                        local v_n = v_arr[v_idx]; append a_vols v_n
                        if (not quiet) then (format "\rMass Mode: '%'..." v_n.name; windows.processPostedMessages())

                        local top_name = v_n.name

                        local c_out = #()
                        if (c_nodes.count > 0) then
                        (
                            maxOps.cloneNodes c_nodes cloneType:#copy newNodes:&c_out
                            recreateLayerTree c_nodes c_out top_name
                        )

                        local dummy_layer = LayerManager.getLayerFromName top_name
                        if (dummy_layer == undefined) then dummy_layer = LayerManager.newLayerFromName top_name
                        dummy_layer.addNode v_n

                        for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                        turnOnLayerChain dummy_layer; unhideLayerHierarchy dummy_layer
                        local res = core.run v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz
                        if (res != undefined) then ( t_p += res[1]; t_dk += res[3] )
                    )
                    deleteAllNodesInLayerTree t_lay; (LayerManager.getLayer 0).current = true; deleteLayerTree t_lay
                )
            )
            for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = true
            undo "Delete Mass Volumes" on ( for v in a_vols where isValidNode v do delete v )
            if (not quiet) then format "\n"
            completeRedraw()
            if (not quiet) then messageBox ("Mass Mode Complete\nProcessed Splines: " + t_p as string + "\nKnots Deleted: " + t_dk as string) title:"Mass Mode"
        ),

    /** Ge size and posof dummy
         */
        function _geSizeAndPosOfDummy n_arr =
        (
            --format "\n"; print "TrimOperations._geSizeAndPosofDummy()"
            fn getVolumeHelpers objs = for n in objs where (isValidNode n and not (core.isVolumeDummy n) and not isGroupHead n) collect n

            /* Get bbox size of single node.
               Returns Point3 size in world coordinates. */
            function getNodeBBoxSize node_item =
            (
                node_box = nodeGetBoundingBox node_item (matrix3 1)
                bbox_size = node_box[2] - node_box[1]

                [abs bbox_size.x, abs bbox_size.y, abs bbox_size.z]
                -- return
            )

            if (selection.count == 1 and isValidNode selection[1]) then
            (
                single_size = getNodeBBoxSize selection[1]
                single_center = selection[1].pos + [5, 5, 0]
                single_center.z = 0.0
                single_size.z = 0.0

                #(single_size, single_center)
            )
            else
            (
                bboxDataTools = bboxDataTools_v()
                volume_helpers_all = getVolumeHelpers helpers

                get_average_size_of = case of
                (
                    /* GET SIZE BY SELECTION */
                    (selection.count > 0): selection as Array

                    /* GET SIZE BY EXISITNG HELPERS */
                    (volume_helpers_all.count > 0): volume_helpers_all

                    /* ALL NODES IN LAYERS */
                    default: n_arr
                )

                bbox_data = bboxDataTools.getAverageBBoxData get_average_size_of

                /* AVERAGE SIZE OF XY */
                bbox_data[1].x = bbox_data[1].y = (bbox_data[1].x + bbox_data[1].y) / 2
                bbox_data[1].z = 0.0
                bbox_data[2].z = 0.0

                bbox_data --return
            )
        ),

    /** Get target layer
         */
        function _getTargetLayer =
        (
            --format "\n"; print "TrimOperations._getTargetLayer()"

            if (selection.count > 0 and isValidNode selection[1]) then
            (
                selection[1].layer
            )
            else
            (
                LayerManager.current
            )
            -- return
        ),

    on create do
    (
    )
)

