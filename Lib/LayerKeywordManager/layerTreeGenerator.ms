global layer_names_keywords
global tv_rollout
-- global layerToggleCallback 

/** * Main function to initialize and display the layer tree rollout.
 */
function layerTreeGenerator =
(
	format "\n"; print ".layerTreeGenerator()"
	
	try(destroyDialog tv_rollout)catch()

	rollout tv_rollout "Layers Manager" width:400 height:1140
	(
		dotNetControl tv "System.Windows.Forms.TreeView" width:380 height:1400 pos:[10,10]
	
		local is_updating = false
		local locked_ids = #()
		local tristate_ids = #()
		local node_states = Dictionary #string
		local hidden_ids = #() 
		
		local checkbox_size = 18
		local font_size = 12
		local line_padding = 2

		local selected_nodes = #()
		local last_selected_node = undefined
		local context_node = undefined
		
		local bg_color_obj = (dotNetClass "System.Drawing.Color").FromArgb 40 40 40
		local highlight_color_obj = (dotNetClass "System.Drawing.Color").FromArgb 70 130 180

		/* --- INTERNAL HELPERS --- */

		function clearCustomSelection =
		(
			for n in selected_nodes do try(n.BackColor = bg_color_obj)catch()
			selected_nodes = #()
			last_selected_node = undefined
		)

		function applyNodeColor node state_int =
		(
			local current_id = node.Tag as string
			local color_class = dotNetClass "System.Drawing.Color"
			if (findItem locked_ids current_id > 0) then
			(
				node.ForeColor = color_class.FromArgb 100 100 100
			)
			else
			(
				case state_int of
				(
					0: node.ForeColor = color_class.FromArgb 220 220 220
					1: node.ForeColor = color_class.FromArgb 150 220 150
					2: node.ForeColor = color_class.Gray
				)
			)
		)

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
			
			fn drawBase b_bg p_border size =
			(
				local bmp = dotNetObject "System.Drawing.Bitmap" size size
				local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
				g.FillRectangle b_bg 0 0 size size
				g.DrawRectangle p_border 2 2 (size - 5) (size - 5) 
				#(bmp, g)
			)
			local base0 = drawBase brush_bg pen_border cb_size
			img_list.Images.Add base0[1]
			local base1 = drawBase brush_bg pen_border cb_size
			local fill_margin = (cb_size / 4) as integer
			local fill_size = cb_size - (fill_margin * 2)
			base1[2].FillRectangle brush_fill fill_margin fill_margin fill_size fill_size 
			img_list.Images.Add base1[1]
			local base2 = drawBase brush_bg pen_border cb_size
			local dash_margin = (cb_size / 5) as integer
			local dash_width = cb_size - (dash_margin * 2)
			local dash_height = amax 2 ((cb_size / 10) as integer)
			local dash_y = (cb_size / 2) - 1
			base2[2].FillRectangle brush_fill dash_margin dash_y dash_width dash_height 
			img_list.Images.Add base2[1]
			return img_list
		)

		function updateNodeState node state_int =
		(
			node.StateImageIndex = state_int
			node_states[node.Tag as string] = state_int
			applyNodeColor node state_int
		)

		function getAllNodes parent_collection out_array:undefined =
		(
			if out_array == undefined then out_array = #()
			for i = 0 to parent_collection.Count - 1 do
			(
				local current_node = parent_collection.Item[i]
				append out_array current_node
				getAllNodes current_node.Nodes out_array:out_array
			)
			out_array
		)

		function populateTreeNode dict parent_collection parent_id_path =
		(
			for k in dict.keys do
			(
				local sub_dict = dict[k]
				local current_id = if parent_id_path == "" then k else (parent_id_path + "_" + k)
				local current_state = 0
				
				if hasDictValue node_states current_id then 
				(
					current_state = node_states[current_id]
				)
				else
				(
					node_states[current_id] = current_state
				)
				
				if (findItem hidden_ids current_id > 0) then continue
				
				local new_node = dotNetObject "System.Windows.Forms.TreeNode" k
				new_node.Tag = current_id 
				new_node.StateImageIndex = current_state
				applyNodeColor new_node current_state
				
				if (isKindOf sub_dict Dictionary) then
				(
					if sub_dict.keys.count > 0 then 
						populateTreeNode sub_dict new_node.Nodes current_id
				)
				else if sub_dict == #FREEZED then
				(
					appendIfUnique tristate_ids current_id
					node_states[current_id] = 2
					new_node.StateImageIndex = 2
					applyNodeColor new_node 2
				)
				
				parent_collection.Add new_node
			)
		)
	
		function setChildrenCheckboxState parent_node target_state =
		(
			local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
			for i = 0 to parent_node.Nodes.Count - 1 do
			(
				local child_node = parent_node.Nodes.Item[i]
				if child_node.ForeColor.ToArgb() != locked_color_argb then
				(
					if child_node.StateImageIndex != target_state then
					(
						updateNodeState child_node target_state
						if layerToggleCallback != undefined then layerToggleCallback target_state (child_node.Tag as string)
					)
					setChildrenCheckboxState child_node target_state 
				)
				else
				(
					setChildrenCheckboxState child_node target_state
				)
			)
		)

		/* --- PUBLIC API (Rollout Methods) --- */

		function expandTrueNodes =
		(
			tv.CollapseAll()
			local all_nodes = getAllNodes tv.Nodes
			for n in all_nodes do
			(
				if n.StateImageIndex == 1 then
				(
					n.EnsureVisible()
				)
			)
		)

		function getItemsByState target_state =
		(
			local matched_items = #()
			for k in node_states.keys where node_states[k] == target_state do append matched_items k
			return matched_items
		)

		function hideSelectedItems =
		(
			if selected_nodes.count > 0 then
			(
				for n in selected_nodes do appendIfUnique hidden_ids (n.Tag as string)
				tv.BeginUpdate()
				clearCustomSelection()
				tv.Nodes.Clear()
				if layer_names_keywords != undefined then populateTreeNode layer_names_keywords tv.Nodes ""
				expandTrueNodes()
				tv.EndUpdate()
			)
		)

		function unhideAllItems =
		(
			hidden_ids = #()
			tv.BeginUpdate()
			clearCustomSelection()
			tv.Nodes.Clear()
			if layer_names_keywords != undefined then populateTreeNode layer_names_keywords tv.Nodes ""
			expandTrueNodes()
			tv.EndUpdate()
		)

		function checkAll target_state =
		(
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
			for n in all_nodes where n.ForeColor.ToArgb() != locked_color_argb do
			(
				if n.StateImageIndex != target_state then
				(
					updateNodeState n target_state
					if layerToggleCallback != undefined then layerToggleCallback target_state (n.Tag as string)
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		function expandAllNodes = (tv.ExpandAll())
		function collapseAllNodes = (tv.CollapseAll())

		function saveStateToIni ini_path =
		(
			for k in node_states.keys do setINISetting ini_path "LayerStates" k (node_states[k] as string)
		)

		function loadStateFromIni ini_path =
		(
			if not (doesFileExist ini_path) then return false
			is_updating = true
			tv.BeginUpdate()
			
			local keys_in_ini = getINISetting ini_path "LayerStates"
			
			-- 1. Apply INI states to memory
			for k in keys_in_ini do
			(
				local val = getINISetting ini_path "LayerStates" k
				local int_val = val as integer
				if int_val != undefined then
				(
					local old_val = if hasDictValue node_states k then node_states[k] else -1 
					if old_val != int_val then
					(
						node_states[k] = int_val
						if layerToggleCallback != undefined then layerToggleCallback int_val k
					)
				)
			)
			
			clearCustomSelection()
			tv.Nodes.Clear()
			if layer_names_keywords != undefined then populateTreeNode layer_names_keywords tv.Nodes ""
			
			-- 2. Create missing items ONLY if their INI value is 2
			local all_nodes = getAllNodes tv.Nodes
			local all_tags = #()
			for n in all_nodes do append all_tags (n.Tag as string)
			
			for k in keys_in_ini do
			(
				local int_val = (getINISetting ini_path "LayerStates" k) as integer
				if int_val == 2 then
				(
					if (findItem all_tags k) == 0 then
					(
						if (findItem hidden_ids k) == 0 then
						(
							local new_node = dotNetObject "System.Windows.Forms.TreeNode" k
							new_node.Tag = k
							new_node.StateImageIndex = 2
							applyNodeColor new_node 2
							tv.Nodes.Add new_node
						)
					)
				)
			)
			
			expandTrueNodes()
			tv.EndUpdate()
			is_updating = false
		)
		
		/* --- EVENTS --- */

		on tv BeforeSelect arg do (arg.Cancel = true)

		on tv NodeMouseClick arg do
		(
			if arg.Button == arg.Button.Right then
			(
				local hit_info = tv.HitTest arg.X arg.Y
				context_node = hit_info.Node 
				local m_menu = dotNetObject "System.Windows.Forms.ContextMenu"
				
				local item_check = m_menu.MenuItems.Add("Check All (True)")
				local item_uncheck = m_menu.MenuItems.Add("Uncheck All (False)")
				local item_mixed = m_menu.MenuItems.Add("Set All to Mixed")
				m_menu.MenuItems.Add("-")
				local item_hide = m_menu.MenuItems.Add("Hide Selected")
				local item_unhide = m_menu.MenuItems.Add("Unhide All")
				m_menu.MenuItems.Add("-")
				
				local expand_title = if selected_nodes.count > 1 then "Expand Selected" else "Expand All"
				local collapse_title = if selected_nodes.count > 1 then "Collapse Selected" else "Collapse All"
				local item_exp = m_menu.MenuItems.Add(expand_title)
				local item_col = m_menu.MenuItems.Add(collapse_title)
				m_menu.MenuItems.Add("-")
				local item_same = m_menu.MenuItems.Add("Select By Same State")
				
				fn onMenuClick s e = (
					case s.Text of (
						"Check All (True)": tv_rollout.checkAll(1)
						"Uncheck All (False)": tv_rollout.checkAll(0)
						"Set All to Mixed": tv_rollout.checkAll(2)
						"Hide Selected": tv_rollout.hideSelectedItems()
						"Unhide All": tv_rollout.unhideAllItems()
						"Select By Same State": (
							local ref = if tv_rollout.selected_nodes.count > 0 then tv_rollout.selected_nodes[1] else tv_rollout.context_node
							if ref != undefined then (
								local ts = ref.StateImageIndex
								tv_rollout.clearCustomSelection()
								for n in (tv_rollout.getAllNodes tv_rollout.tv.Nodes) where n.StateImageIndex == ts do (
									append tv_rollout.selected_nodes n
									n.BackColor = tv_rollout.highlight_color_obj
								)
							)
						)
						default: (
							if (matchPattern s.Text pattern:"Expand*") then (
								if tv_rollout.selected_nodes.count > 1 then (for n in tv_rollout.selected_nodes do n.ExpandAll()) else tv_rollout.expandAllNodes()
							) else if (matchPattern s.Text pattern:"Collapse*") then (
								if tv_rollout.selected_nodes.count > 1 then (for n in tv_rollout.selected_nodes do n.Collapse()) else tv_rollout.collapseAllNodes()
							)
						)
					)
				)
				
				local items = #(item_check, item_uncheck, item_mixed, item_hide, item_unhide, item_exp, item_col, item_same)
				for i in items do dotNet.addEventHandler i "Click" onMenuClick
				
				m_menu.Show tv (dotNetObject "System.Drawing.Point" arg.X arg.Y)
			)
			
			if arg.Button == arg.Button.Left and not is_updating then
			(
				local hit_info = tv.HitTest arg.X arg.Y
				if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" then
				(
					local current_node = hit_info.Node
					local locked_color_argb = ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb()
					if current_node.ForeColor.ToArgb() != locked_color_argb then
					(
						is_updating = true 
						local new_state = if keyboard.controlPressed then (if current_node.StateImageIndex == 2 then 0 else 2) else (if current_node.StateImageIndex == 1 then 0 else 1)
						if (findItem selected_nodes current_node > 0) then (
							for sn in selected_nodes where sn.ForeColor.ToArgb() != locked_color_argb do (
								updateNodeState sn new_state
								if layerToggleCallback != undefined then layerToggleCallback new_state (sn.Tag as string)
							)
						) else (
							updateNodeState current_node new_state
							if layerToggleCallback != undefined then layerToggleCallback new_state (current_node.Tag as string)
						)
						is_updating = false 
					)
				)
				else if matchPattern (hit_info.Location.ToString()) pattern:"*Label*" then
				(
					local current_node = hit_info.Node
					if keyboard.shiftPressed and last_selected_node != undefined then (
						if not keyboard.controlPressed then (for n in selected_nodes do n.BackColor = bg_color_obj; selected_nodes = #())
						local all = getAllNodes tv.Nodes
						local idx1 = findItem all last_selected_node
						local idx2 = findItem all current_node
						if idx1 > 0 and idx2 > 0 then (
							for i = (amin idx1 idx2) to (amax idx1 idx2) do (
								appendIfUnique selected_nodes all[i]
								all[i].BackColor = highlight_color_obj
							)
						)
					) else if keyboard.controlPressed then (
						local idx = findItem selected_nodes current_node
						if idx > 0 then (deleteItem selected_nodes idx; current_node.BackColor = bg_color_obj) 
						else (appendIfUnique selected_nodes current_node; current_node.BackColor = highlight_color_obj; last_selected_node = current_node)
					) else (
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
			if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" then
			(
				local current_node = hit_info.Node
				if current_node.ForeColor.ToArgb() != ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100).ToArgb() then
				(
					is_updating = true 
					tv.BeginUpdate() 
					setChildrenCheckboxState current_node current_node.StateImageIndex
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
			tv.Font = dotNetObject "System.Drawing.Font" "Arial" font_size
			tv.ItemHeight = (amax #(checkbox_size + line_padding, font_size + line_padding)) as integer
			tv.CheckBoxes = false
			tv.StateImageList = createTriStateImageList checkbox_size
			tv.BackColor = bg_color_obj
			tv.LineColor = (dotNetClass "System.Drawing.Color").FromArgb 150 150 150
			if layer_names_keywords != undefined then populateTreeNode layer_names_keywords tv.Nodes ""
			--expandTrueNodes()
			tv.ResumeLayout()
		)
	)
)