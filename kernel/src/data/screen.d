module data.screen;

import data.color;

interface Screen {
	@property long width();
	@property long height();
	@property Color[] pixelData();
}
