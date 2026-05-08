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
		dotNetControl tv "System.Windows.Forms.TreeView" width:280 height:380 pos:[10,10]
	
		local is_updating = false 
		local locked_ids = #("A", "mainx_suba_foo") 

		/** * Traverses the tree recursively to return a flat array of all nodes.
		 */
		function  getAllNodes parent_collection out_array:undefined =
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
		function  populateTreeNode dict parent_collection parent_id_path =
		(
			for k in dict.keys do
			(
				local sub_dict = dict[k]
				local new_node = dotNetObject "System.Windows.Forms.TreeNode" k
				local current_id = if parent_id_path == "" then k else (parent_id_path + "_" + k)
				
				new_node.Tag = current_id 
				
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
		function  setChildrenCheckboxState parent_node state =
		(
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for i = 0 to parent_node.Nodes.Count - 1 do
			(
				local child_node = parent_node.Nodes.Item[i]
				
				if child_node.ForeColor.ToArgb() != gray_color_argb then
				(
					if child_node.Checked != state do
					(
						child_node.Checked = state
						if layerToggleCallback != undefined do layerToggleCallback state (child_node.Tag as string)
					)
					setChildrenCheckboxState child_node state 
				)
				else
				(
					setChildrenCheckboxState child_node state
				)
			)
		)

		/* --- REMOTE API FUNCTIONS --- */

		/** * Sets the checked state for all unlockable items in the tree.
		 */
		function  checkAll state =
		(
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for n in all_nodes where n.ForeColor.ToArgb() != gray_color_argb do
			(
				if n.Checked != state do
				(
					n.Checked = state
					if layerToggleCallback != undefined do layerToggleCallback state (n.Tag as string)
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		/** * Expands all nodes in the tree.
		 */
		function  expandAllNodes = (tv.ExpandAll())

		/** * Collapses all nodes in the tree.
		 */
		function  collapseAllNodes = (tv.CollapseAll())

		/** * Checks items that match any of the provided string masks (wildcards supported).
		 */
		function  checkByMasks masks state =
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
				
				if is_matched and n.Checked != state do
				(
					n.Checked = state
					if layerToggleCallback != undefined do layerToggleCallback state node_id
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		/** * Saves the current checked states of all nodes to an INI file.
		 */
		function  saveStateToIni ini_path =
		(
			local all_nodes = getAllNodes tv.Nodes
			for n in all_nodes do
			(
				setINISetting ini_path "LayerStates" (n.Tag as string) (n.Checked as string)
			)
		)

		/** * Loads checked states from an INI file and applies them to the tree.
		 */
		function  loadStateFromIni ini_path =
		(
			if not (doesFileExist ini_path) do return false
			
			is_updating = true
			tv.BeginUpdate()
			local all_nodes = getAllNodes tv.Nodes
			local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
			
			for n in all_nodes where n.ForeColor.ToArgb() != gray_color_argb do
			(
				local val = getINISetting ini_path "LayerStates" (n.Tag as string)
				if val != "" do
				(
					local target_state = (val == "true")
					if n.Checked != target_state do
					(
						n.Checked = target_state
						if layerToggleCallback != undefined do layerToggleCallback target_state (n.Tag as string)
					)
				)
			)
			tv.EndUpdate()
			is_updating = false
		)

		/* --- EVENTS --- */

		on tv MouseClick arg do
		(
			-- Create Right-Click Menu
			if arg.Button == arg.Button.Right do
			(
				local m_menu = dotNetObject "System.Windows.Forms.ContextMenu"
				local item_check  	= m_menu.MenuItems.Add("Check All")
				local item_uncheck  	= m_menu.MenuItems.Add("Uncheck All")
				local item_expand 	= m_menu.MenuItems.Add("Expand All X")
				local item_collapse	= m_menu.MenuItems.Add("Collapse All")
				
				function  onCheck   	s e = (tv_rollout.checkAll(true))
				function  onUnCheck   	s e = (tv_rollout.checkAll(false))

				function  onExpand  	s e = (tv_rollout.expandAllNodes())
				function  onCollapse 	s e = (tv_rollout.collapseAllNodes())
				
				dotNet.addEventHandler item_check	"Click" onCheck
				dotNet.addEventHandler item_uncheck	"Click" onUnCheck
				dotNet.addEventHandler item_expand	"Click" onExpand
				dotNet.addEventHandler item_collapse	"Click" onCollapse
				
				m_menu.Show tv (dotNetObject "System.Drawing.Point" arg.X arg.Y)
			)
		)

		on tv AfterCheck arg do
		(
			-- Single click behavior
			if not is_updating do
			(
				local current_node = arg.Node
				local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
				
				if current_node.ForeColor.ToArgb() == gray_color_argb then
				(
					is_updating = true
					current_node.Checked = not current_node.Checked 
					is_updating = false
				)
				else
				(
					is_updating = true 
					if layerToggleCallback != undefined do 
						layerToggleCallback current_node.Checked (current_node.Tag as string)
					is_updating = false 
				)
			)
		)

		on tv NodeMouseDoubleClick arg do
		(
			-- Double click on checkbox: Toggle nested items
			local hit_info = tv.HitTest arg.X arg.Y
			
			if matchPattern (hit_info.Location.ToString()) pattern:"*StateImage*" do
			(
				local current_node = hit_info.Node
				local gray_color_argb = (dotNetClass "System.Drawing.Color").Gray.ToArgb()
				
				if current_node.ForeColor.ToArgb() == gray_color_argb then
				(
					is_updating = true
					current_node.Checked = not current_node.Checked 
					is_updating = false
				)
				else
				(
					is_updating = true 
					local new_state = current_node.Checked
					if layerToggleCallback != undefined do 
						layerToggleCallback new_state (current_node.Tag as string)
					
					tv.BeginUpdate() 
					setChildrenCheckboxState current_node new_state
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
			tv.CheckBoxes = true
			
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