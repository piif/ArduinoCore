ArduinoCore
============

Files included in Arduino 1.0.5 IDE, organized in an Eclipse project.
The project generate a libArduinoCore.a file which may be used to compile programs.

Files are "as is", excepted a NO_ARDUINO_IDE constant defined in Arduino.h
This define allow to write a program ending with the main() definition nested
in a #if to define this function only from eclipse, as Arduino IDE
declares it itself.

TODO : minimal project as example + howto for project creation