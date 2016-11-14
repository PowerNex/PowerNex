import PowerNex.Syscall;
import PowerNex.Data.Address;
import PowerNex.Data.String;
import PowerNex.Data.BMPImage;
import PowerNex.Data.Color;

void Print(string str) {
	Syscall.Write(0UL, cast(ubyte[])str, 0UL);
}

void Println(string str) {
	Print(str);
	Print("\n");
}

int main(string[] args) {
	size_t fb = Syscall.Open("/IO/Framebuffer/Framebuffer1");
	if (!fb)
		return 1;

	size_t fd = Syscall.Open("/Data/DLogo.bmp");
	if (!fd)
		return 2;

	BMPImage image = new BMPImage(fd);

	size_t[2] header;
	Syscall.Read(fb, cast(ubyte[])header, 0);

	Println("There will be a DLogo in the center of the screen :)");

	const size_t xoff = header[0] / 2 - image.Width / 2;
	const size_t yoff = header[1] / 2 - image.Height / 2;
	for (size_t row = 0; row < image.Height; row++) {
		auto dataRow = image.Data[row * image.Width .. (row + 1) * image.Width];
		size_t yPos = row + yoff;
		Syscall.Write(fb, cast(ubyte[])dataRow, (yPos * header[0] + xoff) * Color.sizeof);
	}

	Syscall.Close(fd);
	Syscall.Close(fb);

	return 0;
}
