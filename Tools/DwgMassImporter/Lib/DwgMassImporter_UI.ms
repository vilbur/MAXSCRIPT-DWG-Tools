/*
    Description: UI and Dialog Methods for DWG Mass Importer
    Version: 0.60
*/

struct DwgMassImporter_UI
(
    settings, -- Reference to the global settings struct

    function loadSettings =
    (
        local s_group = getINISetting settings.ini_file "Settings" "GroupObjects"
        if (s_group != "") then ( settings.group_objects = (s_group == "true") )
        
        local s_flat = getINISetting settings.ini_file "Settings" "FixFlattenMesh"
        if (s_flat != "") then ( settings.fix_flatten_mesh = (s_flat == "true") )

        local s_prompt = getINISetting settings.ini_file "Settings" "ShowPrompt"
        if (s_prompt != "") then ( settings.show_prompt = (s_prompt == "true") )
    ),

    function saveSettings =
    (
        setINISetting settings.ini_file "Settings" "GroupObjects" (settings.group_objects as string)
        setINISetting settings.ini_file "Settings" "FixFlattenMesh" (settings.fix_flatten_mesh as string)
        setINISetting settings.ini_file "Settings" "ShowPrompt" (settings.show_prompt as string)
    ),

    function askRegexSettings =
    (
        loadSettings()

        -- Use a temporary global to safely bridge the MaxScript scope gap into the rollout
        ::g_DwgMassImporter_TempSettings = settings
        ::g_DwgMassImporter_RegexConfirmed = false

        rollout regex_rollout "IMPORT SETTINGS"
        (
            label lbl_desc "Modify imported layer names before parenting." align:#left
            label lbl1 "Search (Regex):" align:#left offset:[0, 10]
            edittext edt_search "" text:"" width:260
            label lbl2 "Replace:" align:#left offset:[0, 5]
            edittext edt_replace "" text:"" width:260
            
            checkbox chk_group "GROUP IMPORTED OBJECTS PER DWG" width:260 height:24 offset:[0, 10]
            checkbox chk_flatten "FIX FLATTEN MESH (EXTRACT BOTTOM SPLINES)" width:260 height:24 offset:[0, 5]
            checkbox chk_prompt "SHOW PROMPT ON FIRST FILE" width:260 height:24 offset:[0, 5]
            
            button btn_ok "Select Folder && Import" width:260 height:48 offset:[0, 10]
            
            on regex_rollout open do
            (
                edt_search.text = ::g_DwgMassImporter_TempSettings.regex_search
                edt_replace.text = ::g_DwgMassImporter_TempSettings.regex_replace
                chk_group.checked = ::g_DwgMassImporter_TempSettings.group_objects
                chk_flatten.checked = ::g_DwgMassImporter_TempSettings.fix_flatten_mesh
                chk_prompt.checked = ::g_DwgMassImporter_TempSettings.show_prompt
            )

            on btn_ok pressed do
            (
                ::g_DwgMassImporter_TempSettings.regex_search = edt_search.text
                ::g_DwgMassImporter_TempSettings.regex_replace = edt_replace.text
                ::g_DwgMassImporter_TempSettings.group_objects = chk_group.state
                ::g_DwgMassImporter_TempSettings.fix_flatten_mesh = chk_flatten.state
                ::g_DwgMassImporter_TempSettings.show_prompt = chk_prompt.state
                ::g_DwgMassImporter_RegexConfirmed = true
                destroyDialog regex_rollout
            )
        )

        createDialog regex_rollout width:300 height:300 modal:true
        
        if (::g_DwgMassImporter_RegexConfirmed) then
        (
            settings.regex_search = ::g_DwgMassImporter_TempSettings.regex_search
            settings.regex_replace = ::g_DwgMassImporter_TempSettings.regex_replace
            settings.group_objects = ::g_DwgMassImporter_TempSettings.group_objects
            settings.fix_flatten_mesh = ::g_DwgMassImporter_TempSettings.fix_flatten_mesh
            settings.show_prompt = ::g_DwgMassImporter_TempSettings.show_prompt
            saveSettings()
        )
        
        local result = ::g_DwgMassImporter_RegexConfirmed
        ::g_DwgMassImporter_TempSettings = undefined
        ::g_DwgMassImporter_RegexConfirmed = undefined
        return result
    ),

    function getImportDirectory =
    (
        local import_dir = undefined
        if (maxFilePath != "") then
        (
            local dwg_files = getFiles (maxFilePath + "*.dwg")
            if (dwg_files.count > 0) then import_dir = maxFilePath
        )
        if (import_dir == undefined) then
        (
            import_dir = getSavePath caption:"Select DWG Directory" initialDir:(getDir #import)
        )
        import_dir
    ),

    function askFilesToImport dwg_files =
    (
        local file_names = for f in dwg_files collect (filenameFromPath f)
        
        ::g_DwgMassImporter_TempIni = settings.ini_file
        ::g_DwgMassImporter_TempFileNames = file_names
        ::g_DwgMassImporter_FilesConfirmed = false
        ::g_DwgMassImporter_TempIndices = #{}

        rollout file_rollout "SELECT DWG FILES"
        (
            multilistbox mlb_files "DWG Files Found:" height:15
            button btn_import "Import Selected" width:260 height:48 offset:[0,10]

            on file_rollout open do
            (
                mlb_files.items = ::g_DwgMassImporter_TempFileNames
                local last_imported = getINISetting ::g_DwgMassImporter_TempIni "Settings" "LastImportedFiles"
                local initial_sel = #{}
                
                if (last_imported != "") then
                (
                    local last_arr = filterString last_imported "|"
                    for i = 1 to ::g_DwgMassImporter_TempFileNames.count do
                    (
                        if (findItem last_arr ::g_DwgMassImporter_TempFileNames[i] > 0) then append initial_sel i
                    )
                )
                
                if (initial_sel.isEmpty) then
                (
                    for i = 1 to ::g_DwgMassImporter_TempFileNames.count do append initial_sel i
                )
                
                mlb_files.selection = initial_sel
            )

            on btn_import pressed do
            (
                ::g_DwgMassImporter_TempIndices = mlb_files.selection
                ::g_DwgMassImporter_FilesConfirmed = true
                destroyDialog file_rollout
            )
        )

        createDialog file_rollout width:300 modal:true

        local selected_files = #()
        
        if (::g_DwgMassImporter_FilesConfirmed) then
        (
            local sel_names = #()
            for i in ::g_DwgMassImporter_TempIndices do
            (
                append selected_files dwg_files[i]
                append sel_names file_names[i]
            )
            
            local names_str = ""
            for i = 1 to sel_names.count do 
            (
                names_str += sel_names[i]
                if (i < sel_names.count) then names_str += "|"
            )
            setINISetting settings.ini_file "Settings" "LastImportedFiles" names_str
        )
        
        -- Cleanup globals
        ::g_DwgMassImporter_TempIni = undefined
        ::g_DwgMassImporter_TempFileNames = undefined
        ::g_DwgMassImporter_FilesConfirmed = undefined
        ::g_DwgMassImporter_TempIndices = undefined
        
        selected_files
    )
)
