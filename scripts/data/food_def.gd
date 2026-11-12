class_name FoodDef
extends DataDef
## Something you can pick up and eat or drink. The 3D model comes from
## FoodKit (`model`); what it does to you is decided in Home.

@export var display_name := ""
@export var group := "sweet"          ## sweet | frozen | crunchy | hot | drink
@export var model := ""               ## FoodKit model id
@export var tint := Color.WHITE       ## icing, wrapper, flavour or can colour
@export var bites := 3                ## how many goes it takes to finish
@export var energy := 8.0             ## total, spread over the bites
@export var health := 0.0             ## total: comfort food comforts
@export var fullness := 15.0          ## total stomach it takes up (0..100 scale)
@export var caffeine := false         ## counts as a coffee (jitters apply)
@export var price := 0                ## what a shop asks for it (0 = not for sale)
@export var trash := ""               ## FoodKit model left behind ("" = nothing)
@export var trash_name := ""          ## what the leftover is called
@export_multiline var blurb := ""
