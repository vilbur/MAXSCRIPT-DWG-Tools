
global LAYER_NAMES_KEYWORDS
global tvRollout

/** Layer tree generator
 */
function layerTreeGenerator =
(
	format "\n"; print ".layerTreeGenerator()"
	--format "_layer_names: %\n" _layer_names
	-- 3. Define the Rollout
	rollout tvRollout "Dark Layer Tree View" width:300 height:400
	(
		dotNetControl tv "System.Windows.Forms.TreeView" width:280 height:380 pos:[10,10]
	
		fn populateTreeNode dict parentCollection parentIDPath =
		(
			for k in dict.keys do
			(
				local subDict = dict[k]
				local newNode = dotNetObject "System.Windows.Forms.TreeNode" k
				
				local currentID = if parentIDPath == "" then k else (parentIDPath + "_" + k)
				newNode.Tag = currentID 
				
				if subDict.keys.count > 0 do
				(
					populateTreeNode subDict newNode.Nodes currentID
				)
				
				parentCollection.Add newNode
			)
		)
	
		-- Recursive function to apply checkbox state
		fn setChildrenCheckboxState node state =
		(
			for i = 0 to node.Nodes.Count - 1 do
			(
				local childNode = node.Nodes.Item[i]
				
				-- Change the state. This WILL fire AfterCheck, but arg.Action will be "Unknown" 
				-- so it won't cause an infinite loop.
				childNode.Checked = state
				
				-- Always recurse to ensure deep children are caught
				setChildrenCheckboxState childNode state 
			)
		)
	
		on tvRollout open do
		(
			tv.SuspendLayout()
			tv.Nodes.Clear()
			
			tv.CheckBoxes = true
			
			local colorClass = dotNetClass "System.Drawing.Color"
			tv.BackColor = colorClass.FromArgb 40 40 40
			tv.ForeColor = colorClass.FromArgb 220 220 220
			tv.LineColor = colorClass.FromArgb 150 150 150
			
			populateTreeNode LAYER_NAMES_KEYWORDS tv.Nodes ""
			
			tv.ExpandAll()
			tv.ResumeLayout()
		)
	
		on tv AfterCheck arg do
		(
			-- Get the .NET enum for an "Unknown" action (which means a script triggered it)
			local actionUnknown = (dotNetClass "System.Windows.Forms.TreeViewAction").Unknown
			
			-- ONLY run the logic if the user actually clicked it with a mouse or keyboard
			if arg.Action != actionUnknown do
			(
				local node = arg.Node
				local newState = node.Checked
				
				-- Fire the callback
				layerToggleCallback newState (node.Tag as string)
				
				-- Propagate down the tree
				setChildrenCheckboxState node newState
			)
		)
	)
)


 --Create the rollout dialog