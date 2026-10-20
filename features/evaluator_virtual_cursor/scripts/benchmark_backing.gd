extends RefCounted
## Test-only startup configuration. Never called after gameplay-world creation.
static func initialize(window:Window)->Dictionary:
	var before:Vector2i=window.size
	var initialized:=false
	var reason:=""
	var requested:Array=[]
	if DisplayServer.get_name()=="headless":
		# Engine options are consumed before OS exposes arguments to scripts.
		var args:PackedStringArray=OS.get_cmdline_user_args()
		var index:int=args.find("--backing-size")
		if index<0 or index+1>=args.size():reason="RESOLUTION_ARGUMENT_REQUIRED"
		else:
			var dimensions:PackedStringArray=args[index+1].split("x")
			if dimensions.size()!=2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():reason="CANONICAL_BACKING"
			else:
				requested=[int(dimensions[0]),int(dimensions[1])]
				if requested!=[1024,576]:reason="CANONICAL_BACKING"
		if reason.is_empty():
			# Headless Window ignores the CLI size in this build; initialize preworld.
			window.size=Vector2i(1024,576)
			initialized=true
	if reason.is_empty() and window.size!=Vector2i(1024,576):reason="CANONICAL_BACKING"
	if reason.is_empty() and window.get_visible_rect().size!=Vector2(1920,1080):reason="LOGICAL_VIEWPORT"
	return {"reason":reason,"before_size":[before.x,before.y],"requested_cli_size":requested,"explicit_headless_initialization":initialized,"actual_size":[window.size.x,window.size.y],"logical_size":[window.get_visible_rect().size.x,window.get_visible_rect().size.y],"phase":"BEFORE_GAMEPLAY_WORLD"}
