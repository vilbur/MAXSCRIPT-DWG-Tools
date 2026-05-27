struct bottomSplineExtractor_v
(
    z_tolerance = 0.0001,

    function getSelectionArray = selection as array,
    
    function getCreatedObjects old_objects = 
        for o in objects where findItem old_objects o == 0 collect o,

    function mimicProperties source_obj spline_obj =
    (
        if source_obj.layer != undefined then source_obj.layer.addNode spline_obj
        spline_obj.wirecolor = source_obj.wirecolor
        spline_obj.pivot = source_obj.pivot
        spline_obj.name = source_obj.name
    ),

    function mimicHierarchy source_obj spline_obj =
    (
        local is_group = isGroupMember source_obj
        if is_group and isValidNode source_obj.parent then attachNodesToGroup #(spline_obj) source_obj.parent \
        else if isValidNode source_obj.parent then spline_obj.parent = source_obj.parent
        
        local kids = for c in source_obj.children collect c
        for k in kids do if isValidNode k then k.parent = spline_obj
    ),

    function ensureEditablePoly obj =
    (
        if classOf obj == Editable_Poly then return true
        if canConvertTo obj Editable_Poly then convertTo obj Editable_Poly else return false
        classOf obj == Editable_Poly
    ),

    function getBottomEdges obj =
    (
        if (polyOp.getNumVerts obj) == 0 then return #{}
        
        local min_z = 1e9
        for i = 1 to polyOp.getNumVerts obj do if (polyOp.getVert obj i).z < min_z then min_z = (polyOp.getVert obj i).z
        
        local edge_arr = for e = 1 to (polyOp.getNumEdges obj) where \
            abs ((polyOp.getVert obj (polyOp.getEdgeVerts obj e)[1]).z - min_z) <= z_tolerance and \
            abs ((polyOp.getVert obj (polyOp.getEdgeVerts obj e)[2]).z - min_z) <= z_tolerance \
            collect e
            
        edge_arr as bitarray
    ),

    function extractObject source_obj =
    (
        if not isValidNode source_obj then return #(false, "Invalid node.")
        if superClassOf source_obj != GeometryClass then return #(false, source_obj.name + ": Not geometry.")
        if not ensureEditablePoly source_obj then return #(false, source_obj.name + ": Cannot convert.")
        
        local bottom_edges = getBottomEdges source_obj
        if bottom_edges.isEmpty then return #(false, source_obj.name + ": No bottom edges.")
        
        local old_objects = objects as array
        polyOp.setEdgeSelection source_obj bottom_edges
        source_obj.createShape (source_obj.name + "_spline") off source_obj
        
        local new_objs = getCreatedObjects old_objects
        if new_objs.count == 0 then return #(false, source_obj.name + ": Spline not created.")
        
        mimicProperties source_obj new_objs[1]
        mimicHierarchy source_obj new_objs[1]
        
        if isValidNode source_obj then delete source_obj
        #(true, new_objs[1].name + ": Spline created.")
    ),

    function extractBottomSplines objs:undefined quiet:true =
    (
        local source_objs = if objs != undefined then objs else getSelectionArray()
        if source_objs.count == 0 then 
        (
            if not quiet then messageBox "Select objects."
            return false
        )
        
        local results = for obj in source_objs collect extractObject obj
        local created = (for r in results where r[1] == true collect r).count
        local skipped = for r in results where r[1] == false collect r[2]

        if not quiet then
        (
            local msg = "Process Complete!\nCreated: " + (created as string) + "\nSkipped: " + (skipped.count as string) + "\n"
            for txt in skipped do msg += "- " + txt + "\n"
            messageBox msg title:"Results"
        )
        created
    )
)

function extractBottomSplines objs quiet:true = (bottomSplineExtractor_v()).extractBottomSplines objs:objs quiet:quiet