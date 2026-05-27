filein( getFilenamePath(getSourceFileName()) + "/Lib/ExtractBottomSplines.ms" )	--"./Lib/ExtractBottomSplines.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/DwgMassImporter_Methods.ms" )	--"./Lib/DwgMassImporter_Methods.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/DwgMassImporter_UI.ms" )	--"./Lib/DwgMassImporter_UI.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/resetVievporWorkaround.ms" )	--"./Lib/resetVievporWorkaround.ms"

/*
    Description: Main execution file for DWG Mass Importer
    Version: 0.55
*/



struct DwgMassImporter_Settings (
    regex_search = "^.*?_",
    regex_replace = "",
    group_objects = false,
    fix_flatten_mesh = true,
    ini_file = (getDir #userscripts) + "\\DwgMassImporter.ini"
)

/* Main Application Struct */ 
struct DwgMassImporter_Main (
    settings = DwgMassImporter_Settings(),
    ui,
    methods,
    
    function run = (
		
        -- Initialize modules passing the shared settings object
        ui = DwgMassImporter_UI settings:settings
        methods = DwgMassImporter_Methods settings:settings
        
        if (not ui.askRegexSettings()) do return false
        
        local target_dir = ui.getImportDirectory()
        if (target_dir == undefined) do (
            messageBox "No folder selected."
            return false
        )
        
        local dwg_files = getFiles (target_dir + "\\*.dwg")
        if (dwg_files.count == 0) do (
            messageBox "No DWG files found."
            return false
        )
        
        local files_to_import = dwg_files
        
        if (dwg_files.count > 1) do (
            files_to_import = ui.askFilesToImport dwg_files
            if (files_to_import.count == 0) do return false
        )
		
        disableSceneRedraw()
        
		
        for f in files_to_import do (
            methods.importDwgFile f
        )
		
        enableSceneRedraw()
		
        completeRedraw()
        
        resetVievporWorkaround()

        -- Open Layer Explorer on end of import
        try(macros.run "Scene Explorer" "LayerExplorer") catch(try(macros.run "Layers" "LayerManager")catch())
        
        --messageBox ("Import completed successfully!\n\nImported DWG files: " + (files_to_import.count as string))
		format "\nIMPORTED DWG FILES: %" (files_to_import.count as string))
    )
)

-- 5. Execute
(DwgMassImporter_Main()).run()