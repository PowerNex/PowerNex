module bin.consolefont;

import data.font;
import data.psf;

private __gshared ubyte[] _consoleFont_PSF;// = cast(ubyte[])import("data/font/terminus/ter-v16n.psf");

PSF getConsoleFont() {
	import stl.trait : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, PSF)] data;
	__gshared PSF consoleFont;

	if (!consoleFont)
		consoleFont = inplaceClass!PSF(data, _consoleFont_PSF);
	return consoleFont;
}
