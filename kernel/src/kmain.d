module kmain;

import io.textmode;

alias scr = GetScreen;

void main() {
	scr.Clear();
	scr.Print("Hello World!\n");
	scr.Print("Int test: ");
	scr.Print(-1337);
	scr.Print("\n");
	scr.Print("Hex test: ");
	scr.Print(0xDEADC0DE);
	scr.Print("\n");
	asm {
		forever:
			hlt;
			jmp forever;
	}
}
