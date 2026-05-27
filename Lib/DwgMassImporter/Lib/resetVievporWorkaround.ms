/** Remerge imported scene reset vievpor workaround

	What it does: Saves the scene,
	resets 3ds Max,
	and merges everything back into a clean workspace.
	Why it's needed: Massive scene bounding boxes can corrupt an orthographic/isometric viewport's math matrix to infinity.
	Because this corruption gets permanently baked into the file's binary data,
	a full scene reset and asset merge is the only way to completely wipe the broken viewport memory.  

*/ 

fn resetVievporWorkaround =
(
    local fullPath = ""
    local isTemp = false
    
    -- Check if the file has a name (has been saved)
    if (maxFileName == "") then
    (
        -- Save to a temporary file in the user's temp directory
        fullPath = getDir #temp + "\\temp_viewport_rescue.max"
        isTemp = true
    )
    else
    (
        fullPath = maxFilePath + maxFileName
    )
    
    --if (queryBox "This will automate your workaround:\n1. Save the current file\n2. Reset 3ds Max\n3. Merge everything back in\n\nProceed?" title:"Nuclear Scene Clean") do
    (
        -- 1. Save current scene (either to real path or temp path)
        saveMaxFile fullPath clearNeedSaveFlag:true
        
        -- 2. Reset scene (Purges all broken viewport data)
        resetMaxFile #noPrompt
        
        -- 3. Merge the saved scene back in
        mergeMAXFile fullPath #mergeDups #useMergedMtlDups #alwaysReparent
        
        -- 4. Overwrite original file (ONLY if it was previously saved by the user)
        if not isTemp do
        (
            saveMaxFile fullPath clearNeedSaveFlag:true
        )
        
        completeRedraw()
        --messagebox "Scene successfully reset and merged!\n\nYour viewports are totally factory-fresh." title:"Success"
    )
)