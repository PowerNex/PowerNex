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
	size_t fb = Syscall.open("/io/framebuffer/framebuffer1", "wr");
	if (!fb)
		return 1;

	size_t[2] header;
	Syscall.read(fb, cast(ubyte[])header, 0);
	const width = 640;
	const height = 480;

	const size_t xoff = header[0] / 2 - width / 2;
	const size_t yoff = header[1] / 2 - height / 2;

	Color[] data = new Color[width];

	size_t tick = 0;
	while (true) {
		tick++;
		for (size_t row = 0; row < height; row++) {
			size_t yPos = row + yoff;
			const size_t tmp = tick << 2;

			foreach (size_t xPos; 0 .. width) {
				size_t tmp2 = tmp + xPos + yPos;
				data[xPos] = Color((tmp2 + tick * 3) & 0xFF, (tmp2 + tick * 5) & 0xFF, (tmp2 + tick) & 0xFF, 0xFF);
			}

			Syscall.write(fb, cast(ubyte[])data, (yPos * header[0] + xoff) * Color.sizeof);
		}
	}

	data.destroy;
	Syscall.close(fb);

	return 0;
}
