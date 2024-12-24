Interfacing with GPIO (General Purpose Input/Output) pins is a fundamental skill when working with Arduino. Here, I'll provide an example of how to use GPIO pins for both input and output.

### Example: Blinking an LED and Reading a Button

#### Components Needed
- Arduino board (e.g., Arduino Uno)
- LED
- 220-ohm resistor
- Push button
- 10k-ohm resistor
- Breadboard and jumper wires

#### Circuit Diagram
1. **LED Setup**:
   - Connect the anode (long leg) of the LED to digital pin 13 through a 220-ohm resistor.
   - Connect the cathode (short leg) of the LED to the ground (GND).

2. **Button Setup**:
   - Connect one leg of the button to digital pin 7.
   - Connect the other leg of the button to the ground (GND).
   - Add a 10k-ohm pull-up resistor between the button leg connected to pin 7 and the 5V supply.

#### Arduino Code
```cpp
const int ledPin = 13;    // LED connected to digital pin 13
const int buttonPin = 7;  // Button connected to digital pin 7

int buttonState = 0;      // Variable to hold the button state

void setup() {
  // Initialize the LED pin as an output
  pinMode(ledPin, OUTPUT);
  
  // Initialize the button pin as an input
  pinMode(buttonPin, INPUT_PULLUP);  // Enable internal pull-up resistor
}

void loop() {
  // Read the state of the button
  buttonState = digitalRead(buttonPin);

  // Check if the button is pressed
  if (buttonState == LOW) {
    // Turn the LED on
    digitalWrite(ledPin, HIGH);
  } else {
    // Turn the LED off
    digitalWrite(ledPin, LOW);
  }
  
  // Small delay to debounce the button
  delay(50);
}
```

### Explanation
1. **Setup Function**:
   - `pinMode(ledPin, OUTPUT);` sets the LED pin as an output.
   - `pinMode(buttonPin, INPUT_PULLUP);` sets the button pin as an input with an internal pull-up resistor enabled.

2. **Loop Function**:
   - `digitalRead(buttonPin);` reads the state of the button.
   - If the button is pressed (`LOW` state due to pull-up resistor), the LED turns on.
   - If the button is not pressed (`HIGH` state), the LED turns off.
   - `delay(50);` adds a small delay to debounce the button, which helps to avoid false readings due to mechanical noise.

### Additional Tips
- **Debouncing**: If you experience issues with button readings, consider implementing a more robust debouncing algorithm.
- **Breadboard Layout**: Ensure all connections are secure on the breadboard to avoid intermittent issues.

This basic example demonstrates how to use GPIO pins for both input (button) and output (LED) on an Arduino. You can expand upon this by adding more sensors, actuators, and implementing more complex logic.
