module kmain;

import io.textmode;

void main() {
	auto scr = Screen!(80, 25)(Colors.Cyan, Colors.Black);
	scr.Clear();
	scr.Print("Hello World!");
	asm {
		forever:
			hlt;
			jmp forever;
	}
}
