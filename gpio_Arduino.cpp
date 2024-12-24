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
