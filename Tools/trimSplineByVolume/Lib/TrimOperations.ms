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

    function getTopLayer layer_item =
        (
            while ((layer_item.getParent()) != undefined and (layer_item.getParent()).name != "0") do layer_item = layer_item.getParent(); layer_item

            layer_item --return
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

    function createVolumeFromNodes n_arr vol_name is_layer:false target_layer:undefined wirecolor:undefined =
    (
        result = false

        if (target_layer == undefined) then target_layer = this._getTargetLayer()

        if (target_layer != undefined) then
        (
            local exist_dummy = getNodeByName target_layer.name
            if (isValidNode exist_dummy and core.isVolumeDummy exist_dummy) then delete exist_dummy

            average_bbox_data = this._geSizeAndPosOfDummy(n_arr)
            average_bbox_data = makeSafe2DVolumeData (average_bbox_data[1]) (average_bbox_data[2])

            size = average_bbox_data[1]
            cent = average_bbox_data[2]

            obj = if (selection.count > 0) then selection[1] else undefined
            top_layer = getTopLayer target_layer

            if wirecolor == undefined then
                wirecolor = top_layer.wireColor

            if vol_name == undefined then
                vol_name = top_layer.name

            /* CREATE DUMMY */
            local d = VolumeHelper name:vol_name pos:cent size:1 wirecolor:wirecolor color:wirecolor
            d.pos.z = 0.0

            append new_dummies d

            /* SET DUMMY SCALE */
            d.scale = size
            d.scale.z = 0.0
            d.pos.z = 0.0

            top_layer.addNode d

            result = true
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
                --format "TARGET_LAYER: %\n" target_layer
            target_layer = this._getTargetLayer()


                if (target_layer != undefined) then
                (
                    --local lay_name = target_layer.name

                    /* AUTO FIND LAYER TO GENERATE IF VURRENT LAYER IS DEFAULT ( uer friedlai front end function ) */
                    if (target_layer.name == "0") then
                    (
                        /* GET ENABLED TOP LAYERS */
                        visible_top_layers = for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i ).getParent() == undefined and layer.on collect layer
                        --format "visible_top_layers.count: %\n" visible_top_layers.count


                        if visible_top_layers.count > 0 then
                        (
                            /* SERACH FOR LAYER WITHOUT DUMMY */
                            layers_without_dummy = for visible_top_layer in visible_top_layers where (this.getVolumesInLayerTree visible_top_layer).count == 0 collect visible_top_layer

                            target_layer = if layers_without_dummy.count > 0 then layers_without_dummy[1] else visible_top_layers[1]

                            target_layer.current  = true
                        )

                    )

                    local ex_vols = this.getVolumesInLayerTree target_layer

                        local a_nodes = collectAllNodesInLayerTree target_layer
/* GET NAME BY SELECTED DUMMY OR BY TOP LAYER */ 
                            vol_name = undefined
                            wirecolor = undefined
                            if (this._isDummySelected obj) then
                            (
                                vol_name = trimGetNextDummy obj.name
                                wirecolor = obj.wirecolor
                            )
                            
                            
                            
                        if not (createVolumeFromNodes a_nodes vol_name is_layer:true target_layer:target_layer wirecolor:wirecolor ) then
                            messageBox ("A No valid objects found to calculate volume.\n\nIn layer:\n\n"+target_layer.name) title:"Generate Volumes"
                        else
                            FORMAT "GENERATED VOLUME FOR LAYER: %"  target_layer.name
                            --messageBox ("Generated volume for layer: " + target_layer.name) title:"Generate Volumes"
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
                    local t_lay = this.getTopLayer s_nodes[1].layer
                    if (createVolumeFromNodes s_nodes "TRIM_SELECTION" is_layer:true target_layer:t_lay) then
                    (
                        local d = getNodeByName "TRIM_SELECTION"
                        if (isValidNode d) then select d
                        messageBox "Generated single volume for selected objects." title:"Generate Volumes"
                    )
                    else
                    (
                        messageBox ("B No valid selected objects found to calculate volume.\n\nIn layer:\n\n"+t_lay.name) title:"Generate Volumes"

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

