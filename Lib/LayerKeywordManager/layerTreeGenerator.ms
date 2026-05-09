global layer_names_keywords
global tv_rollout
-- global layerToggleCallback 

/** * Main function to initialize and display the layer tree rollout.
 */
function layerTreeGenerator =
(
	format "\n"; print ".layerTreeGenerator()"
	
	try(destroyDialog tv_rollout)catch()

	rollout tv_rollout "Layers Manager" width:400 --height:1140
	(
		dotNetControl tv "System.Windows.Forms.TreeView" width:380 height:512 pos:[0,10]
	
		local is_updating = false
		
		local locked_ids = #() 
		--local locked_ids = #("A", "mainx_suba_foo") 
		
		-- Master dictionary to remember the state of all items even if hidden
		local node_states = Dictionary #string
		local show_mixed_items = true
		
		-- Customizable Sizes
		local checkbox_size = 18
		local font_size = 12
		local line_padding = 2

		-- Custom Multi-Selection Variables
		local selected_nodes = #()
		local last_selected_node = undefined
		local bg_color_obj = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
		local highlight_color_obj = (dotNetClass "System.Drawing.Color").FromArgb 70 130 180

		/** * Helper to clear custom selections cleanly
		 */
		function clearCustomSelection =
		(
			for n in selected_nodes do try(n.BackColor = bg_color_obj)catch()
			selected_nodes = #()
			last_selected_node = undefined
		)

		/** * Updates the font color based on the state and locked status
		 */
		function applyNodeColor node state_int =
		(
			local current_id = node.Tag as string
			local color_class = dotNetClass "System.Drawing.Color"
			
			-- Locked items get a specific dark/dimmed color
			if (findItem locked_ids current_id > 0) then
			(
				node.ForeColor = color_class.FromArgb 100 100 100
			)
			else
			(
				case state_int of
				(
					0: node.ForeColor = color_class.FromArgb 220 220 220 -- Unchecked: Light Gray
					1: node.ForeColor = color_class.FromArgb 150 220 150 -- Checked: Pastel Green
					2: node.ForeColor = color_class.Gray                 -- Mixed: Standard Gray
				)
			)
		)

		/** * Generates the custom 3-state checkbox images natively.
		 */
		function createTriStateImageList cb_size =
		(
			local img_list = dotNetObject "System.Windows.Forms.ImageList"
			img_list.ImageSize = dotNetObject "System.Drawing.Size" cb_size cb_size
			
			local color_class = dotNetClass "System.Drawing.Color"
			local bg_color = color_class.FromArgb 40 40 40
			local border_color = color_class.FromArgb 150 150 150
			local fill_color = color_class.FromArgb 220 220 220
			
			local brush_bg = dotNetObject "System.Drawing.SolidBrush" bg_color
			local pen_border = dotNetObject "System.Drawing.Pen" border_color 1
			local brush_fill = dotNetObject "System.Drawing.SolidBrush" fill_color
			
			-- drawBase now correctly accepts brush and pen as parameters
			fn drawBase b_bg p_border size =
			(
				local bmp = dotNetObject "System.Drawing.Bitmap" size size
				local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
				
				g.FillRectangle b_bg 0 0 size size
				-- dynamically scale the rectangle based on size
				g.DrawRectangle p_border 2 2 (size - 5) (size - 5) 
				#(bmp, g)
			)
			
			-- State 0: Unchecked (Empty Box)
			local base0 = drawBase brush_bg pen_border cb_size
			img_list.Images.Add base0[1]
			
			-- State 1: Checked (Solid Inner Box)
			local base1 = drawBase brush_bg pen_border cb_size
			local fill_margin = (cb_size / 4) as integer
			local fill_size = cb_size - (fill_margin * 2)
			base1[2].FillRectangle brush_fill fill_margin fill_margin fill_size fill_size 
			img_list.Images.Add base1[1]
			
			-- State 2: Mixed / Indeterminate (Horizontal Dash)
			local base2 = drawBase brush_bg pen_border cb_size
			local dash_margin = (cb_size / 5) as integer
			local dash_width = cb_size - (dash_margin * 2)
			local dash_height = amax 2 ((cb_size / 10) as integer)
			local dash_y = (cb_size / 2) - 1
			base2[2].FillRectangle brush_fill dash_margin dash_y dash_width dash_height 
			img_list.Images.Add base2[1]
			
			return img_list
		)

		/** * Centralized helper to update UI and master dictionary.
		 */
		function updateNodeState node state_int =
		(
			node.StateImageIndex = state_int
			node_states[node.Tag as string] = state_int
			applyNodeColor node state_int
		)

		/** * Traverses tree to return flat array of all UI nodes.
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

		/** * Recursively fills the TreeView.
		 */
		function populateTreeNode dict parent_collection parent_id_path =
		(
			for k in dict.keys do
			(
				local sub_dict = dict[k]
				local current_id = if parent_id_path == "" then k else (parent_id_path + "_" + k)
				
				local current_state = 0
				if hasDictValue node_states current_id then 
					current_state = node_states[current_id]
				else
					node_states[current_id] = current_state
				
				-- Hide mixed items if toggled off
				if (not show_mixed_items) and (current_state == 2) do continue
				
				local new_node = dotNetObject "System.Windows.Forms.TreeNode" k
				new_node.Tag = current_id 
				
				-- Setup node state and color
				new_node.StateImageIndex = current_state
				applyNodeColor new_node current_state
				
				if sub_dict.keys.count > 0 do (populateTreeNode sub_dict new_node.Nodes current_id)
				parent_collection.Add new_node
			)
		)
	
		/** * Recursively sets the checkbox state of all children.
		 */
		function setChildrenCheckboxState parent_node target_state =
		(
			local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
			
			for i = 0 to parent_node.Nodes.Count - 1 do
			(
				local child_node = parent_node.Nodes.Item[i]
				
				if child_node.ForeColor.ToArgb() != locked_color_argb then
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

		/** * Toggles visibility for mixed items and rebuilds UI.
		 */
		function toggleMixedItemsVisibility =
		(
			show_mixed_items = not show_mixed_items
			tv.BeginUpdate()
			clearCustomSelection()
			tv.Nodes.Clear()
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			tv.ExpandAll()
			tv.EndUpdate()
		)

		function getItemsByState target_state =
		(
			local matched_items = #()
			for k in node_states.keys where node_states[k] == target_state do append matched_items k
			return matched_items
		)

		function checkAll target_state =
		(
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
			
			for n in all_nodes where n.ForeColor.ToArgb() != locked_color_argb do
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

		function expandAllNodes = (tv.ExpandAll())
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
			clearCustomSelection()
			tv.Nodes.Clear()
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			tv.ExpandAll()
			
			tv.EndUpdate()
			is_updating = false
		)
		
		
		/* --- EVENTS --- */

		on tv BeforeSelect arg do
		(
			-- Makes native items 'unselectable' so our custom selection logic works cleanly
			arg.Cancel = true
		)

		on tv NodeMouseClick arg do
		(
			-- Right-Click Menu
			if arg.Button == arg.Button.Right do
			(
				local m_menu = dotNetObject "System.Windows.Forms.ContextMenu"
				
				local item_check  	= m_menu.MenuItems.Add("Check All (True)")
				local item_uncheck  = m_menu.MenuItems.Add("Uncheck All (False)")
				local item_mixed  	= m_menu.MenuItems.Add("Set All to Mixed")
				local item_sep1     = m_menu.MenuItems.Add("-")
				
				local vis_string    = if show_mixed_items then "Hide Mixed Items" else "Show Mixed Items"
				local item_tog_mix  = m_menu.MenuItems.Add(vis_string)
				local item_sep2     = m_menu.MenuItems.Add("-")
				
				local item_expand 	= m_menu.MenuItems.Add("Expand All")
				local item_collapse	= m_menu.MenuItems.Add("Collapse All")
				
				function onCheck   	s e = (tv_rollout.checkAll(1))
				function onUnCheck  s e = (tv_rollout.checkAll(0))
				function onMixed    s e = (tv_rollout.checkAll(2))
				function onTogMix   s e = (tv_rollout.toggleMixedItemsVisibility())
				function onExpand  	s e = (tv_rollout.expandAllNodes())
				function onCollapse s e = (tv_rollout.collapseAllNodes())
				
				dotNet.addEventHandler item_check	"Click" onCheck
				dotNet.addEventHandler item_uncheck	"Click" onUnCheck
				dotNet.addEventHandler item_mixed	"Click" onMixed
				dotNet.addEventHandler item_tog_mix	"Click" onTogMix
				dotNet.addEventHandler item_expand	"Click" onExpand
				dotNet.addEventHandler item_collapse "Click" onCollapse
				
				m_menu.Show tv (dotNetObject "System.Drawing.Point" arg.X arg.Y)
			)
			
			-- Left Click logic
			if arg.Button == arg.Button.Left and not is_updating do
			(
				local hit_info = tv.HitTest arg.X arg.Y
				
				-- 1. Clicking the Checkbox (StateImage)
				if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" then
				(
					local current_node = hit_info.Node
					local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
					
					-- Only toggle if it's not locked
					if current_node.ForeColor.ToArgb() != locked_color_argb then
					(
						is_updating = true 
						
						local new_state = 0
						
						-- If CTRL is pressed, toggle to Mixed(2). Otherwise, toggle True(1)/False(0).
						if keyboard.controlPressed then
							new_state = if current_node.StateImageIndex == 2 then 0 else 2
						else
							new_state = if current_node.StateImageIndex == 1 then 0 else 1
							
						-- Apply state change to all selected nodes if the clicked node is selected
						if (findItem selected_nodes current_node > 0) then
						(
							for sn in selected_nodes where sn.ForeColor.ToArgb() != locked_color_argb do
							(
								updateNodeState sn new_state
								if layerToggleCallback != undefined do layerToggleCallback new_state (sn.Tag as string)
							)
						)
						else
						(
							updateNodeState current_node new_state
							
							if layerToggleCallback != undefined do 
								layerToggleCallback new_state (current_node.Tag as string)
						)
							
						is_updating = false 
					)
				)
				-- 2. Clicking the Label (Multi-Select Logic)
				else if matchPattern (hit_info.Location.ToString()) pattern:"*Label*" then
				(
					local current_node = hit_info.Node
					local is_ctrl = keyboard.controlPressed
					local is_shift = keyboard.shiftPressed
					
					if is_shift and last_selected_node != undefined then
					(
						-- Shift Select
						if not is_ctrl do
						(
							for n in selected_nodes do n.BackColor = bg_color_obj
							selected_nodes = #()
						)
						
						local all_nodes = getAllNodes tv.Nodes
						local idx1 = findItem all_nodes last_selected_node
						local idx2 = findItem all_nodes current_node
						
						if idx1 > 0 and idx2 > 0 do
						(
							local start_idx = amin idx1 idx2
							local end_idx = amax idx1 idx2
							for i = start_idx to end_idx do
							(
								local n = all_nodes[i]
								appendIfUnique selected_nodes n
								n.BackColor = highlight_color_obj
							)
						)
					)
					else if is_ctrl then
					(
						-- Ctrl Select (Toggle)
						local idx = findItem selected_nodes current_node
						if idx > 0 then
						(
							deleteItem selected_nodes idx
							current_node.BackColor = bg_color_obj
						)
						else
						(
							appendIfUnique selected_nodes current_node
							current_node.BackColor = highlight_color_obj
							last_selected_node = current_node
						)
					)
					else
					(
						-- Normal Click
						for n in selected_nodes do n.BackColor = bg_color_obj
						selected_nodes = #(current_node)
						current_node.BackColor = highlight_color_obj
						last_selected_node = current_node
					)
				)
			)
		)

		on tv NodeMouseDoubleClick arg do
		(
			local hit_info = tv.HitTest arg.X arg.Y
			
			if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" do
			(
				local current_node = hit_info.Node
				local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
				
				if current_node.ForeColor.ToArgb() != locked_color_argb then
				(
					is_updating = true 
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
			clearCustomSelection()
			tv.Nodes.Clear()
			tv.Sorted = true
			
			-- Apply dynamic fonts
			tv.Font = dotNetObject "System.Drawing.Font" "Arial" font_size
			tv.ItemHeight = (amax #(checkbox_size + line_padding, font_size + line_padding)) as integer

			-- Disable native checkboxes and inject dynamic Tri-State images
			tv.CheckBoxes = false
			tv.StateImageList = createTriStateImageList checkbox_size
			
			tv.BackColor = bg_color_obj
			tv.LineColor = (dotNetClass "System.Drawing.Color").FromArgb 150 150 150
			
			if layer_names_keywords != undefined do 
				populateTreeNode layer_names_keywords tv.Nodes ""
			
			tv.ExpandAll()
			tv.ResumeLayout()
		)
	)
	
	--createDialog tv_rollout 
)