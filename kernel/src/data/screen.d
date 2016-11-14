module Data.Screen;

import Data.Color;

interface Screen {
	@property long Width();
	@property long Height();
	@property Color[] PixelData();
}
