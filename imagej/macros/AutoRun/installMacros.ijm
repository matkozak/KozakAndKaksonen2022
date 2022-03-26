// Put this in Fiji.app/macros/AutoRun/, and your user-defined macros in Fiji.app/macros/StartupMacros.ijm. That way your macros are loaded at startup, but Fiji doesn't complain that StartupMacros.fiji.ijm is modified at every update.

run("Install...", "install=[" + getDirectory("imagej")
	+ "/macros/StartupMacros.ijm]");
