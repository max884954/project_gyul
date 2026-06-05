class_name DungeonCardHud
extends PanelContainer

@onready var deck_label: Label = %DeckLabel
@onready var card_help_label: Label = %CardHelpLabel
@onready var run_action_container: HBoxContainer = %RunActionContainer
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var tutorial_button: Button = %TutorialButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var log_view: RichTextLabel = %LogView
