module app;

import std.stdio;
import core.sys.powernex.io;
import powernex.gfx.ppm;

int main(string[] args) {
	version (none) {
		File fb = File("/system/device/framebuffer", FileMode.none);
		if (!fb) {
			write("Failed to open the framebuffer!");
			return 1;
		}

		size_t width = fb.ioctl(0);
		size_t height = fb.ioctl(1);
		size_t videoMemory = fb.ioctl(2);
		uint[] screen = (cast(uint*)videoMemory)[0 .. width * height];

		string file = "/data/background.ppm";
		if (args.length > 1)
			file = args[1];
		File image = File(file, FileMode.read);
		if (!image) {
			write("'", initFile, "' is missing!");
			return 1;
		}

		size_t len = image.length;
		ubyte[] data;
		data.length = len;
		scope (exit)
			data.length = 0;
		image.read(data);

		PPM img = PPM(data);

		enum pixelSize = 1;
		size_t startX = width / 2 - (img.width * pixelSize) / 2;
		size_t startY = height / 2 - (img.height * pixelSize) / 2;

		foreach (size_t y; 0 .. img.height)
			foreach (size_t x; 0 .. img.width) {
				auto pixel = img.data[(y * img.width + x) * 3 .. (y * img.width + x) * 3 + 3];
				size_t realX = startX + (x * pixelSize);
				size_t realY = startY + (y * pixelSize);
				foreach (y0; 0 .. pixelSize)
					foreach (x0; 0 .. pixelSize)
						screen[(realY + y0) * width + (realX + x0)] = pixel[0] << 16 | pixel[1] << 8 | pixel[2] << 0;
			}
	}
	return 0;
}
