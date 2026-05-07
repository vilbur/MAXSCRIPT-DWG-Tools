
-- Make sure your callback function is also declared globally before this script runs
-- global layerToggleCallback 

/** Layer tree generator
 */
function layerTreeGenerator =
(
	format "\n"; print ".layerTreeGenerator()"
	
	try(destroyDialog tvRollout)catch()

	rollout tvRollout "LYERS BY KEYWORDS" width:300 height:400
	(
		dotNetControl tv "System.Windows.Forms.TreeView" width:280 height:1440 pos:[10,10]

		-- Flag to prevent recursive loops safely
		local isUpdating = false 

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
				
				-- Only act if the state actually needs to change
				if childNode.Checked != state do
				(
					childNode.Checked = state
					
					-- FIRE CALLBACK FOR NESTED ITEMS:
					-- (If you don't want the callback to fire for children, comment out the next two lines)
					if layerToggleCallback != undefined do
						layerToggleCallback state (childNode.Tag as string)
				)
				
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
			
			-- Make sure the global variable is actually defined before populating
			if LAYER_NAMES_KEYWORDS != undefined do
				populateTreeNode LAYER_NAMES_KEYWORDS tv.Nodes ""
			
			--tv.ExpandAll()
			tv.ResumeLayout()
		)
	
		on tv AfterCheck arg do
		(
			-- Only run if we aren't already running via script
			if not isUpdating do
			(
				isUpdating = true -- Lock the event
				
				try
				(
					local node = arg.Node
					local newState = node.Checked
					
					-- 1. Fire the callback for the clicked parent node
					if layerToggleCallback != undefined do
						layerToggleCallback newState (node.Tag as string)
					
					-- 2. Freeze the TreeView UI to prevent visual glitches/dropped events
					tv.BeginUpdate() 
					
					-- 3. Propagate down the tree
					setChildrenCheckboxState node newState
					
					-- 4. Unfreeze the TreeView UI
					tv.EndUpdate()
				)
				catch
				(
					-- If your callback crashes, this ensures the rollout doesn't get permanently broken
					format "*** Error in TreeView AfterCheck: % ***\n" (getCurrentException())
				)
				
				isUpdating = false -- Unlock the event
			)
		)
	)

	--createDialog tvRollout
)