module kmain;

import io.textmode;

alias scr = GetScreen;

void main() {
	scr.Clear();
	scr.Print("Hello World!\n");
	asm {
		forever:
			hlt;
			jmp forever;
	}
}
