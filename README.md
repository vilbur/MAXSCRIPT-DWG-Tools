
# Set of tools to process dwg files in 3Ds Max  

### Pipeline for Processing DWG Files  

## Prepare DWG Files  

Each ARCH view **must have its own DWG file**.  

A single DWG file may contain multiple views, but each view should be prepared as a separate DWG before import.  

Filenames are important because they become **layer names in 3ds Max**.  

---  

## Import DWG Files  

Uses: [`DwgMassImporter.ms`](\Lib\DwgMassImporter\)  
![ DwgMassImporter ](Doc\DwgMassImporter.jpg "DwgMassImporter")  

Mass-import DWG files into 3ds Max.  

### Importer Settings  

- **Search and Replace**  
  Remove unwanted prefixes or other naming irregularities.  

- **Flatten Mesh**  
  Some splines are imported as meshes. This option converts them back to splines.  

- **Group Each DWG**  
  Groups each imported DWG file. This is usually not needed.  

---  

## Clean Up DWG Data  

Uses: [`trimSplineByVolume.ms`](\Lib\trimSplineByVolume\)  
![ trimSplineByVolume ](Doc\trimSplineByVolume.jpg "trimSplineByVolume")  



### Trim the Desired View from the DWG File  

Each DWG file may contain multiple views.  

- Generate a volume helper for each view.  
  The volume defines the canvas area.  

- Mass-generated helpers are applied to all visible layers.  

### Run Trim  

Run trimming for the selected or visible helper.  

This deletes all splines outside the helper volume.  

### Helper Cleanup  

Helpers are deleted after a successful trim.  

Use **Undo** to bring them back if needed.  

---  

# Result after import &  cleanup  

Each view has its own layer, named after the DWG file.  


--  

## DWG LAYER VIEWER  

![ DwgLayerViewer ](Doc\DwgLayerViewer.jpg "DwgLayerViewer")  
  