module main;

struct VideoSlot {
	char ch;
	ubyte color;
}

extern (C) ulong main() {
	VideoSlot[] video = (cast(VideoSlot*)0xB8000)[0 .. 80 * 25];
	while (true) {
		foreach (i, ref slot; video) {
			//slot.ch += i;
			slot.color += 1;
		}

		for(int i; i < int.max/128; i++) {}
	}
	return 0;
}
