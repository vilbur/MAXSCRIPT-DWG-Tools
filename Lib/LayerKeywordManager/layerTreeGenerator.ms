global layer_names_keywords
global tv_rollout
-- global layerToggleCallback 

/** * Main function to initialize and display the layer tree rollout.
 */
function layerTreeGenerator =
(
	format "\n"; print ".layerTreeGenerator()"
	
	try(destroyDialog tv_rollout)catch()

	rollout tv_rollout "Dark Layer Tree View" width:300 height:400
	(
		dotNetControl tv "System.Windows.Forms.TreeView" width:280 height:1280 pos:[10,10]
	
		local is_updating = false 
		local locked_ids = #("A", "mainx_suba_foo") 
		
		-- Master dictionary to remember the state of all items even if they are hidden from UI
		local node_states = Dictionary #string
		local show_mixed_items = true

		/** * Generates the custom 3-state checkbox images natively for the dark theme.
		 */
		function createTriStateImageList =
		(
			local img_list = dotNetObject "System.Windows.Forms.ImageList"
			img_list.ImageSize = dotNetObject "System.Drawing.Size" 16 16
			
			local color_class = dotNetClass "System.Drawing.Color"
			local bg_color = color_class.FromArgb 40 40 40
			local border_color = color_class.FromArgb 150 150 150
			local fill_color = color_class.FromArgb 220 220 220
			
			local brush_bg = dotNetObject "System.Drawing.SolidBrush" bg_color
			local pen_border = dotNetObject "System.Drawing.Pen" border_color 1
			local brush_fill = dotNetObject "System.Drawing.SolidBrush" fill_color
			
			fn drawBase brush_bg pen_border =
			(
				local bmp = dotNetObject "System.Drawing.Bitmap" 16 16
				local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
				g.FillRectangle brush_bg 0 0 16 16
				g.DrawRectangle pen_border 2 2 11 11
				#(bmp, g)
			)
			
			-- State 0: Unchecked (Empty Box)
			local base0 = drawBase(brush_bg)(pen_border)
			img_list.Images.Add base0[1]
			
			-- State 1: Checked (Solid Inner Box)
			local base1 = drawBase(brush_bg)(pen_border)
			base1[2].FillRectangle brush_fill 5 5 6 6 
			img_list.Images.Add base1[1]
			
			-- State 2: Mixed / Indeterminate (Horizontal Dash)
			local base2 = drawBase(brush_bg)(pen_border)
			base2[2].FillRectangle brush_fill 4 7 8 2 
			img_list.Images.Add base2[1]
			
			return img_list
		)

		/** * Centralized helper to update the UI node and the master memory dictionary.
		 */
		function updateNodeState node state_int =
		(
			node.StateImageIndex = state_int
			node_states[node.Tag as string] = state_int
		)

		/** * Traverses the tree recursively to return a flat array of all nodes currently in UI.
		 */
		function getAllNodes parent_collection out_array:undefined =
		(
			if out_array == undefined do out_array = #()
			for i = 0 to parent_collection.Count - 1 do
			(
				local current_node = parent_collection.Item[i]
				append out_array current_node
				getAllNodes current_node.Nodes out_array:out_array
			)
			out_array
		)

		/** * Recursively fills the TreeView from a nested MAXScript dictionary.
		 */
		function populateTreeNode dict parent_collection parent_id_path =
		(
			for k in dict.keys do
			(
				local sub_dict = dict[k]
				local current_id = if parent_id_path == "" then k else (parent_id_path + "_" + k)
				
				-- Retrieve saved state, or default to 0 (Unchecked)
				local current_state = 0
				if hasDictValue node_states current_id then 
					current_state = node_states[current_id]
				else
					node_states[current_id] = current_state
				
				-- Filter out mixed items if the user wants them hidden
				if (not show_mixed_items) and (current_state == 2) do continue
				
				local new_node = dotNetObject "System.Windows.Forms.TreeNode" k
				new_node.Tag = current_id 
				new_node.StateImageIndex = current_state
				
				-- Apply gray color to locked items
				if (findItem locked_ids current_id > 0) do 
				(
					new_node.ForeColor = (dotNetClass "System.Drawing.Color").Gray
				)
				
				if sub_dict.keys.count > 0 do (populateTreeNode sub_dict new_node.Nodes current_id)
				parent_collection.Add new_node
			)
		)
	
		/** * Recursively sets the checkbox state of all children of a given node.
		 */
		function setChildrenCheckboxState parent_node target_state =
		(
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for i = 0 to parent_node.Nodes.Count - 1 do
			(
				local child_node = parent_node.Nodes.Item[i]
				
				if child_node.ForeColor.ToArgb() != gray_color_argb then
				(
					if child_node.StateImageIndex != target_state do
					(
						updateNodeState child_node target_state
						if layerToggleCallback != undefined do layerToggleCallback target_state (child_node.Tag as string)
					)
					setChildrenCheckboxState child_node target_state 
				)
				else
				(
					setChildrenCheckboxState child_node target_state
				)
			)
		)

		/* --- REMOTE API FUNCTIONS --- */

		/** * Sets visibility for mixed (State 2) items. Rebuilds UI to reflect changes.
		 */
		function setMixedItemsVisibility is_visible =
		(
			format "\n"; print ".setMixedItemsVisibility()"
			show_mixed_items = is_visible
			tv.BeginUpdate()
			tv.Nodes.Clear()
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			tv.ExpandAll()
			tv.EndUpdate()
		)

		/** * Returns an array of Item IDs that match the target state (0, 1, or 2).
		 */
		function getItemsByState target_state =
		(
			local matched_items = #()
			for k in node_states.keys where node_states[k] == target_state do
			(
				append matched_items k
			)
			return matched_items
		)

		/** * Sets the checked state (0, 1, or 2) for all unlockable items in the tree.
		 */
		function checkAll target_state =
		(
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for n in all_nodes where n.ForeColor.ToArgb() != gray_color_argb do
			(
				if n.StateImageIndex != target_state do
				(
					updateNodeState n target_state
					if layerToggleCallback != undefined do layerToggleCallback target_state (n.Tag as string)
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		/** * Expands all nodes in the tree.
		 */
		function expandAllNodes = (tv.ExpandAll())

		/** * Collapses all nodes in the tree.
		 */
		function collapseAllNodes = (tv.CollapseAll())

		/** * Checks items that match any of the provided string masks (wildcards supported) to a specific state.
		 */
		function checkByMasks masks target_state =
		(
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for n in all_nodes where n.ForeColor.ToArgb() != gray_color_argb do
			(
				local is_matched = false
				local node_id = n.Tag as string
				for m in masks where (matchPattern node_id pattern:m) do is_matched = true
				
				if is_matched and n.StateImageIndex != target_state do
				(
					updateNodeState n target_state
					if layerToggleCallback != undefined do layerToggleCallback target_state node_id
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		/** * Saves the current states (0, 1, 2) of all nodes to an INI file.
		 */
		function saveStateToIni ini_path =
		(
			format "\n"; print "layerTreeGenerator.saveStateToIni()"
			format "ini_path: %\n" ini_path
			
			for k in node_states.keys do
			(
				setINISetting ini_path "LayerStates" k (node_states[k] as string)
			)
		)

		/** * Loads integer states from an INI file, fires callbacks for changed items, and rebuilds tree.
		 */
		function loadStateFromIni ini_path =
		(
			format "\n"; print "layerTreeGenerator.loadStateFromIni()"
			format "ini_path: %\n" ini_path
			
			if not (doesFileExist ini_path) do return false
			
			is_updating = true
			tv.BeginUpdate()
			
			local keys_in_ini = getINISetting ini_path "LayerStates"
			for k in keys_in_ini do
			(
				local val = getINISetting ini_path "LayerStates" k
				local int_val = val as integer
				
				if int_val != undefined do
				(
					local old_val = if hasDictValue node_states k then node_states[k] else 0
					if old_val != int_val do
					(
						node_states[k] = int_val
						-- Fire callback for items modified by the INI load
						if layerToggleCallback != undefined do layerToggleCallback int_val k
					)
				)
			)
			
			-- Rebuild tree to apply loaded states visually
			tv.Nodes.Clear()
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			tv.ExpandAll()
			
			tv.EndUpdate()
			is_updating = false
		)

		/* --- EVENTS --- */

		on tv NodeMouseClick arg do
		(
			-- Right-Click Menu
			if arg.Button == arg.Button.Right do
			(
				local m_menu = dotNetObject "System.Windows.Forms.ContextMenu"
				local item_check  	= m_menu.MenuItems.Add("Check All (True)")
				local item_uncheck  = m_menu.MenuItems.Add("Uncheck All (False)")
				local item_mixed  	= m_menu.MenuItems.Add("Set All to Mixed")
				local item_sep      = m_menu.MenuItems.Add("-")
				local item_expand 	= m_menu.MenuItems.Add("Expand All")
				local item_collapse	= m_menu.MenuItems.Add("Collapse All")
				
				function onCheck   	s e = (tv_rollout.checkAll(1))
				function onUnCheck  s e = (tv_rollout.checkAll(0))
				function onMixed    s e = (tv_rollout.checkAll(2))
				function onExpand  	s e = (tv_rollout.expandAllNodes())
				function onCollapse s e = (tv_rollout.collapseAllNodes())
				
				dotNet.addEventHandler item_check	"Click" onCheck
				dotNet.addEventHandler item_uncheck	"Click" onUnCheck
				dotNet.addEventHandler item_mixed	"Click" onMixed
				dotNet.addEventHandler item_expand	"Click" onExpand
				dotNet.addEventHandler item_collapse "Click" onCollapse
				
				m_menu.Show tv (dotNetObject "System.Drawing.Point" arg.X arg.Y)
			)
			
			-- Left Click logic (Single Click Toggle)
			if arg.Button == arg.Button.Left and not is_updating do
			(
				local hit_info = tv.HitTest arg.X arg.Y
				if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" do
				(
					local current_node = hit_info.Node
					local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
					
					-- Only toggle if it's not locked
					if current_node.ForeColor.ToArgb() != gray_color_argb then
					(
						is_updating = true 
						
						-- Cycle the State: 0 -> 1 -> 2 -> 0
						local new_state = current_node.StateImageIndex + 1
						if new_state > 2 do new_state = 0
						
						updateNodeState current_node new_state
						
						if layerToggleCallback != undefined do 
							layerToggleCallback new_state (current_node.Tag as string)
							
						is_updating = false 
					)
				)
			)
		)

		on tv NodeMouseDoubleClick arg do
		(
			-- Double click on checkbox: Propagate current state to all nested items
			local hit_info = tv.HitTest arg.X arg.Y
			
			if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" do
			(
				local current_node = hit_info.Node
				local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
				
				if current_node.ForeColor.ToArgb() != gray_color_argb then
				(
					is_updating = true 
					
					-- Note: The first click of the double-click already cycled the state.
					-- We grab that new state and push it down to the children.
					local target_state = current_node.StateImageIndex
					
					tv.BeginUpdate() 
					setChildrenCheckboxState current_node target_state
					tv.EndUpdate()
					
					is_updating = false 
				)
			)
		)

		on tv_rollout open do
		(
			tv.SuspendLayout()
			tv.Nodes.Clear()
			tv.Sorted = true
			
			-- VERY IMPORTANT: Disable native checkboxes so our Tri-State images work
			tv.CheckBoxes = false
			tv.StateImageList = createTriStateImageList()
			
			local color_class = dotNetClass "System.Drawing.Color"
			tv.BackColor = color_class.FromArgb 40 40 40
			tv.ForeColor = color_class.FromArgb 220 220 220
			tv.LineColor = color_class.FromArgb 150 150 150
			
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			
			tv.ExpandAll()
			tv.ResumeLayout()
		)
	)
	
	--createDialog tv_rollout -- FOR GEMINY: KEEP THIS CMD COMMENDED, NEED FIT TO WORKFLOW
)