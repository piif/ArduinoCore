#include <Arduino.h>

int main(void) {
	init();

#if defined(USBCON)
	USBDevice.attach();
#endif
	
	setup();
    
	for (;;) {
		loop();
		if (serialEventRun) serialEventRun();
	}
        
	return 0;
}

extern "C" void __cxa_pure_virtual() {
	while (1);
}
