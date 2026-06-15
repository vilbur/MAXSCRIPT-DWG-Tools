struct TrimOperations
(
    core = undefined,

    new_dummies = #(),

    new_layers = #(),

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

    /* Make a newly created layer visible.
       Existing layer visibility is not changed by creation helpers. */
    function makeNewLayerVisible layer_item =
    (
        if (layer_item != undefined) then
        (
            try (layer_item.on = true) catch()
            appendIfUnique new_layers layer_item
        )

        layer_item
        -- return
    ),

    /* Keep every layer created by this tool visible after processing.
       Existing layer visibility states are restored separately. */
    function turnOnNewLayers =
    (
        for layer_item in new_layers where (layer_item != undefined) do
        (
            try (layer_item.on = true) catch()
        )

        true
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

    /* Test if volume helper is in a visible layer chain.
       Hidden-layer dummies are ignored by single trim, mass trim, and duplicate preflight. */
    function isVolumeDummyInVisibleLayer node_item =
    (
        (isValidNode node_item and core.isVolumeDummy node_item and node_item.layer != undefined and isLayerChainVisible node_item.layer)
        -- return
    ),

    function getVolumesInLayerTree lay_val visible_layers_only:true =
        (
            local arr = #(), n_arr = #()

            if (lay_val != undefined and ((visible_layers_only == false) or isLayerChainVisible lay_val)) then
            (
                lay_val.nodes &n_arr
                for n in n_arr where (core.isVolumeDummy n and ((visible_layers_only == false) or isVolumeDummyInVisibleLayer n)) do append arr n

                for i = 1 to lay_val.getNumChildren() do
                (
                    local c_lay = lay_val.getChild i
                    if ((visible_layers_only == false) or isLayerChainVisible c_lay) then
                    (
                        local c_vols = getVolumesInLayerTree c_lay visible_layers_only:visible_layers_only
                        for v in c_vols do append arr v
                    )
                )
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

    /* Get original top-layer name without using later struct methods.
       Used before recreated child layers are renamed. */
    function getTopLayerNameFromLayer layer_item =
        (
            local result_name = ""
            local current_layer = layer_item

            if (current_layer != undefined) then
            (
                result_name = current_layer.name

                while (getParentLayer current_layer.name != undefined) do
                (
                    current_layer = getParentLayer current_layer.name
                    result_name = current_layer.name
                )
            )

            result_name
            -- return
        ),

    /* Remove original top-layer prefix from source child-layer names.
       Example: Source_A > Source_A - hrany becomes Target_D > Target_D - hrany. */
    function getLayerNameWithoutSourceTopPrefix layer_name source_top_name =
        (
            local result_name = layer_name

            if (layer_name != undefined and source_top_name != undefined and source_top_name != "") then
            (
                local prefix_text = source_top_name + " - "

                if (findString layer_name prefix_text == 1) then
                (
                    result_name = substring layer_name (prefix_text.count + 1) (layer_name.count - prefix_text.count)
                )
            )

            result_name
            -- return
        ),

    function getOrCreateLayer orig_lay top_name o_names n_lays =
        (
            local idx = findItem o_names orig_lay.name
            if (idx > 0) then return n_lays[idx]

            local is_top = isTopLayer orig_lay.name
            local p_lay = getParentLayer orig_lay.name
            local source_top_name = getTopLayerNameFromLayer orig_lay
            local child_name = getLayerNameWithoutSourceTopPrefix orig_lay.name source_top_name

            local n_name = if (is_top) then top_name else (top_name + " - " + child_name)

            local n_lay = LayerManager.getLayerFromName n_name
            if (n_lay == undefined) then
            (
                n_lay = LayerManager.newLayerFromName n_name
                makeNewLayerVisible n_lay
            )

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

    /* Get top layer of first visible scene object.
       Used when the current layer is hidden during no-selection volume creation. */
    function getFirstVisibleObjectTopLayer =
    (
        local visible_top_layer = undefined

        for node_item in objects where (visible_top_layer == undefined and isValidNode node_item and not isGroupHead node_item and not (core.isVolumeDummy node_item) and node_item.name != "TRIM_CANVAS" and node_item.isHidden == false and node_item.layer != undefined and isLayerChainVisible node_item.layer) do
        (
            visible_top_layer = getTopLayer node_item.layer
            if (visible_top_layer == undefined) then visible_top_layer = node_item.layer
        )

        visible_top_layer
        -- return
    ),

    /* Set current layer to top layer of first visible object.
       Returns undefined if no visible object layer can be found. */
    function setCurrentLayerToFirstVisibleObjectTopLayer =
    (
        local visible_top_layer = getFirstVisibleObjectTopLayer()

        if (visible_top_layer != undefined) then
        (
            try (visible_top_layer.current = true) catch()
        )

        visible_top_layer
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

        for node_item in n_arr where (isValidNode node_item and node_item.name != "TRIM_CANVAS" and classOf node_item != VolumeHelper and not isGroupHead node_item) do
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

    /* Test if numeric value is safe for volume size/position.
       Prevents runaway helpers from bad viewport ray intersections. */
    function isSafeViewportNumber number_value max_abs:10000000.0 =
    (
        local result_value = false

        try
        (
            result_value = (number_value > -max_abs and number_value < max_abs)
        )
        catch
        (
            result_value = false
        )

        result_value
        -- return
    ),

    /* Test if viewport volume data has usable XY dimensions.
       Rejects huge values like 100000000.0 before helper creation. */
    function isSafeViewVolumeData volume_data max_abs:10000000.0 =
    (
        local result_value = false

        if (volume_data != undefined and volume_data.count >= 2) then
        (
            local size_value = volume_data[1]
            local center_value = volume_data[2]

            result_value = (
                isSafeViewportNumber size_value.x max_abs:max_abs and
                isSafeViewportNumber size_value.y max_abs:max_abs and
                isSafeViewportNumber center_value.x max_abs:max_abs and
                isSafeViewportNumber center_value.y max_abs:max_abs and
                size_value.x > 0.001 and
                size_value.y > 0.001
            )
        )

        result_value
        -- return
    ),

    /* Scale XY size of 2D volume data around same center.
       Used to create viewport helpers smaller than the full visible view. */
    function scale2DVolumeData volume_data size_factor:1.0 =
    (
        local result_data = volume_data

        if (volume_data != undefined and volume_data.count >= 2) then
        (
            local size_value = volume_data[1]
            local center_value = volume_data[2]
            local safe_factor = amax 0.001 size_factor

            result_data = makeSafe2DVolumeData [size_value.x * safe_factor, size_value.y * safe_factor, 0.0] center_value
        )

        result_data
        -- return
    ),

    /* Get active viewport size safely.
       Falls back to graphics window size when getViewSize is unavailable. */
    function getSafeViewportPixelSize =
    (
        local view_size = undefined

        try
        (
            view_size = getViewSize()
        )
        catch
        (
            view_size = undefined
        )

        if (view_size == undefined or view_size.x <= 0 or view_size.y <= 0) then
        (
            try
            (
                view_size = gw.getWinSize()
            )
            catch
            (
                view_size = [1000, 1000]
            )
        )

        view_size
        -- return
    ),

    /* Get world point on construction plane from screen pixel.
       Uses native viewport mapping, not manual ray-to-Z intersection. */
    function getScreenPointOnConstructionPlane screen_point view_size =
    (
        local world_point = undefined

        try
        (
            world_point = gw.getPointOnCP screen_point
        )
        catch
        (
            world_point = undefined
        )

        if (world_point == undefined) then
        (
            try
            (
                world_point = mapScreenToCP screen_point view_size
            )
            catch
            (
                world_point = undefined
            )
        )

        world_point
        -- return
    ),

    /* Build current-view XY bounds from construction plane corner points.
       This is the restored no-selection behavior: volume fits 80% of active view. */
    function getCurrentViewCPBBoxData2D view_size =
    (
        local result_data = undefined
        local screen_points = #(
            [0, 0],
            [view_size.x, 0],
            [view_size.x, view_size.y],
            [0, view_size.y]
        )
        local min_p = [1e9, 1e9, 0.0]
        local max_p = [-1e9, -1e9, 0.0]
        local point_count = 0

        for screen_point in screen_points do
        (
            local world_point = getScreenPointOnConstructionPlane screen_point view_size

            if (world_point != undefined and isSafeViewportNumber world_point.x and isSafeViewportNumber world_point.y) then
            (
                min_p.x = amin min_p.x world_point.x
                min_p.y = amin min_p.y world_point.y
                max_p.x = amax max_p.x world_point.x
                max_p.y = amax max_p.y world_point.y
                point_count += 1
            )
        )

        if (point_count >= 2) then
        (
            result_data = makeSafe2DVolumeData [max_p.x - min_p.x, max_p.y - min_p.y, 0.0] [(min_p.x + max_p.x) / 2.0, (min_p.y + max_p.y) / 2.0, 0.0]
        )

        if (not (isSafeViewVolumeData result_data)) then result_data = undefined

        result_data
        -- return
    ),

    /* Build finite current-view fallback data.
       Uses viewport world width and pixel aspect when CP corners are invalid. */
    function getCurrentViewFiniteFallbackData2D view_size =
    (
        local width_value = 500.0
        local height_value = 500.0
        local center_value = [0.0, 0.0, 0.0]

        try
        (
            local test_width = gw.getVPWorldWidth [0.0, 0.0, 0.0]
            if (test_width > 0.001 and test_width < 10000000.0) then width_value = test_width
        )
        catch
        (
            width_value = 500.0
        )

        try
        (
            if (view_size.x > 0) then height_value = width_value * ((view_size.y as float) / (view_size.x as float))
        )
        catch
        (
            height_value = width_value
        )

        try
        (
            local mid_point = [view_size.x / 2.0, view_size.y / 2.0]
            local center_point = getScreenPointOnConstructionPlane mid_point view_size

            if (center_point != undefined and isSafeViewportNumber center_point.x and isSafeViewportNumber center_point.y) then
            (
                center_value = [center_point.x, center_point.y, 0.0]
            )
        )
        catch
        (
            center_value = [0.0, 0.0, 0.0]
        )

        makeSafe2DVolumeData [width_value, height_value, 0.0] center_value
        -- return
    ),

    /* Get XY volume data from current viewport.
       No scene/layer bbox is used when nothing is selected. */
    function getCurrentViewBBoxData2D size_factor:0.80 =
    (
        local view_size = getSafeViewportPixelSize()
        local result_data = getCurrentViewCPBBoxData2D view_size

        if (result_data == undefined) then
        (
            result_data = getCurrentViewFiniteFallbackData2D view_size
        )

        if (not (isSafeViewVolumeData result_data)) then
        (
            result_data = makeSafe2DVolumeData [500.0, 500.0, 0.0] [0.0, 0.0, 0.0]
        )

        result_data = scale2DVolumeData result_data size_factor:size_factor

        result_data
        -- return
    ),



    /* Delete old selection helper from earlier versions.
       New generated volume helpers use top layer name instead. */
    function deleteLegacySelectionVolume =
    (
        local legacy_node = getNodeByName "TRIM_SELECTION"

        if (isValidNode legacy_node and classOf legacy_node == VolumeHelper) then
        (
            try (delete legacy_node) catch()
        )

        true
        -- return
    ),

    /* Create no-selection volume from current viewport.
       Uses 80% of viewport size and prevents huge scale values. */
    function createVolumeFromCurrentView vol_name target_layer:undefined wirecolor:undefined from_current_layer:true =
    (
        local result_value = false

        if (target_layer == undefined) then target_layer = this._getTargetLayer()

        if (target_layer != undefined) then
        (
            if (not (isLayerChainVisible target_layer)) then
            (
                if (from_current_layer) then
                (
                    target_layer = setCurrentLayerToFirstVisibleObjectTopLayer()

                    if (target_layer == undefined) then
                    (
                        messageBox "Current layer is hidden and no visible object layer was found." title:"Generate Volume"
                        return false
                    )
                )
                else
                (
                    showHiddenLayerMessage target_layer from_current_layer:from_current_layer
                    return false
                )
            )

            deleteLegacySelectionVolume()

            local top_layer = getTopLayer target_layer
            local volume_layer = if (top_layer != undefined) then top_layer else target_layer
            local volume_bbox_data = getCurrentViewBBoxData2D()

            if (volume_bbox_data != undefined) then
            (
                local size = volume_bbox_data[1]
                local cent = volume_bbox_data[2]

                if (wirecolor == undefined) then
                (
                    wirecolor = getLayerSaturatedColor volume_layer
                )
                else
                (
                    wirecolor = getSaturatedColor wirecolor
                )

                if (vol_name == undefined) then vol_name = volume_layer.name

                local exist_named_dummy = getNodeByName vol_name
                if (isValidNode exist_named_dummy and core.isVolumeDummy exist_named_dummy) then delete exist_named_dummy

                local d = VolumeHelper name:vol_name pos:cent size:1 wirecolor:wirecolor color:wirecolor
                d.pos.z = 0.0
                d.scale = size
                d.scale.z = 0.0
                d.wirecolor = wirecolor
                d.color = wirecolor

                volume_layer.addNode d
                append new_dummies d

                result_value = true
            )
        )

        result_value
        -- return
    ),

    /* Test if node is below selected group head.
       Used to replace selected group heads with real member nodes. */
    function isNodeUnderGroupHead node_item group_head =
    (
        local found_result = false

        if (isValidNode node_item and isValidNode group_head) then
        (
            local parent_item = node_item.parent

            while (parent_item != undefined and found_result == false) do
            (
                if (parent_item == group_head) then
                (
                    found_result = true
                )

                parent_item = parent_item.parent
            )
        )

        found_result
        -- return
    ),

    /* Collect non-head members below selected group head.
       Nested group heads are skipped, but their real children are included. */
    function collectGroupHeadMemberNodes group_head =
    (
        local member_nodes = #()

        if (isValidNode group_head and isGroupHead group_head) then
        (
            for node_item in objects where (isValidNode node_item and node_item != group_head and not isGroupHead node_item) do
            (
                if (isNodeUnderGroupHead node_item group_head) then appendIfUnique member_nodes node_item
            )
        )

        member_nodes
        -- return
    ),

    /* Validate node for volume generation.
       Volume helper, trim canvas, and group heads are never source geometry. */
    function isVolumeSourceNode node_item =
    (
        (isValidNode node_item and node_item.name != "TRIM_CANVAS" and classOf node_item != VolumeHelper and not isGroupHead node_item)
        -- return
    ),

    /* Collect selected nodes for volume generation.
       Selected group heads are ignored and replaced by their member objects. */
    function collectSelectionVolumeSourceNodes =
    (
        local source_nodes = #()

        for node_item in selection where isValidNode node_item do
        (
            if (isGroupHead node_item) then
            (
                local member_nodes = collectGroupHeadMemberNodes node_item

                for member_item in member_nodes where (isVolumeSourceNode member_item) do appendIfUnique source_nodes member_item
            )
            else if (isVolumeSourceNode node_item) then
            (
                appendIfUnique source_nodes node_item
            )
        )

        source_nodes
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

            deleteLegacySelectionVolume()

            local top_layer = getTopLayer target_layer
            local volume_layer = if (top_layer != undefined) then top_layer else target_layer
            local volume_name = if (vol_name != undefined) then vol_name else volume_layer.name
            local exist_dummy = getNodeByName volume_name
            if (isValidNode exist_dummy and core.isVolumeDummy exist_dummy) then delete exist_dummy

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
                    wirecolor = getLayerSaturatedColor volume_layer
                )
                else
                (
                    wirecolor = getSaturatedColor wirecolor
                )

                /* CREATE DUMMY */
                local d = VolumeHelper name:volume_name pos:cent size:1 wirecolor:wirecolor color:wirecolor
                d.pos.z = 0.0

                append new_dummies d

                /* SET DUMMY SCALE */
                d.scale = size
                d.scale.z = 0.0
                d.pos.z = 0.0
                d.wirecolor = wirecolor
                d.color = wirecolor

                volume_layer.addNode d

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
            new_layers = #()

            undo "Generate Current Layer Volume" on
            (
                obj = if (selection.count > 0) then selection[1] else undefined
                source_nodes = collectSelectionVolumeSourceNodes()

                if (source_nodes.count > 0) then
                (
                    target_layer = source_nodes[1].layer

                    if (not (isLayerChainVisible target_layer)) then
                    (
                        showHiddenLayerMessage target_layer from_current_layer:false
                    )
                    else if (not (createVolumeFromNodes source_nodes undefined is_layer:false target_layer:target_layer use_bounds:true margin_percent:0.10)) then
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
                            target_layer = setCurrentLayerToFirstVisibleObjectTopLayer()
                        )

                        if (target_layer != undefined) then
                        (
                            /* GET NAME BY SELECTED DUMMY OR BY TOP LAYER */
                            vol_name = undefined
                            wirecolor = undefined
                            if (this._isDummySelected obj) then
                            (
                                vol_name = trimGetUniqueDummy obj.name
                                wirecolor = obj.wirecolor
                            )

                            if (not (createVolumeFromCurrentView vol_name target_layer:target_layer wirecolor:wirecolor from_current_layer:true)) then
                                messageBox ("Could not calculate current viewport XY volume.\n\nIn layer:\n\n" + target_layer.name) title:"Generate Volumes"
                            else
                                format "GENERATED VIEW VOLUME FOR CURRENT LAYER: %\n" target_layer.name
                        )
                        else
                        (
                            messageBox "Current layer is hidden and no visible object layer was found." title:"Generate Volumes"
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
            new_layers = #()

            undo "Generate Volumes" on
            (
                current_selection = selection as Array

                local s_nodes = collectSelectionVolumeSourceNodes()
                if (s_nodes.count > 0) then
                (
                    local t_lay = s_nodes[1].layer
                    if (not (isLayerChainVisible t_lay)) then
                    (
                        showHiddenLayerMessage t_lay from_current_layer:false
                    )
                    else if (createVolumeFromNodes s_nodes undefined is_layer:false target_layer:t_lay use_bounds:true margin_percent:0.10) then
                    (
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

    /* Collect remaining spline nodes from a layer tree.
       Volume helpers and group heads are not grouped as trim results. */
    function collectTrimResultNodesForLayer layer_item ignore_frz:true =
    (
        local result_nodes = #()

        if (layer_item != undefined) then
        (
            local layer_nodes = collectAllNodesInLayerTree layer_item

            for node_item in layer_nodes where (isValidNode node_item and core.isSplineShapeNode node_item and not isGroupHead node_item and not (core.isVolumeDummy node_item) and node_item.name != "TRIM_CANVAS" and node_item.name != "TRIM_SELECTION" and core.isNodeProcessable node_item ignore_frozen:ignore_frz) do
            (
                appendIfUnique result_nodes node_item
            )
        )

        result_nodes
        -- return
    ),

    /* Group unwrapped trim result nodes in a layer.
       If all result nodes are already group members, no new group is created. */
    function groupTrimmedResultForLayer layer_item ignore_frz:true =
    (
        local result_group = undefined

        if (layer_item != undefined) then
        (
            local result_nodes = collectTrimResultNodesForLayer layer_item ignore_frz:ignore_frz
            local unwrapped_nodes = #()

            for node_item in result_nodes where (isValidNode node_item and not isGroupMember node_item) do
            (
                appendIfUnique unwrapped_nodes node_item
            )

            if (result_nodes.count > 0 and unwrapped_nodes.count > 0) then
            (
                try
                (
                    result_group = group unwrapped_nodes name:layer_item.name

                    if (isValidNode result_group) then
                    (
                        result_group.name = layer_item.name
                        layer_item.addNode result_group
                    )
                )
                catch
                (
                    format "Group trimmed result failed for layer: %\n" layer_item.name
                    result_group = undefined
                )
            )
        )

        result_group
        -- return
    ),

    /* Test if node is a point helper.
       Only classOf Point objects are handled by point-helper cleanup. */
    function isPointHelperNode node_item =
    (
        (isValidNode node_item and classOf node_item == Point)
        -- return
    ),

    /* Remove point helpers outside volume in XY only.
       Inside point helpers are flattened to Z = 0. */
    function deletePointHelpersOutsideVolume vol_node tol_val:0.001 ignore_frz:true =
    (
        local deleted_count = 0

        if (isValidNode vol_node) then
        (
            local bounds_data = core.getVolumeBoundsData vol_node

            if (bounds_data != undefined) then
            (
                local point_nodes = for node_item in objects where (isPointHelperNode node_item and node_item != vol_node and core.isNodeProcessable node_item ignore_frozen:ignore_frz) collect node_item

                for point_node in point_nodes where isValidNode point_node do
                (
                    if (not (core.isWorldPointInsideVolume point_node.pos bounds_data tol_val:tol_val)) then
                    (
                        delete point_node
                        deleted_count += 1
                    )
                    else
                    (
                        point_node.pos = [point_node.pos.x, point_node.pos.y, 0.0]
                    )
                )
            )
        )

        deleted_count
        -- return
    ),

    /* Delete trim volume dummy after a successful trim.
       Only VolumeHelper trim dummies are removed. */
    function deleteVolumeDummyOnSuccess volume_node =
    (
        local delete_result = false

        if (isValidNode volume_node and core.isVolumeDummy volume_node) then
        (
            try
            (
                delete volume_node
                delete_result = true
            )
            catch
            (
                delete_result = false
            )
        )

        delete_result
        -- return
    ),

    /* Run trim and optionally group the unwrapped result nodes.
       Group name and group layer follow the volume helper layer. */
    function runTrimWithVolume vol_node quiet:false tol_val:0.001 del_empty:true ignore_frz:true group_result:false =
    (
        local result_data = core.run vol_node quiet:quiet tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz

        deletePointHelpersOutsideVolume vol_node tol_val:tol_val ignore_frz:ignore_frz

        if (group_result and isValidNode vol_node and vol_node.layer != undefined) then
        (
            groupTrimmedResultForLayer vol_node.layer ignore_frz:ignore_frz
        )

        if (result_data != undefined) then deleteVolumeDummyOnSuccess vol_node

        result_data
        -- return
    ),


    /* Create a unique node name from a base name.
       Used by split feature output nodes and groups. */
    function getUniqueSceneNodeName base_name =
    (
        local clean_name = if (base_name != undefined and base_name != "") then base_name else "Node"
        local result_name = clean_name
        local index_value = 1

        while (isValidNode (getNodeByName result_name)) do
        (
            local index_string = index_value as string
            while (index_string.count < 3) do index_string = "0" + index_string
            result_name = clean_name + "_" + index_string
            index_value += 1
        )

        result_name
        -- return
    ),

    /* Get or create one visible child layer.
       New layers created by this tool are forced visible. */
    function getOrCreateVisibleChildLayer layer_name parent_layer:undefined =
    (
        local layer_item = LayerManager.getLayerFromName layer_name

        if (layer_item == undefined) then
        (
            layer_item = LayerManager.newLayerFromName layer_name
            makeNewLayerVisible layer_item
            appendIfUnique new_layers layer_item
        )

        if (layer_item != undefined) then
        (
            layer_item.on = true

            if (parent_layer != undefined and layer_item != parent_layer) then
            (
                try ( layer_item.setParent parent_layer ) catch()
            )
        )

        layer_item
        -- return
    ),

    /* Get selected group head for slice split.
       First selected group head is used as source group. */
    function getSelectedSliceGroupHead =
    (
        local group_head = undefined

        for node_item in selection where (group_head == undefined and isValidNode node_item and isGroupHead node_item) do
        (
            group_head = node_item
        )

        group_head
        -- return
    ),

    /* Get selected slice plane node.
       Plane node must be selected and must not be inside the source group. */
    function getSelectedSlicePlaneNode group_head =
    (
        local slice_node = undefined

        for node_item in selection where (slice_node == undefined and isValidNode node_item and node_item != group_head and not isGroupHead node_item) do
        (
            if (not (isNodeUnderGroupHead node_item group_head)) then
            (
                slice_node = node_item
            )
        )

        slice_node
        -- return
    ),

    /* Build infinite slice plane data from node transform.
       Local Z axis of node is used as plane normal. */
    function getSlicePlaneData slice_node =
    (
        local plane_data = undefined

        if (isValidNode slice_node) then
        (
            local slice_tm = slice_node.transform
            local plane_pos = slice_tm.row4
            local plane_normal = slice_tm.row3

            if ((length plane_normal) < 0.000001) then
            (
                plane_normal = [0,0,1]
            )
            else
            (
                plane_normal = normalize plane_normal
            )

            plane_data = #(plane_pos, plane_normal)
        )

        plane_data
        -- return
    ),

    /* Get signed distance of world point from slice plane.
       Positive side follows slice plane local Z axis. */
    function getSliceSignedDistance world_point plane_data =
    (
        local signed_distance = 0.0

        if (plane_data != undefined and plane_data.count >= 2) then
        (
            signed_distance = dot (world_point - plane_data[1]) plane_data[2]
        )

        signed_distance
        -- return
    ),

    /* Build world-space bbox corners.
       Used for robust side classification of whole objects. */
    function getWorldBBoxCorners node_item =
    (
        local corner_points = #()

        if (isValidNode node_item) then
        (
            local bbox_value = nodeGetBoundingBox node_item (matrix3 1)
            local min_p = bbox_value[1]
            local max_p = bbox_value[2]

            append corner_points [min_p.x,min_p.y,min_p.z]
            append corner_points [max_p.x,min_p.y,min_p.z]
            append corner_points [min_p.x,max_p.y,min_p.z]
            append corner_points [max_p.x,max_p.y,min_p.z]
            append corner_points [min_p.x,min_p.y,max_p.z]
            append corner_points [max_p.x,min_p.y,max_p.z]
            append corner_points [min_p.x,max_p.y,max_p.z]
            append corner_points [max_p.x,max_p.y,max_p.z]
        )

        corner_points
        -- return
    ),

    /* Classify node by bbox side.
       Returns 1 positive, -1 negative, 0 crossing or on plane. */
    function getNodeSideBySlicePlane node_item plane_data tol_val:0.001 =
    (
        local side_value = 0
        local positive_count = 0
        local negative_count = 0
        local corner_points = getWorldBBoxCorners node_item

        for point_item in corner_points do
        (
            local signed_distance = getSliceSignedDistance point_item plane_data

            if (signed_distance > tol_val) then positive_count += 1
            else if (signed_distance < -tol_val) then negative_count += 1
        )

        if (positive_count > 0 and negative_count == 0) then side_value = 1
        else if (negative_count > 0 and positive_count == 0) then side_value = -1
        else side_value = 0

        side_value
        -- return
    ),

    /* Classify node by bbox center.
       Used for non-shape objects that intersect the slice plane. */
    function getNodeCenterSideBySlicePlane node_item plane_data tol_val:0.001 =
    (
        local side_value = 1

        if (isValidNode node_item) then
        (
            local bbox_value = nodeGetBoundingBox node_item (matrix3 1)
            local center_point = (bbox_value[1] + bbox_value[2]) / 2.0
            local signed_distance = getSliceSignedDistance center_point plane_data

            if (signed_distance < -tol_val) then side_value = -1
            else side_value = 1
        )

        side_value
        -- return
    ),

    /* Add point to polyline if it is not duplicate of last point.
       Keeps generated sliced splines clean. */
    function appendSlicePolylinePoint polyline_points point_value tol_val:0.001 =
    (
        local result_points = polyline_points
        local can_append = true

        if (result_points.count > 0) then
        (
            if ((distance result_points[result_points.count] point_value) <= tol_val) then can_append = false
        )

        if (can_append) then append result_points point_value

        result_points
        -- return
    ),

    /* Get world-space knot point.
       New sliced shapes are generated in world space. */
    function getWorldKnotPoint shape_node spline_index knot_index =
    (
        ((getKnotPoint shape_node spline_index knot_index) * shape_node.objectTransform)
        -- return
    ),

    /* Get segment intersection point with slice plane.
       Linear interpolation is used between spline knots. */
    function getSliceSegmentIntersection p_a p_b d_a d_b =
    (
        local factor_value = 0.5
        local denom_value = d_a - d_b

        if ((abs denom_value) > 0.0000001) then
        (
            factor_value = d_a / denom_value
        )

        if (factor_value < 0.0) then factor_value = 0.0
        if (factor_value > 1.0) then factor_value = 1.0

        (p_a + ((p_b - p_a) * factor_value))
        -- return
    ),

    /* Build side polylines from one spline shape.
       Curved segments are sliced by their knot-to-knot chord. */
    function buildSliceSidePolylines shape_node plane_data side_value tol_val:0.001 =
    (
        local all_polylines = #()

        if (isValidNode shape_node and core.isSplineShapeNode shape_node) then
        (
            for spline_index = 1 to (numSplines shape_node) do
            (
                local knot_count = numKnots shape_node spline_index

                if (knot_count > 1) then
                (
                    local point_values = for knot_index = 1 to knot_count collect (getWorldKnotPoint shape_node spline_index knot_index)
                    local dist_values = for point_item in point_values collect (getSliceSignedDistance point_item plane_data)
                    local segment_count = if (isClosed shape_node spline_index) then knot_count else (knot_count - 1)
                    local current_points = #()

                    for segment_index = 1 to segment_count do
                    (
                        local next_index = if (segment_index == knot_count) then 1 else (segment_index + 1)
                        local p_a = point_values[segment_index]
                        local p_b = point_values[next_index]
                        local d_a = dist_values[segment_index]
                        local d_b = dist_values[next_index]
                        local in_a = if (side_value > 0) then (d_a >= -tol_val) else (d_a <= tol_val)
                        local in_b = if (side_value > 0) then (d_b >= -tol_val) else (d_b <= tol_val)

                        if (in_a and in_b) then
                        (
                            current_points = appendSlicePolylinePoint current_points p_a tol_val:tol_val
                            current_points = appendSlicePolylinePoint current_points p_b tol_val:tol_val
                        )
                        else if (in_a and not in_b) then
                        (
                            local cross_point = getSliceSegmentIntersection p_a p_b d_a d_b
                            current_points = appendSlicePolylinePoint current_points p_a tol_val:tol_val
                            current_points = appendSlicePolylinePoint current_points cross_point tol_val:tol_val

                            if (current_points.count > 1) then append all_polylines current_points
                            current_points = #()
                        )
                        else if ((not in_a) and in_b) then
                        (
                            local cross_point = getSliceSegmentIntersection p_a p_b d_a d_b
                            current_points = appendSlicePolylinePoint current_points cross_point tol_val:tol_val
                            current_points = appendSlicePolylinePoint current_points p_b tol_val:tol_val
                        )
                    )

                    if (current_points.count > 1) then append all_polylines current_points
                )
            )
        )

        all_polylines
        -- return
    ),

    /* Create spline shape from world-space polylines.
       Output shape has identity transform and inherits display from source. */
    function createShapeFromSlicePolylines polyline_values shape_name source_node target_layer =
    (
        local new_shape = undefined

        if (polyline_values.count > 0) then
        (
            new_shape = SplineShape name:(getUniqueSceneNodeName shape_name)
            new_shape.transform = matrix3 1

            try ( new_shape.wirecolor = source_node.wirecolor ) catch()
            try ( new_shape.color = source_node.color ) catch()
            try ( new_shape.material = source_node.material ) catch()

            for polyline_points in polyline_values where polyline_points.count > 1 do
            (
                addNewSpline new_shape
                local spline_index = numSplines new_shape

                for point_item in polyline_points do
                (
                    addKnot new_shape spline_index #corner #line point_item
                )
            )

            if ((numSplines new_shape) > 0) then
            (
                updateShape new_shape

                if (target_layer != undefined) then target_layer.addNode new_shape
            )
            else
            (
                delete new_shape
                new_shape = undefined
            )
        )

        new_shape
        -- return
    ),

    /* Copy whole object into side layer.
       Used when object is fully on one side or cannot be shape-sliced. */
    function copyNodeToSliceSide source_node target_layer suffix_text =
    (
        local copied_node = undefined

        if (isValidNode source_node) then
        (
            try
            (
                copied_node = copy source_node
                copied_node.name = getUniqueSceneNodeName (source_node.name + suffix_text)

                if (target_layer != undefined) then target_layer.addNode copied_node
                try ( copied_node.isHidden = false ) catch()
            )
            catch
            (
                copied_node = undefined
            )
        )

        copied_node
        -- return
    ),

    /* Hide original source group after successful split.
       Original data is preserved but removed from visible result. */
    function hideSliceSourceGroup group_head source_nodes =
    (
        if (isValidNode group_head) then
        (
            try ( group_head.isHidden = true ) catch()
        )

        for node_item in source_nodes where isValidNode node_item do
        (
            try ( node_item.isHidden = true ) catch()
        )
    ),

    /* Create side group from output nodes.
       Group head is placed on the same side layer. */
    function createSliceSideGroup side_nodes group_name target_layer =
    (
        local result_group = undefined
        local valid_nodes = for node_item in side_nodes where isValidNode node_item collect node_item

        if (valid_nodes.count > 0) then
        (
            try
            (
                result_group = group valid_nodes name:(getUniqueSceneNodeName group_name)

                if (isValidNode result_group and target_layer != undefined) then
                (
                    target_layer.addNode result_group
                    result_group.isHidden = false
                )
            )
            catch
            (
                result_group = undefined
            )
        )

        result_group
        -- return
    ),

    /* Split selected group by selected slice plane.
       Side output layer and group names are driven by the old source layer name. */
    function splitSelectedGroupBySlicePlane quiet:false tol_val:0.001 =
    (
        local result_data = undefined
        local group_head = getSelectedSliceGroupHead()
        local slice_node = getSelectedSlicePlaneNode group_head

        if (not (isValidNode group_head)) then
        (
            messageBox "Select one group head and one slice plane node." title:"Split Group By Plane"
            return undefined
        )

        if (not (isValidNode slice_node)) then
        (
            messageBox "Select one slice plane node with the group head. Slice plane local Z axis defines the split normal." title:"Split Group By Plane"
            return undefined
        )

        local plane_data = getSlicePlaneData slice_node

        if (plane_data == undefined) then
        (
            messageBox "Slice plane data could not be read." title:"Split Group By Plane"
            return undefined
        )

        local source_nodes = collectGroupHeadMemberNodes group_head
        local process_nodes = for node_item in source_nodes where (isValidNode node_item and node_item != slice_node and not core.isVolumeDummy node_item and node_item.name != "TRIM_CANVAS") collect node_item

        if (process_nodes.count < 1) then
        (
            messageBox "Selected group has no valid member objects to split." title:"Split Group By Plane"
            return undefined
        )

        local source_layer = if (group_head.layer != undefined) then group_head.layer else LayerManager.getLayer 0
        local top_layer = if (source_layer != undefined) then getTopLayer source_layer else LayerManager.getLayer 0
        local source_layer_name = if (source_layer != undefined and source_layer.name != undefined and source_layer.name != "") then source_layer.name else group_head.name
        local positive_layer = getOrCreateVisibleChildLayer (source_layer_name + "_A") parent_layer:top_layer
        local negative_layer = getOrCreateVisibleChildLayer (source_layer_name + "_B") parent_layer:top_layer
        local positive_nodes = #()
        local negative_nodes = #()
        local copied_count = 0
        local sliced_count = 0

        undo "Split Group By Slice Plane" on
        (
            try ( setGroupOpen group_head true ) catch()

            for source_node in process_nodes where isValidNode source_node do
            (
                local side_value = getNodeSideBySlicePlane source_node plane_data tol_val:tol_val

                if (core.isSplineShapeNode source_node and side_value == 0) then
                (
                    local positive_polylines = buildSliceSidePolylines source_node plane_data 1 tol_val:tol_val
                    local negative_polylines = buildSliceSidePolylines source_node plane_data -1 tol_val:tol_val
                    local positive_shape = createShapeFromSlicePolylines positive_polylines (source_node.name + "_A") source_node positive_layer
                    local negative_shape = createShapeFromSlicePolylines negative_polylines (source_node.name + "_B") source_node negative_layer

                    if (isValidNode positive_shape) then append positive_nodes positive_shape
                    if (isValidNode negative_shape) then append negative_nodes negative_shape

                    if (isValidNode positive_shape or isValidNode negative_shape) then
                    (
                        sliced_count += 1
                    )
                    else
                    (
                        local center_side = getNodeCenterSideBySlicePlane source_node plane_data tol_val:tol_val
                        local copied_node = if (center_side >= 0) then (copyNodeToSliceSide source_node positive_layer "_A") else (copyNodeToSliceSide source_node negative_layer "_B")

                        if (isValidNode copied_node) then
                        (
                            if (center_side >= 0) then append positive_nodes copied_node else append negative_nodes copied_node
                            copied_count += 1
                        )
                    )
                )
                else
                (
                    local target_side = if (side_value == 0) then (getNodeCenterSideBySlicePlane source_node plane_data tol_val:tol_val) else side_value
                    local copied_node = if (target_side >= 0) then (copyNodeToSliceSide source_node positive_layer "_A") else (copyNodeToSliceSide source_node negative_layer "_B")

                    if (isValidNode copied_node) then
                    (
                        if (target_side >= 0) then append positive_nodes copied_node else append negative_nodes copied_node
                        copied_count += 1
                    )
                )
            )

            local positive_group = createSliceSideGroup positive_nodes (source_layer_name + "_A") positive_layer
            local negative_group = createSliceSideGroup negative_nodes (source_layer_name + "_B") negative_layer
            local result_groups = #()

            if (isValidNode positive_group) then append result_groups positive_group
            if (isValidNode negative_group) then append result_groups negative_group

            if (result_groups.count > 0) then
            (
                hideSliceSourceGroup group_head process_nodes
                select result_groups
                result_data = #(positive_nodes.count, negative_nodes.count, sliced_count, copied_count)
            )
        )

        if (result_data != undefined) then
        (
            completeRedraw()

            if (not quiet) then
            (
                messageBox ("Split complete." + \
                    "\nSide A objects: " + (result_data[1] as string) + \
                    "\nSide B objects: " + (result_data[2] as string) + \
                    "\nSliced shapes: " + (result_data[3] as string) + \
                    "\nCopied objects: " + (result_data[4] as string) + \
                    "\nOriginal group is hidden, not deleted.") title:"Split Group By Plane"
            )
        )
        else
        (
            if (not quiet) then messageBox "Split failed. Original group was not hidden." title:"Split Group By Plane"
        )

        result_data
        -- return
    ),

    /* Collect volume helper dummies in scene.
       Hidden-layer dummies are ignored by default. */
    function collectSceneVolumeDummies visible_layers_only:true =
    (
        local volume_nodes = #()

        for node_item in objects where (core.isVolumeDummy node_item and ((visible_layers_only == false) or isVolumeDummyInVisibleLayer node_item)) do
        (
            append volume_nodes node_item
        )

        volume_nodes
        -- return
    ),

    /* Collect visible top layers used by auto Mass Mode.
       Hidden top layers are ignored completely. */
    function collectVisibleMassTopLayers =
    (
        local top_layers = #()

        for layer_index = 0 to LayerManager.count - 1 do
        (
            local layer_item = LayerManager.getLayer layer_index

            if (layer_item != undefined and layer_item.name != "0" and findString layer_item.name "_TO_DELETE_" == undefined and isTopLayer layer_item.name and layer_item.on == true) then
            (
                append top_layers layer_item
            )
        )

        top_layers
        -- return
    ),

    /* Store visibility of existing top layers.
       Used to restore original layer state after successful Mass Mode. */
    function collectTopLayerVisibilityState =
    (
        local layer_state = #()

        for layer_index = 0 to LayerManager.count - 1 do
        (
            local layer_item = LayerManager.getLayer layer_index

            if (layer_item != undefined and layer_item.name != "0" and isTopLayer layer_item.name) then
            (
                append layer_state #(layer_item, layer_item.name, layer_item.on)
            )
        )

        layer_state
        -- return
    ),

    /* Restore visibility of existing top layers.
       New result layers are not forced hidden by this restore. */
    function restoreTopLayerVisibilityState layer_state =
    (
        if (layer_state != undefined) then
        (
            for state_item in layer_state where (state_item != undefined and state_item.count >= 3) do
            (
                local layer_item = state_item[1]
                local layer_name = state_item[2]
                local layer_on = state_item[3]

                if (layer_item == undefined) then layer_item = LayerManager.getLayerFromName layer_name

                if (layer_item != undefined) then
                (
                    try (layer_item.on = layer_on) catch()
                )
            )
        )

        true
        -- return
    ),

    /* Collect volume helpers from visible auto Mass Mode top layers.
       Dummies under hidden top layers are not used or validated. */
    function collectVolumeDummiesInTopLayers top_layers visible_layers_only:true =
    (
        local volume_nodes = #()

        if (top_layers != undefined) then
        (
            for top_layer in top_layers where (top_layer != undefined) do
            (
                local layer_volumes = getVolumesInLayerTree top_layer visible_layers_only:visible_layers_only

                for volume_node in layer_volumes where isValidNode volume_node do
                (
                    appendIfUnique volume_nodes volume_node
                )
            )
        )

        volume_nodes
        -- return
    ),

    /* Collect duplicate-name volume helper data.
       When top layers are supplied, only those Mass Mode dummies are checked. */
    function getDuplicateVolumeDummyNameData top_layers:undefined =
    (
        local volume_nodes = if (top_layers == undefined) then (collectSceneVolumeDummies visible_layers_only:false) else (collectVolumeDummiesInTopLayers top_layers visible_layers_only:true)
        local name_keys = #()
        local name_counts = #()
        local duplicate_names = #()
        local duplicate_nodes = #()

        for volume_node in volume_nodes where isValidNode volume_node do
        (
            local name_key = toLower volume_node.name
            local key_index = findItem name_keys name_key

            if (key_index == 0) then
            (
                append name_keys name_key
                append name_counts 1
            )
            else
            (
                name_counts[key_index] += 1
            )
        )

        for volume_node in volume_nodes where isValidNode volume_node do
        (
            local name_key = toLower volume_node.name
            local key_index = findItem name_keys name_key

            if (key_index > 0 and name_counts[key_index] > 1) then
            (
                appendIfUnique duplicate_names volume_node.name
                appendIfUnique duplicate_nodes volume_node
            )
        )

        #(duplicate_names, duplicate_nodes)
        -- return
    ),

    /* Reveal selected duplicate volume helpers.
       Turns on layer chain, unhides helpers, selects them, and starts isolate selection mode. */
    function revealDuplicateVolumeDummies duplicate_nodes =
    (
        local valid_nodes = #()

        for node_item in duplicate_nodes where isValidNode node_item do
        (
            appendIfUnique valid_nodes node_item

            try
            (
                if (node_item.layer != undefined) then turnOnLayerChain node_item.layer
            )
            catch
            (
            )

            try (node_item.isHidden = false) catch()
            try (core.openParentGroups node_item) catch()
        )

        if (valid_nodes.count > 0) then
        (
            try (select valid_nodes) catch()
            try (completeRedraw()) catch()

            try (IsolateSelection.ExitIsolateSelectionMode()) catch()
            try
            (
                IsolateSelection.EnterIsolateSelectionMode()
            )
            catch
            (
                try (execute "max isolate selection") catch()
            )

            try (max zoomext sel) catch()
        )

        valid_nodes.count
        -- return
    ),

    /* Check used volume dummy names before mass trim.
       Only dummies under visible auto Mass Mode top layers are validated. */
    function validateVolumeDummyUniqueNames quiet:false top_layers:undefined =
    (
        local duplicate_data = getDuplicateVolumeDummyNameData top_layers:top_layers
        local duplicate_names = duplicate_data[1]
        local duplicate_nodes = duplicate_data[2]

        if (duplicate_nodes.count > 0) then
        (
            revealDuplicateVolumeDummies duplicate_nodes

            if (not quiet) then
            (
                local duplicate_text = ""

                for duplicate_name in duplicate_names do
                (
                    duplicate_text += duplicate_name + "\n"
                )

                messageBox ("Mass Mode stopped.\n\nAll volume helper names must be unique before mass trim.\n\nDuplicate helpers were selected, unhidden, and isolated.\n\nDuplicate names:\n" + duplicate_text) title:"Mass Mode"
            )

            false
        )
        else
        (
            true
        )
        -- return
    ),

    function runMassMode quiet:false tol_val:0.001 del_empty:true ignore_frz:true group_result:false =
        (
            new_layers = #()

            local top_layer_visibility_state = collectTopLayerVisibilityState()
            local t_lays = collectVisibleMassTopLayers()

            if (not (validateVolumeDummyUniqueNames quiet:quiet top_layers:t_lays)) then return undefined

            local t_p = 0, t_dk = 0, a_vols = #()

            for t_lay in t_lays do
            (
                local v_arr = getVolumesInLayerTree t_lay visible_layers_only:true
                if (v_arr.count == 1) then
                (
                    local v_n = v_arr[1]; append a_vols v_n
                    if (not quiet) then (format "\rMass Mode: '%'..." v_n.name; windows.processPostedMessages())
                    for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                    turnOnLayerChain t_lay; unhideLayerHierarchy t_lay
                    local res = runTrimWithVolume v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz group_result:group_result
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
                        if (dummy_layer == undefined) then
                        (
                            dummy_layer = LayerManager.newLayerFromName top_name
                            makeNewLayerVisible dummy_layer
                        )
                        dummy_layer.addNode v_n

                        for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                        turnOnLayerChain dummy_layer; unhideLayerHierarchy dummy_layer
                        local res = runTrimWithVolume v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz group_result:group_result
                        if (res != undefined) then ( t_p += res[1]; t_dk += res[3] )
                    )
                    deleteAllNodesInLayerTree t_lay; (LayerManager.getLayer 0).current = true; deleteLayerTree t_lay
                )
            )
            restoreTopLayerVisibilityState top_layer_visibility_state
            turnOnNewLayers()
            undo "Delete Mass Volumes" on ( for v in a_vols where isValidNode v do delete v )
            restoreTopLayerVisibilityState top_layer_visibility_state
            turnOnNewLayers()
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

