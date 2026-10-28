class_name GameExit
extends RefCounted

## Leaving the game. A desktop build simply quits. A browser tab cannot close
## itself, so in the web build the shell page (web/shell/loading_shell.html) takes
## the visitor back to the website's case files once the engine has exited, which
## happens only after the engine has flushed its saves to the browser's storage.

const SHELL_HOOK := "window.shadowCastleExit && window.shadowCastleExit.requested()"


static func quit(tree: SceneTree) -> void:
	if OS.has_feature("web"):
		# Godot's web exit closes the AudioContext before its final cleanup, and that
		# cleanup then pauses every sound still playing, which throws and stops the
		# exit before the shell hears of it. Silent players have nothing to pause.
		for node: Node in tree.root.find_children("*", "", true, false):
			if node is AudioStreamPlayer:
				(node as AudioStreamPlayer).stop()
			elif node is AudioStreamPlayer2D:
				(node as AudioStreamPlayer2D).stop()
			elif node is AudioStreamPlayer3D:
				(node as AudioStreamPlayer3D).stop()
		JavaScriptBridge.eval(SHELL_HOOK, true)
	tree.quit()
