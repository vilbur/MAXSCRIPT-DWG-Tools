/*
    Function: importDWG_Silently
    Description: Imports a DWG file dynamically, generating the INI if it's missing,
                 and dropping the deprecated 'using:DWGIMP' requirement.
*/
fn importDWG_Silently dwg_file deriveBy:0 curveSteps:10 weld:true weldThreshold:0.01 autoSmooth:true smoothAngle:15.0 =
(
    -- 1. Validate that the target DWG exists
    if not (doesFileExist dwg_file) do (
        format "Error: DWG file does not exist: %\n" dwg_file
        return false
    )

    -- 2. Define the INI path (Modern Max uses plugcfg_ln for local configs)
    local dwgIniFile = (getDir #plugcfg_ln) + @"\dwgimp.ini"

    -- 3. Safely create a backup ONLY if the original INI already exists
    if (doesFileExist dwgIniFile) do (
        local backupIniFile = dwgIniFile + ".default"
        if not (doesFileExist backupIniFile) do (
            copyFile dwgIniFile backupIniFile
            format "Created backup of existing DWG INI at: %\n" backupIniFile
        )
    )

    -- Helper function to convert booleans to "1" or "0" for the INI
    fn boolToString val = if val then "1" else "0"

    -- 4. Overwrite (or create) the import settings in the INI file
    -- If dwgimp.ini does not exist, setINISetting will build it right now.
    setINISetting dwgIniFile "Options" "DeriveBy" (deriveBy as string)
    setINISetting dwgIniFile "Options" "CurveSteps" (curveSteps as string)
    setINISetting dwgIniFile "Options" "Weld" (boolToString weld)
    setINISetting dwgIniFile "Options" "WeldThreshold" (weldThreshold as string)
    setINISetting dwgIniFile "Options" "AutoSmooth" (boolToString autoSmooth)
    setINISetting dwgIniFile "Options" "SmoothAngle" (smoothAngle as string)

    -- 5. Execute the import silently WITHOUT the deprecated 'using:DWGIMP' parameter.
    -- Max will automatically read the extension and use the INI we just generated.
    --local importResult = importFile dwg_file #noPrompt
    local importResult = importFile dwg_file
    
    if importResult then (
        format "Successfully imported: %\n" dwg_file
    ) else (
        format "Failed to import: %\n" dwg_file
    )
    
    return importResult
)

importDWG_Silently @"w:\SIGNTECH\HRAD\VYKRESY\ACAD-14 + 15 - Pohledy - REXECPORT.dwg"