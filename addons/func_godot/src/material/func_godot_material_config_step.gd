#### TASTYSPLEEN_CLASSY 4/12/2025 ####
'''
Step in the Material Configuration pipeline. 
Allows us to configure material when func_godot instantiates it
'''
#### TASTYSPLEEN_CLASSY 4/12/2025 ####
@tool
class_name FuncGodotMaterialConfigStep

func configure_material(map_settings: FuncGodotMapSettings, texture_name: String, material : Material):
    pass

func should_configure_material(map_settings: FuncGodotMapSettings, texture_name: String, material : Material) -> bool:
    return true
#### TASTYSPLEEN_CLASSY 4/12/2025 ####