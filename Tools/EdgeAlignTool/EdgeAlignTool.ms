global EdgeAlignTool
global launchEdgeAlignTool

fn launchEdgeAlignTool =
(
    try(destroyDialog EdgeAlignTool)catch()

    rollout EdgeAlignTool "Edge Aligner & Folder v16" width:250
    (
        group "1. Assigned Shapes" (
            dotNetControl lbl_srcName "System.Windows.Forms.Label" width:230 height:20 align:#left tooltip:"Source object. This object will move."
            dotNetControl lbl_tgtName "System.Windows.Forms.Label" width:230 height:20 align:#left tooltip:"Target object. This object stays static."
            
            label lbl_pad "" height:2 
            
            button btn_swap "Swap Source <-> Target" width:220 height:32 tooltip:"Reverts position, swaps objects, and automatically realigns."
        )

        group "2. Snap Edges" (
            label lbl_info "Select objects, then click below!" align:#center
            checkbox chk_2d "2D Mode (Flatten Z / No Tilt)" checked:false align:#center tooltip:"Ignores Z-height differences between points so shapes stay perfectly flat."
            
            button btn_pick "Align This There" width:220 height:32 enabled:true tooltip:"Grabs current selection. 1-2: ALIGN THIS Start/End. 3-4: ALIGN THERE Start/End."
        )

        group "3. Adjust Hinge / Fold" (
            spinner spn_angle "Angle:" range:[-360,360,90.0] type:#float width:100 align:#left across:2 enabled:false tooltip:"Fold the shape along the hinge."
            button btn_flip "Flip 180°" width:80 height:32 align:#right enabled:false tooltip:"Rotates the object 180 degrees around the hinge."
            
            button btn_rot90 "+90°" width:65 height:32 across:3 enabled:false tooltip:"Add 90 degrees."
            button btn_rotM90 "-90°" width:65 height:32 enabled:false tooltip:"Subtract 90 degrees."
            button btn_rot0 "Flush (0°)" width:65 height:32 enabled:false tooltip:"Reset to flush alignment."
        )

        local srcNode, tgtNode
        local pSrc1, pSrc2, pTgt1, pTgt2
        local origTransform

        fn applyColor node clr = (
            if isValidNode node do (
                node.wirecolor = clr
                for c in node.children do applyColor c clr
            )
        )

        fn updateLabels = (
            if srcNode != undefined and isValidNode srcNode then (
                lbl_srcName.Text = "Source - Align This: " + srcNode.name
                applyColor srcNode (color 0 255 0) 
            ) else (
                lbl_srcName.Text = "Source - Align This: None"
            )

            if tgtNode != undefined and isValidNode tgtNode then (
                lbl_tgtName.Text = "Target - Align There: " + tgtNode.name
                applyColor tgtNode (color 80 170 255) 
            ) else (
                lbl_tgtName.Text = "Target - Align There: None"
            )
        )

        -- Helper to strictly climb the hierarchy and find the group head if the object is inside a group
        fn getTopGroupHead obj = (
            if obj == undefined or not isValidNode obj do return undefined
            local current = obj
            while isGroupMember current and current.parent != undefined do (
                current = current.parent
            )
            if isGroupHead current then return current else return obj
        )

        fn assignSelection = (
            local sel = getCurrentSelection()
            
            if sel.count >= 2 then (
                -- STRICT SELECTION ORDER: 1st is Source, 2nd is Target
                srcNode = getTopGroupHead sel[1]
                tgtNode = getTopGroupHead sel[2]
            ) 
            else if sel.count == 1 then (
                srcNode = getTopGroupHead sel[1]
            )
            
            updateLabels()
            
            -- Ensure both are valid and they aren't accidentally the exact same group
            return (srcNode != undefined and tgtNode != undefined and srcNode != tgtNode)
        )

        fn updateAlignment =
        (
            if srcNode == undefined or tgtNode == undefined or not isValidNode srcNode or not isValidNode tgtNode do return false
            if classOf pSrc1 != Point3 or classOf pSrc2 != Point3 or classOf pTgt1 != Point3 or classOf pTgt2 != Point3 do return false

            local vX_s_raw = pSrc2 - pSrc1
            local vX_t_raw = pTgt2 - pTgt1
            local vZ_s_raw = origTransform.row3 
            local vZ_t_raw = tgtNode.transform.row3

            if chk_2d.checked do (
                vX_s_raw.z = 0
                vX_t_raw.z = 0
                vZ_s_raw = [0,0,1] 
                vZ_t_raw = [0,0,1]
            )

            local vX_s = normalize vX_s_raw
            local vZ_s = normalize vZ_s_raw
            local vY_s = normalize (cross vZ_s vX_s)
            vZ_s = normalize (cross vX_s vY_s) 
            local mSrc = matrix3 vX_s vY_s vZ_s pSrc1

            local vX_t = normalize vX_t_raw
            local vZ_t = normalize vZ_t_raw
            local vY_t = normalize (cross vZ_t vX_t)
            vZ_t = normalize (cross vX_t vY_t) 
            local mTgt = matrix3 vX_t vY_t vZ_t pTgt1

            local tm = origTransform * inverse(mSrc) * mTgt

            local angleOffset = spn_angle.value
            if angleOffset != 0.0 do (
                local r = (angleAxis angleOffset vX_t) as matrix3
                local offsetTm = transMatrix (-pTgt1)
                local restoreTm = transMatrix pTgt1
                tm = tm * offsetTm * r * restoreTm
            )

            undo "Edge Align" on (
                srcNode.transform = tm
            )
            
            redrawViews()
            
            return true
        )

        on EdgeAlignTool open do (
            local bg = colorMan.getColor #background
            local r = (bg[1] * 255) as integer
            local g = (bg[2] * 255) as integer
            local b = (bg[3] * 255) as integer
            local maxBgColor = (dotNetClass "System.Drawing.Color").FromArgb r g b
            
            lbl_tgtName.BackColor = maxBgColor
            lbl_srcName.BackColor = maxBgColor
            
            lbl_tgtName.ForeColor = (dotNetClass "System.Drawing.Color").DeepSkyBlue
            lbl_srcName.ForeColor = (dotNetClass "System.Drawing.Color").LimeGreen
            
            local fontStyle = (dotNetClass "System.Drawing.FontStyle").Bold
            lbl_tgtName.Font = dotNetObject "System.Drawing.Font" "Tahoma" 8.5 fontStyle
            lbl_srcName.Font = dotNetObject "System.Drawing.Font" "Tahoma" 8.5 fontStyle
            
            assignSelection()
        )
        
        on btn_swap pressed do (
            if srcNode != undefined and tgtNode != undefined do (
                undo "Swap Objects" on (
                    if origTransform != undefined and classOf pSrc1 == Point3 do (
                        srcNode.transform = origTransform
                    )
                    
                    local tempNode = srcNode
                    srcNode = tgtNode
                    tgtNode = tempNode
                    
                    if classOf pSrc1 == Point3 do (
                        local tempP1 = pSrc1
                        local tempP2 = pSrc2
                        pSrc1 = pTgt1
                        pSrc2 = pTgt2
                        pTgt1 = tempP1
                        pTgt2 = tempP2
                    )
                    
                    origTransform = srcNode.transform
                    updateLabels()
                    
                    if classOf pSrc1 == Point3 do (
                        updateAlignment()
                    )
                )
            )
        )

        on chk_2d changed val do (
            if classOf pSrc1 == Point3 do updateAlignment()
        )

        on btn_pick pressed do (
            if not assignSelection() do (
                messageBox "Please select at least 2 objects in the viewport first.

1st Selection = ALIGN THIS (Moves)
2nd Selection = ALIGN THERE (Stays)" title:"Selection Required"
                return false
            )

            origTransform = srcNode.transform
            spn_angle.value = 90.0

            local isPicking = true
            while isPicking do (
                pSrc1 = undefined; pSrc2 = undefined; pTgt1 = undefined; pTgt2 = undefined

                pushPrompt "Pick Point 1: ALIGN THIS Edge START (Right-click to Cancel tool)"
                pSrc1 = pickPoint snap:#3d
                if pSrc1 == #rightClick or pSrc1 == undefined do (
                    pushPrompt "Alignment Cancelled."
                    isPicking = false
                    exit
                )

                pushPrompt "Pick Point 2: ALIGN THIS Edge END (Right-click to Restart sequence)"
                pSrc2 = pickPoint snap:#3d rubberBand:pSrc1
                if pSrc2 == #rightClick do continue
                if pSrc2 == undefined do ( pushPrompt ""; isPicking = false; exit )

                pushPrompt "Pick Point 3: ALIGN THERE Edge START (Right-click to Restart sequence)"
                pTgt1 = pickPoint snap:#3d
                if pTgt1 == #rightClick do continue
                if pTgt1 == undefined do ( pushPrompt ""; isPicking = false; exit )

                pushPrompt "Pick Point 4: ALIGN THERE Edge END (Right-click to Restart sequence)"
                pTgt2 = pickPoint snap:#3d rubberBand:pTgt1
                if pTgt2 == #rightClick do continue
                if pTgt2 == undefined do ( pushPrompt ""; isPicking = false; exit )

                pushPrompt "" 
                isPicking = false 

                spn_angle.enabled = true
                btn_flip.enabled = true
                btn_rot90.enabled = true
                btn_rotM90.enabled = true
                btn_rot0.enabled = true

                updateAlignment()
            )
        )

        on spn_angle changed val do updateAlignment()

        on btn_flip pressed do (
            spn_angle.value += 180.0
            updateAlignment()
        )

        on btn_rot90 pressed do (
            spn_angle.value += 90.0
            updateAlignment()
        )

        on btn_rotM90 pressed do (
            spn_angle.value -= 90.0
            updateAlignment()
        )

        on btn_rot0 pressed do (
            spn_angle.value = 0.0
            updateAlignment()
        )
    )

    createDialog EdgeAlignTool
)
/*

launchEdgeAlignTool()
*/ 
