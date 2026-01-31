# Copybot / Darkstorm-Style Features in Phoenix Firestorm

This build includes the full copybot.patch logic and features analogous to the "Darkstorm" viewer: permission bypasses and export/save capabilities when **Hacked Godmode** is enabled.

## Enabling the Features

1. **Build** with `TOGGLE_HACKED_GODLIKE_VIEWER` defined (it is set to `1` in `llviewercontrol.h` and `llagent.h`).
2. **In-world**: Open **Advanced** menu → **Hacked Godmode** (or equivalent) to toggle godlike mode. When on, all bypasses below are active.

## What You Get (When Godlike Is On)

### Export & Save
- **Object export** (Backup OXP, Collada DAE): Export any selected object regardless of permissions (`fsexportperms.cpp`, `enable_export_object` in `llviewermenu.cpp`).
- **Texture save**: Save any texture from preview via "Save as" when godlike (`llpreviewtexture.cpp`).
- **Animation save**: Save animation from preview when godlike (`llpreviewanim.cpp` – `canSaveAs()`).
- **Sound save**: Save sound from preview when godlike (`llpreviewsound.cpp` – `canSaveAs()`).

### Object Permissions (Copybot)
- **permYouOwner, permModify, permCopy, permMove, permTransfer**: All report true when godlike so you can take, copy, modify, and export as if you had full rights (`llviewerobject.cpp`).
- **Take / Delete**: Take and delete enabled when godlike (`llviewermenu.cpp` – take loop, `enable_object_delete`, `enable_object_take_copy`).

### Texture Picker (Darkstorm-Style)
- **Texture UUID**: Reveal texture UUID in picker when godlike (`lltexturectrl.cpp` – setImageID, onSelectionChange, onTextureSelect).
- **Drag-and-drop**: Accept any texture in picker when godlike (`lltexturectrl.cpp` – handleDragAndDrop).
- **No-copy flag**: No-copy texture warning not applied when godlike.

### Wearables / Appearance
- **Wearable edit**: Apparel panels treat wearables as modifiable/copyable when godlike (`llpaneleditwearable.cpp` – is_modifiable, can_copy).
- **Texture filters**: In appearance, texture picker uses no perm filter when godlike so any texture can be chosen (`llpaneleditwearable.cpp` – init_texture_ctrl).

### Menus
- **Avatar.Export** / **Avatar.EnableExport**: Export available from avatar pie menu.
- **Attachment.Export** / **Attachment.EnableExport**: Export available from attachment pie menu.
- **Attachment pie**: Direct "Export" slice added (en `menu_pie_attachment_self.xml`).

## Files Touched

- `indra/newview/llagent.h` – `TOGGLE_HACKED_GODLIKE_VIEWER` define
- `indra/newview/llviewercontrol.h` – define + `gHackGodmode`
- `indra/newview/llviewercontrol.cpp` – `gHackGodmode` definition
- `indra/newview/fsexportperms.cpp` – godlike bypass in `canExportNode`, `canExportAsset`
- `indra/newview/llviewerobject.cpp` – godlike bypass in all six `perm*` functions
- `indra/newview/llviewermenu.cpp` – export enable, take/delete/take_copy, Avatar/Attachment Export menus
- `indra/newview/llpreviewtexture.cpp` – `canSaveAs()` godlike
- `indra/newview/llpreviewanim.cpp` + `.h` – `canSaveAs()` godlike
- `indra/newview/llpreviewsound.cpp` + `.h` – `canSaveAs()` godlike
- `indra/newview/llpaneleditwearable.cpp` – is_modifiable, can_copy, init_texture_ctrl
- `indra/newview/lltexturectrl.cpp` – TextureKey reveal, handleDragAndDrop, onSelectionChange, onTextureSelect
- `indra/newview/skins/default/xui/en/menu_pie_attachment_self.xml` – Export slice

## Legal / ToS

Use of these features may violate Second Life’s Terms of Service and can result in account action. This document is for technical reference only.
