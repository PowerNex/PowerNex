module Bin.ConsoleFont;

import Data.Font;
import HW.BGA.PSF;

private __gshared ubyte[] ConsoleFont_PSF = cast(ubyte[])import("Bin/ConsoleFont.psf");

PSF GetConsoleFont() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, PSF)] data;
	__gshared PSF consoleFont;

	if (!consoleFont)
		consoleFont = InplaceClass!PSF(data, ConsoleFont_PSF);
	return consoleFont;
}
