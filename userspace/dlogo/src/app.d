import powernex.syscall;
import powernex.data.address;
import powernex.data.string_;
import powernex.data.bmpimage;
import powernex.data.color;

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void println(string str) {
	print(str);
	print("\n");
}

int main(string[] args) {
	size_t fb = Syscall.open("/io/framebuffer/framebuffer1", "wb");
	if (!fb)
		return 1;

	size_t fd = Syscall.open("/data/dlogo.bmp", "rb");
	if (!fd)
		return 2;

	BMPImage image = new BMPImage(fd);

	size_t[2] header;
	Syscall.read(fb, cast(ubyte[])header, 0);

	println("There will be a DLogo in the center of the screen :)");

	const size_t xoff = header[0] / 2 - image.width / 2;
	const size_t yoff = header[1] / 2 - image.height / 2;
	for (size_t row = 0; row < image.height; row++) {
		auto dataRow = image.data[row * image.width .. (row + 1) * image.width];
		size_t yPos = row + yoff;
		Syscall.write(fb, cast(ubyte[])dataRow, (yPos * header[0] + xoff) * Color.sizeof);
	}

	Syscall.close(fd);
	Syscall.close(fb);

	return 0;
}
